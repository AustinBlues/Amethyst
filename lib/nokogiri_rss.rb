# coding: utf-8
require 'nokogiri'


module NokogiriRSS
  def refresh_feed(feed, rss, now)
    if rss
      feed.status = nil
      begin
        f = Nokogiri::XML.parse(rss)
        begin
          case f.encoding
          when 'utf-8', 'UTF-8'
            # preferred/native/expected encoding
          when nil, ''
            Refresh.log 'NO ENCODING', :warning
          else
            Refresh.log "ENCODING: #{f.encoding.inspect}.", :error
          end
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
          elsif f.namespaces['xmlns:rdf']
            standard = 'RDF'
            feed.title = f.at_css('title').content
            item = f.css('item')
          else
            feed.status = 'Unknown Feed type'
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
                        parse_rss_item(post, feed)
                      when 'ATOM'
                        parse_atom_item(post, feed)
                      else
                        Refresh.log "METHODS: #{post.methods}", :debug
                        nil
                      end
              attrs[:title] = truncate(post.at_css('title').content, {length: VARCHAR_MAX, omission: ELLIPSIS})
              attrs[:title].strip!

              if attrs[:description].nil?
                attrs[:description] = 'No description'
                Refresh.log "MISSING DESCRIPTION: '#{attrs[:title]}.", :warning
              else
                attrs[:description].strip!
                attrs[:description] = truncate(attrs[:description], {length: TEXT_MAX, omission: ELLIPSIS})
              end

              if attrs[:title].empty?
                attrs[:title] = truncate(attrs[:description], {length: VARCHAR_MAX, omission: ELLIPSIS})
              end

              retries = 0
              begin
                new = nil	# force scope
                post = Post.update_or_create(feed_id: feed.id, ident: attrs[:ident]) do |p|
                  if (new = p.new?)
                    feed.ema_volume += ALPHA
                    # This is to be sure assignment done by write accessor, not directly to self[:description]
                    p.description = attrs.delete(:description)
                    attrs[:published_at] = Refresh.raw2time(attrs[:time])
                    p.set(attrs)
                  end
                  STDERR.puts("IDENT: #{p.inspect}.") if feed[:id] == 203
                  p.previous_refresh = now
                end
                Refresh.log("NEW: #{post.name}", :highlight) if new
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
    end

    feed.next_refresh = now + Refresh::CYCLE_TIME
    feed.save(changed: true)

    !rss.nil?
  end


  def parse_rss_item(post, feed)
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
                      feed.status = 'missing ident'
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
                     Refresh.log "NO DATE: '#{attrs[:title]}'.", :warning
                     Time.now.to_s
                   end
    attrs[:url] = if !(link = post.at_css('link')).nil?
                    link.content
                  elsif !(link = post.at_css('enclosure')).nil?
                    link['url']
                  else
                    p.feed.status = 'missing URL'
                    Refresh.log "MISSING URL: '#{p.name}'.", :error
                    post.feed.rss_url
                  end
    attrs
  end


  def parse_atom_item(post, feed)
    attrs = {}

    attrs[:title] = post.at_css('title')
    attrs[:description] = if (tmp = post.at_css('content'))
                            tmp.content
                          elsif (tmp = post.at_css('summary'))
                            tmp.content
                          else
                            nil
                          end

    if (tmp = post.at_css('summary'))
      attrs[:synopsis] = tmp.content
    end
    # NOTE: ident uses .to_s instead of .content for compatibility with RubyRSS module
    attrs[:ident] = if (tmp = post.at_css('id'))
                      tmp.to_s
                    elsif (tmp = post.at_css('link'))
                      tmp['href']
                    else
                      feed.status = 'missing ident'
                      Refresh.log "NO IDENT: "#{title}'.", :warning
                      attrs[:title]
                    end

    begin
      attrs[:time] = if (tmp = post.at_css('published'))
                       tmp.content
                     elsif (tmp = post.at_css('date'))
                       tmp.content
                     elsif (tmp = post.at_css('dc|date'))
                       tmp.content
                     else
                       attrs[:status] = 'missing date'
                       Refresh.log "NO DATE: "#{title}'.", :warning
                       Time.now.to_s
                     end
    rescue Nokogiri::XML::XPath::SyntaxError
      attrs[:time] = Time.now.to_s
    end
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
end
