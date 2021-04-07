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


  def refresh_feed(feed, now)
    feed.status = nil
    begin
      # open-uri is gagging on IPv6 address and doesn't support forcing to IPv4
      # libcurl and curb Gem appear to have same limitation.
      # Invoking curl CLI is fast enough
      open("|curl -s -4 #{feed.rss_url}") do |rss|
        f = RSS::Parser.parse(rss)
        
        if f.respond_to?(:channel)
          # Is this what I want, hand-edited title overridden?
          feed.title ||= strip_tags(f.channel.title)
        elsif f.respond_to?(:title)
          # Is this what I want, hand-edited title overridden?
          feed.title ||= strip_tags(f.title.to_s)
        else
          Refresh.log "MISSING TITLE: '#{feed.name}'.", :warning
        end
        
        if f.items.nil?
          Refresh.log "Feed '#{feed.name}' items is non-existant.", :error
        elsif f.items.size == 0
          Refresh.log "Feed '#{feed.name}' is empty.", :warning
        else
          f.items.each do |post|
            title = strip_tags(post.title.to_s)

            case post.class.to_s
            when 'RSS::Atom::Feed::Entry'
              description = post.content
              ident = post.id.to_s
              published_at = strip_tags(post.updated.to_s)
#              Refresh.log "ID: #{ident}.", :debug
#              Refresh.log "UPDATED: #{published_at}.", :debug
#              Refresh.log "METHODS(#{post.class}): #{post.methods}", :debug
            else
#              Refresh.log "GUID: #{post.guid}.", :debug
#              Refresh.log "PubDATE: #{post.pubDate}.", :debug
#              Refresh.log "DATE: #{post.date}.", :debug
              description = post.description
              ident = post.guid ? post.guid.to_s : post.link

              if post.pubDate != post.date
                Refresh.log "DATES: pubDate: #{post.pubDate}, date: #{post.date},  dc_date: #{post.dc_date}.", :warning
              end
              published_at = first_nonblank(post.pubDate, post.date, post.dc_date, now)
            end

            ident = title if ident.empty?

            new = nil	# force scope
            Post.update_or_create(feed_id: feed.id, ident: ident) do |p|
              if (new = p.new?)
                feed.ema_volume += Daily::ALPHA 
                p.title = title.empty? ? nil : title
                p.description = description
                p.published_at = published_at	# TimeDate object
                p.time = published_at	# actual String
                p.url = post.link
              end
              Refresh.log("NEW: #{title}", :highlight) if new
              p.previous_refresh = now
#              Refresh.log "  #{p.inspect}", :debug
            end
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
