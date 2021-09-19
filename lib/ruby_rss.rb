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
    feed.status = nil
    begin
      if (f = RSS::Parser.parse(rss)).nil?
        Refresh.log "Feed '#{feed.name}' has no content.", :error
      elsif f.items.size == 0
        Refresh.log "Feed '#{feed.name}' has no posts.", :warning
      else
        if f.respond_to?(:channel)
          feed.title ||= strip_tags(f.channel.title).strip
        elsif f.respond_to?(:title)
          feed.title ||= strip_tags(f.title.to_s).strip
        else
          Refresh.log "MISSING TITLE: '#{feed.name}'.", :warning
        end

        unless (f.items[0].class == RSS::Rss::Channel::Item) || (f.items[0].class == RSS::Atom::Feed::Entry)
          Refresh.log "CLASS: #{f.items[0].class}.", :highlight
        end

        f.items.each do |post|
          title = strip_tags(post.title.to_s)
          title.strip!

          case post.class.to_s
          when 'RSS::Atom::Feed::Entry'
            description = post.content
            ident = post.id.to_s
            published_at = strip_tags(post.updated.to_s)
          else
            description = post.description
            ident = (post.guid ? post.guid : post.link).to_s

            if post.pubDate != post.date
              Refresh.log "DATES: pubDate: #{post.pubDate}, date: #{post.date},  dc_date: #{post.dc_date}.", :warning
            end
            published_at = first_nonblank(post.pubDate, post.date, post.dc_date, now)
          end
          ident.strip!

          ident = title if ident.empty?

          Post.update_or_create(feed_id: feed.id, ident: ident) do |p|
            if p.new?
              if post.class == RSS::Atom::Feed::Entry
                Refresh.log("ATOM: #{title}", :highlight)
              else
                Refresh.log("NEW: #{title}", :highlight)
              end
              #                  Refresh.log "NEW: #{title.inspect}.", :highlight
              feed.ema_volume += ALPHA

              p.title = title.empty? ? nil : title
              p.description = description.to_s.strip
              p.ident = ident.to_s.strip
              p.published_at = DateTime.parse(published_at)	# TimeDate object
              p.time = published_at.strip	# actual String
              p.url = post.link.to_s.strip
            end
            p.previous_refresh = now
          end
        end
      end
    rescue
      feed.status = $!.class
      Refresh.log "Exception: #{$!}.", :error
    else
      feed.previous_refresh = now
    end
    feed.next_refresh = now + Refresh::CYCLE_TIME
    feed.save(changed: true)
  end
end
