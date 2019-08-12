require 'rss'
require 'open-uri'

module RubyRSS
  extend Padrino::Helpers::FormatHelpers
  
  def self.refresh_feed(feed)
    open(feed.rss_url) do |rss|
      f = nil	# force scope
      begin
        STDERR.puts "PARSING: #{feed.rss_url}."
        f = RSS::Parser.parse(rss)
      rescue
        STDERR.puts "Exception: #{$!}."
        exit
      end

      if feed.respond_to?(:channel)
        # is this what I want, hand-edited title overridden?
        feed.title ||= strip_tags(f.channel.title)
      else
        STDERR.puts "METHODS(#{f.class}): #{f.methods}"
      end
      feed.save
      
      if f.items.size == 0
        STDERR.puts "Feed '#{feed.name}' is empty."
      else
        f.items.each do |post|
          title = strip_tags(post.title.to_s)
          STDERR.puts "Post: '#{title}'."
          
          case post.class.to_s
          when 'RSS::Atom::Feed::Entry'
            description = post.dc_description
            ident = post.dc_identifier
            published_at = strip_tags(post.updated.to_s)
#            STDERR.puts "UPDATED: #{published_at}."
            STDERR.puts "ID: #{ident}."
#            STDERR.puts "METHODS(#{post.class}): #{post.methods}"
          else
            STDERR.puts "GUID: #{post.guid}."
#            STDERR.puts "PubDATE: #{post.pubDate}."
#            STDERR.puts "DATE: #{post.date}."
            description = post.description
            ident = post.guid
            published_at = post.pubDate || post.date
          end

#          STDIN.gets
          
          tmp = Post.find_or_create(feed_id: feed.id, title: title) do |p|
            p.feed_id = feed.id
            p.title = title
            p.description = description
            p.ident = ident
            p.published_at = published_at
            p.time = Time.now	# KLUDGE: not sure what this should be
#            STDERR.puts "POST: #{post.methods}"
            p.url = post.link
          end
          STDERR.puts "  #{tmp.inspect}"
        end
      end
    end
  end
end
