require 'rss'
require 'open-uri'

module RubyRSS
  extend Padrino::Helpers::FormatHelpers
  
  def self.refresh_feed(feed)
    begin
      open(feed.rss_url) do |rss|
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
              description = post.dc_description
              ident = post.dc_identifier
              published_at = strip_tags(post.updated.to_s)
            #            STDERR.puts "ID: #{ident}."
            #            STDERR.puts "UPDATED: #{published_at}."
            #            STDERR.puts "METHODS(#{post.class}): #{post.methods}"
            else
              #            STDERR.puts "GUID: #{post.guid}."
              #            STDERR.puts "PubDATE: #{post.pubDate}."
              #            STDERR.puts "DATE: #{post.date}."
              description = post.description
              ident = post.guid
              published_at = post.pubDate || post.date
            end

            #          STDIN.gets
            
            tmp = Post.find_or_create(feed_id: feed.id, title: title) do |p|
              STDERR.puts "Post: '#{title}'."
              p.feed_id = feed.id
              p.title = title
              p.description = description
              p.ident = ident
              p.published_at = published_at
              p.time = Time.now	# KLUDGE: not sure what this should be
              #            STDERR.puts "POST: #{post.methods}"
              p.url = post.link
              feed.moving_avg += Aging::ALPHA
              STDERR.puts "  #{p.inspect}"
            end
          end
        end
      end
    rescue Net::OpenTimeout
      STDERR.puts "TIMEOUT: #{feed.name}."
    rescue
      STDERR.puts "Exception: #{$!}."
    end
  end
end
