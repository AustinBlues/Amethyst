require 'rss'


module ParseRSS
  extend Padrino::Helpers::FormatHelpers
  
  def self.first_nonblank(*args)
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


  def self.refresh_feed(feed, now)
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
          STDERR.puts "MISSING TITLE: '#{feed.name}'."
        end
        
        if f.items.size == 0
          STDERR.puts "Feed '#{feed.name}' is empty."
        else
          f.items.each do |post|
            title = strip_tags(post.title.to_s)

            case post.class.to_s
            when 'RSS::Atom::Feed::Entry'
              description = post.content
              ident = post.id.to_s
              published_at = strip_tags(post.updated.to_s)
              STDERR.puts "ID: #{ident}."
              STDERR.puts "UPDATED: #{published_at}."
#              STDERR.puts "METHODS(#{post.class}): #{post.methods}"
            else
#              STDERR.puts "GUID: #{post.guid}."
#              STDERR.puts "PubDATE: #{post.pubDate}."
#              STDERR.puts "DATE: #{post.date}."
              description = post.description
              ident = post.guid.to_s

              if post.pubDate != post.date
                STDERR.puts "DATES: pubDate: #{post.pubDate}, date: #{post.date},  dc_date: #{post.dc_date}."
              end
              published_at = first_nonblank(post.pubDate, post.date, post.dc_date, now)
            end

            ident = title if ident.empty?
            
            Post.update_or_create(feed_id: feed.id, ident: ident) do |p|
              if p.new?
                STDERR.puts "NEW: #{title.inspect}."
                feed.ema_volume += Aging::ALPHA 
                p.title = title.empty? ? nil : title
                p.description = description
                p.published_at = published_at	# TimeDate object
                p.time = published_at	# actual String
                p.url = post.link
              end
              p.previous_refresh = now
#              STDERR.puts "  #{p.inspect}"
            end
          end
        end
      end
    rescue
      feed.status = $!.class
      STDERR.puts "Exception: #{$!}."
    else
      feed.previous_refresh = now
    end
  end
end
