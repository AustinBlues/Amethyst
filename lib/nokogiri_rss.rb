# coding: utf-8
require 'nokogiri'


module NokogiriRSS
  def refresh_feed(feed, now)
    feed.status = nil
    refreshed_at = feed.previous_refresh
    begin
      # open-uri is gagging on IPv6 address and doesn't support forcing to IPv4
      # libcurl and curb Gem appear to have same limitation.
      # Invoking curl CLI is fast enough
      open("|curl -s -4 #{feed.rss_url}") do |rss|
        f = Nokogiri::XML.parse(rss)

        if f.at_css('rss')
          standard = f.at_css('rss').name
          version = f.at_css('rss')['version']

          unless standard == 'rss' && version == '2.0'
            feed.status = "#{standard.upcase} #{version}"
            STDERR.puts("#{feed.status}.")
          end
          
          # Is this what I want, hand-edited title overridden?
          feed.title ||= f.at_css('channel title').content
          if feed.title.empty?
            feed.status = 'missing title'
            STDERR.puts "MISSING TITLE: '#{feed.name}'."
          end

          item = f.css('item')
        elsif f.namespaces['xmlns'] =~ /atom/i
        # ATOM
          standard = 'ATOM'
          feed.title = f.at_css('title').content
          item = f.css('entry')
        else
          feed.status = 'download or RSS parse failed'
#          STDERR.puts "OOPS(#{feed.name}): #{f.inspect}."
#          STDERR.puts "METHODS: #{f.methods}."
          item = []
        end

        if item.size == 0
          feed.status = 'empty'
          STDERR.puts "Feed '#{feed.name}' is empty."
        else
          item.each do |post|
            
            attrs = case standard
                    when 'rss'
                      parse_rss_item(post)
                    when 'ATOM'
                      parse_atom_item(post)
                    else
                      #              description = post.content
                      #              ident = post.id.to_s
                      #              published_at = strip_tags(post.updated.to_s)
                      #              STDERR.puts "ID: #{ident}."
                      #              STDERR.puts "UPDATED: #{published_at}."
                      STDERR.puts "METHODS: #{post.methods}"
                      nil
                    end

            Post.update_or_create(feed_id: feed.id, ident: attrs[:ident]) do |p|
#              puts "ATTRS: #{attrs.inspect}."
              if p.new?
                STDERR.puts "NEW: #{attrs[:title]}."
                feed.ema_volume += Aging::ALPHA 
                
                p.set(attrs)
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

    feed.next_refresh = now + Refresh::CYCLE_TIME
    feed.save(changed: true)

    if refreshed_at
      puts "Refreshed #{Refresh.time_ago_in_words(refreshed_at, true)} ago: #{feed.name}."
    else
      puts "Refreshed (no previous refresh): #{feed.name}."
    end
  end


  def parse_rss_item(post)
    attrs = {}

    attrs[:title] = post.at_css('title').content
    attrs[:description] = post.at_css('description').content
    # NOTE: ident uses .to_s instead of .content for compatibility with RubyRSS module
    attrs[:ident] = if (tmp = post.at_css('guid'))
                      tmp.to_s
                    elsif (tmp = post.at_css('link'))
                      tmp.to_s
                    else
                      attrs[:status] = 'missing ident'
                      STDERR.puts "NO IDENT: "#{title}'."
                      post.feed.title
                    end
    attrs[:time] = if (tmp = post.at_css('pubDate'))
                     tmp.content
                   elsif (tmp = post.at_css('date'))
                     tmp.content
                   elsif (tmp = post.at_css('dc|date'))
                     tmp.content
                   else
                     attrs[:status] = 'missing date'
                     STDERR.puts "NO DATE: "#{title}'."
                     now.to_s
                   end
    attrs[:published_at] = Time.parse(attrs[:time])
    attrs[:url] = if !(link = post.at_css('link')).nil?
                   link.content
                 elsif !(link = post.at_css('enclosure')).nil?
                   link['url']
                 else
                   p.status = 'missing URL'
                   STDERR.puts "MISSING URL: '#{p.name}'."
                   post.feed.rss_url
                 end
    attrs
  end


  def parse_atom_item(post)
    attrs = {}

    attrs[:title] = post.at_css('title').content
    attrs[:description] = post.at_css('content').content
    if (tmp = post.at_css('summary'))
      attrs[:synopsis] = tmp.content
    end
    # NOTE: ident uses .to_s instead of .content for compatibility with RubyRSS module
    attrs[:ident] = if (tmp = post.at_css('id'))
                      tmp.to_s
                    elsif (tmp = post.at_css('link'))
                      tmp['href']
                    else
                      attrs[:status] = 'missing ident'
                      STDERR.puts "NO IDENT: "#{title}'."
                      post.feed.title
                    end
    attrs[:time] = if (tmp = post.at_css('published'))
                     tmp.content
                   elsif (tmp = post.at_css('date'))
                     tmp.content
                   elsif (tmp = post.at_css('dc|date'))
                     tmp.content
                   else
                     attrs[:status] = 'missing date'
                     STDERR.puts "NO DATE: "#{title}'."
                     now.to_s
                   end
    attrs[:published_at] = Time.parse(attrs[:time])
    attrs[:url] = if !(link = post.at_css('link')).nil?
                   link['href']
                 elsif !(link = post.at_css('enclosure')).nil?
                   link['url']
                 else
                   p.status = 'missing URL'
                   STDERR.puts "MISSING URL: '#{p.name}'."
                   post.feed.rss_url
                 end
    attrs
  end
end
