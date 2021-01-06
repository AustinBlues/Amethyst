# coding: utf-8
require 'nokogiri'
require 'time'
require 'htmlentities'


module NokogiriRSS
  def refresh_feed(feed, now)
    feed.status = nil
    begin
      # open-uri is gagging on IPv6 address and doesn't support forcing to IPv4
      # libcurl and curb Gem appear to have same limitation.
      # Invoking curl CLI is fast enough
#      open("|curl -s -4 '#{feed.rss_url}'") do |rss|
      rss = %x(wget '#{feed.rss_url}' -4 -q -O -)
      if $?.to_s !~ /exit 0/
#        puts("WGET: #{$?}.")
        rss = %x(curl -s -4 '#{feed.rss_url}')
#        puts "RSS: #{rss.size} bytes."
#        puts "RSS: #{rss}."
      end

      f = Nokogiri::XML.parse(rss)
      begin
        if f.at_css('rss')
          standard = f.at_css('rss').name
          version = f.at_css('rss')['version']

          unless standard == 'rss' && version == '2.0'
            feed.status = "#{standard.upcase} #{version}"
            Refresh.log "#{feed.status}.", :warning
          end
          
          # Is this what I want, hand-edited title overridden?
          feed.title ||= f.at_css('channel title').content
          feed.title.strip!
          if feed.title.empty?
            feed.status = 'missing title'
            Refresh.log "MISSING TITLE: '#{feed.name}'.", :warning
            #            feed.title = feed.rss_url
            feed.title = nil
          end

          item = f.css('item')
        elsif f.namespaces['xmlns'] =~ /atom/i
          # ATOM
          standard = 'ATOM'
          feed.title = f.at_css('title').content
          item = f.css('entry')
        else
          feed.status = 'download or RSS parse failed'
#          Refresh.log "OOPS(#{feed.name}): #{f.inspect}.", :error
#          Refresh.log "METHODS: #{f.methods}.", :debug
          item = []
        end

        if item.size == 0
          feed.status = 'empty'
          # KLUDGE: warning is yellow, not very readable.
          Refresh.log "Feed '#{feed.name}' is empty.", :warning
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
                      #              Refresh.log "ID: #{ident}.", :debug
                      #              Refresh.log "UPDATED: #{published_at}.", :debug
                      Refresh.log "METHODS: #{post.methods}", :debug
                      nil
                    end
            attrs[:title] = truncate(post.at_css('title').content, VARCHAR_MAX, separator: /\s/)
            attrs[:title].strip!

            if attrs[:description].nil?
              attrs[:description] = 'No description'
            else
              attrs[:description].strip!
              attrs[:description] = truncate(attrs[:description], TEXT_MAX, separator: /\s/)
            end

            attrs[:title] = truncate(attrs[:description], VARCHAR_MAX, separator: /\s/) if attrs[:title].empty?

            retries = 0
            begin
              Post.update_or_create(feed_id: feed.id, ident: attrs[:ident]) do |p|
                if p.new?
                  feed.ema_volume += Aging::ALPHA
                  if attrs[:description].nil?
                    attrs[:description] = 'No description'
                    Refresh.log "MISSING DESCRIPTION: '#{attrs[:title]}.", :warning
                  end
                  p.set(attrs)
                  Refresh.log "NEW: #{p.name}.", :highlight
                end
                p.previous_refresh = now
              end
            rescue Sequel::DatabaseError
              retries += 1
              if retries > 3
                Refresh.log 'Too many retries', :warning
                raise
              else
                case $!.to_s
                when /description/
                  attrs[:description] = nil
                when /synopsis/
                  attrs[:synopsis] = nil
                when /title/
                  attrs[:title] = nil
                else
                  Refresh.log 'No field name match', :error
                  raise
                end
                Refresh.log "Deleting #{$&}.", :warning
                retry
              end
            end
          end
        end
      end

    rescue Nokogiri::XML::XPath::SyntaxError
      # Benign as far as I can tell
    rescue Exception => e
      STDERR.puts e.backtrace.join('\n')
      feed.status = e.class
      Refresh.log "Exception: #{e}.", :error
      Refresh.log "CLASS: #{e.class}.", :debug
    else
      feed.previous_refresh = now
    end

    feed.next_refresh = now + Refresh::CYCLE_TIME
    feed.save(changed: true)
  end


  def parse_rss_item(post)
    attrs = {}

    attrs[:title] = post.at_css('title').content
    attrs[:description] = if (tmp = post.at_css('description'))
                            tmp.content.strip
                          end
    
    # NOTE: ident uses .to_s instead of .content for compatibility with RubyRSS module
    attrs[:ident] = if (tmp = post.at_css('guid'))
                      tmp.to_s
                    elsif (tmp = post.at_css('link'))
                      strip_tags(tmp.content)
                    else
                      attrs[:status] = 'missing ident'
                      Refresh.log "NO IDENT: '#{attrs[:title]}'.", :warning
                      attrs[:title]
                    end
    attrs[:time] = if (tmp = post.at_css('pubDate'))
                     tmp.content
                   elsif (tmp = post.at_css('date'))
                     tmp.content
                   elsif (tmp = post.at_css('dc|date'))
                     Refresh.log "INFO: dc:date used", :warning
                     tmp.content
                   else
                     attrs[:status] = 'missing date'
                     Refresh.log "NO DATE: '#{title}'.", :warning
                     now.to_s
                   end
#    attrs[:published_at] = Time.parse(attrs[:time])
    attrs[:published_at] = Refresh.raw2time(attrs[:time])
    attrs[:url] = if !(link = post.at_css('link')).nil?
                   link.content
                 elsif !(link = post.at_css('enclosure')).nil?
                   link['url']
                 else
                   p.status = 'missing URL'
                   Refresh.log "MISSING URL: '#{p.name}'.", :error
                   post.feed.rss_url
                 end
    attrs
  end


  def parse_atom_item(post)
    attrs = {}

    attrs[:title] = post.at_css('title')
    attrs[:description] = (tmp = post.at_css('content')).nil? ? nil : tmp.content

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
                      Refresh.log "NO IDENT: "#{title}'.", :warning
                      attrs[:title]
                    end
    attrs[:time] = if (tmp = post.at_css('published'))
                     tmp.content
                   elsif (tmp = post.at_css('date'))
                     tmp.content
                   elsif (tmp = post.at_css('dc|date'))
                     tmp.content
                   else
                     attrs[:status] = 'missing date'
                     Refresh.log "NO DATE: "#{title}'.", :warning
                     now.to_s
                   end
#    attrs[:published_at] = Time.parse(attrs[:time])
    attrs[:published_at] = Refresh.raw2time(attrs[:time])
    attrs[:url] = if !(link = post.at_css('link')).nil?
                   link['href']
                 elsif !(link = post.at_css('enclosure')).nil?
                   link['url']
                 else
                   p.status = 'missing URL'
                   Refresh.log "MISSING URL: '#{p.name}'.", :error
                   post.feed.rss_url
                 end
    attrs
  end

  def truncate(str, truncate_at, options = {})
    return str.dup unless str.length > truncate_at

    options[:omission] ||= '...'
    options[:omission] ||= ELLIPSIS
    length_with_room_for_omission = truncate_at - options[:omission].length
    stop = if options[:separator]
             str.rindex(options[:separator], length_with_room_for_omission) || length_with_room_for_omission
           else
             length_with_room_for_omission
           end
    "#{str[0...stop]}#{options[:omission]}"
  end
end
