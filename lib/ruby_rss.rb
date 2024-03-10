require 'rss'


module RubyRSS
  def first_nonblank(*args)
    if args.nil?
      nil
    elsif args.size == 1
      if args[0].respond_to?(:empty?) && args[0].empty?
        nil
      else
        tmp = args[0].to_s.strip
        (tmp != '') ? tmp : nil
      end
    else
      args.each do |a|
        tmp = first_nonblank(a)
        return tmp unless tmp.nil?
      end
      nil
    end
  end


  def refresh_feed(feed, rss, now)
    if rss
      feed.status = nil
      begin
        if (f = RSS::Parser.parse(rss, false)).nil?
          Refresh.log "Feed '#{feed.name}' has no content.", :error
        elsif f.items.size == 0
          Refresh.log "Feed '#{feed.name}' has no posts.", :warning
        else
          case f.encoding
          when 'UTF-8'
            # preferred/assumed/Ruby native encoding
          when nil, ''
            # Only log on create or update/edit.
            Refresh.log("NO ENCODING specified.", :warning) if feed.previous_refresh.nil?
          else
            Refresh.log("ENCODING: #{f.encoding.inspect}.", :warning)
          end

          if f.respond_to?(:channel)
            feed.title ||= strip_tags(f.channel.title).strip
          elsif f.respond_to?(:title)
            feed.title ||= strip_tags(f.title.to_s).strip
          else
            Refresh.log "MISSING FEED TITLE: '#{feed.name}'.", :warning
          end

          unless (f.class == RSS::Rss) || (f.class == RSS::Atom::Feed) || (f.class == RSS::RDF)
            Refresh.log "CLASS: #{f.class}.", :info
          end

          f.items.each do |post|
            title = strip_tags(post.title.to_s)
            title.strip! if title

            case f.class.to_s
            when 'RSS::Atom::Feed'
              description = post.content.content
              ident = post.id.to_s
              time = strip_tags(post.updated.to_s)
            when 'RSS::Rss'
              description = post.description
              ident = post.link
              time = post.pubDate
            else
              description = post.description
              ident = (post.respond_to?(:guid) ? post.guid : post.link).to_s

              if post.respond_to?(:pubDate) && (post.pubDate != post.date)
                Refresh.log "DATES: pubDate: #{post.pubDate}, date: #{post.date},  dc_date: #{post.dc_date}.", :warning
              end
              if post.class.to_s == 'RSS::RDF::Item'
                time = first_nonblank(post.date, post.dc_date, now)
              else
                time = first_nonblank(post.pubDate, post.date, post.dc_date, now)
              end
            end
            if ident
              ident.strip!
            else
              ident = String.strip(post.link || post.guid)
              Refresh.log "MISSING POST IDENT: '#{post.link || post.guid}'.", :warning
            end
            description.strip! if description
            time.strip! if time && time.is_a?(String)

            ident = title if ident.empty?

            Post.update_or_create(feed_id: feed.id, ident: ident) do |p|
              if p.new?
                feed.ema_volume += ALPHA

                if title
                  p.title = title
                else
                  Refresh.log "MISSING POST TITLE: '#{post.link || post.guid}'.", :warning
                end
                if description
                  p.description = description
                else
                  p.description = 'MISSING DESCRIPTION'
                  Refresh.log "MISSING POST DESCRIPTION: '#{title || post.link || post.guid}.", :warning
                end
                p.published_at = Refresh.raw2time(time.to_s)
                if time.nil?
                  time = Time.now
                  Refresh.log("'#{title}' missing time, setting to current time.", :warning)
                end
                p.time = time.to_s
                if post.class != RSS::Atom::Feed::Entry
                  p.url = post.link.to_s.strip
                else
                  p.url = post.link.href.to_s.strip
                end

                Refresh.log("NEW: #{p.name}", :highlight)
              end
              p.previous_refresh = now
            end
          end
        end
      rescue Mysql2::Error
        feed.status = "MySQL encoding error" if $!.to_s =~ /Incorrect string value:/
        Refresh.log "MySQL: #{$!}.", :error
      rescue Sequel::DatabaseError
        feed.status = "Sequel encoding error" if $!.to_s =~ /Incorrect string value:/
        Refresh.log "MySQL: #{$!}.", :error
      rescue
        feed.status = $!.class
        Refresh.log "Exception: #{$!}.", :error
      else
        feed.previous_refresh = now
      end
    end
    feed.next_refresh = now + Refresh::CYCLE_TIME
    feed.save(changed: true)

    !rss.nil?
  end
end
