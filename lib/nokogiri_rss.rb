require 'nokogiri'


module NokogiriRSS
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
        f = Nokogiri::XML.parse(rss)

        standard = f.at_css('rss').name
        version = f.at_css('rss')['version']
        
        STDERR.puts("#{standard.upcase} #{version}.") unless standard == 'rss' && version == '2.0'
            
        # Is this what I want, hand-edited title overridden?
        feed.title ||= f.at_css('channel title').content
        if feed.title.empty?
          STDERR.puts "MISSING TITLE: '#{feed.name}'."
        end

        item = f.css('item')
        if item.size == 0
          STDERR.puts "Feed '#{feed.name}' is empty."
        else
          item.each do |post|
#            title = strip_tags(post.at_css('title').content)
            title = post.at_css('title').content

            if standard == 'rss'
              description = post.at_css('description').content
              # NOTE: ident uses .to_s instead of .content for compatibility with RubyRSS module
              ident = if (tmp = post.at_css('guid'))
                        tmp.to_s
                      elsif (tmp = post.at_css('link'))
                        tmp.to_s
                      else
                        STDERR.puts "NO IDENT: "#{title}'."
                        title
                      end
              date = if (tmp = post.at_css('pubDate'))
                       tmp.content
                     elsif (tmp = post.at_css('date'))
                       tmp.content
                     elsif (tmp = post.at_css('dc|date'))
                       tmp.content
                     else
                       STDERR.puts "NO DATE: "#{title}'."
                       now.to_s
                     end
              published_at = Time.parse(date)
            else
#              description = post.content
#              ident = post.id.to_s
#              published_at = strip_tags(post.updated.to_s)
#              STDERR.puts "ID: #{ident}."
#              STDERR.puts "UPDATED: #{published_at}."
              STDERR.puts "METHODS: #{post.methods}"
            end

            Post.update_or_create(feed_id: feed.id, ident: ident) do |p|
#            Post.find_or_new(feed_id: feed.id, ident: ident) do |p|
              if p.new?
                STDERR.puts "NEW: #{title.inspect}."
                feed.ema_volume += Aging::ALPHA 
                p.title = title.empty? ? nil : title
                p.description = description
                p.published_at = published_at	# TimeDate object
                p.time = date	# actual String
                p.url = post.at_css('link').content
              end
              p.previous_refresh = now
#              STDERR.puts "  #{p.inspect}"
            end
          end
        end
      end
    rescue Exception => e
      STDERR.puts e.backtrace.join('\n')
      feed.status = e.class
      STDERR.puts "Exception: #{e}."
    else
      feed.previous_refresh = now
    end
  end
end
