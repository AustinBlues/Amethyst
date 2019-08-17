require 'rss'


module RubyRSS
  extend Padrino::Helpers::FormatHelpers
  
  def self.refresh_feed(feed)
    begin
      # open-uri is gagging on IPv6 address and doesn't support forcing to IPv4
      # libcurl and curb Gem appear to have same limitation.
      # Invoking curl is fast enough
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
          #        STDERR.puts "METHODS(#{f.class}): #{f.methods}"
        end
        feed.save
        
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
              published_at = post.pubDate || post.date
            end

            ident = title if ident.empty?
            
#            tmp = Post.find_or_create(feed_id: feed.id, title: (title.nil? || title.blank?) ident : title) do |p|
            tmp = Post.find_or_create(feed_id: feed.id, ident: ident) do |p|
              STDERR.puts "Post: '#{title}'."
              p.feed_id = feed.id
              p.title = title.empty? ? nil : title
              p.description = description
              p.ident = ident
              p.published_at = published_at	# TimeDate object
              p.time = published_at	# actual String
#              STDERR.puts "POST: #{post.methods}"
              p.url = post.link
              feed.ema_volume += Aging::ALPHA
              STDERR.puts "  #{p.inspect}"
            end
          end
        end
      end
#    rescue Net::OpenTimeout
#      feed.status = 'timeout'
#      STDERR.puts "TIMEOUT: #{feed.name}."
    rescue
      feed.status = $!.class
      STDERR.puts "Exception: #{$!}."
    end
  end
end
