# All periodic refresh of Feeds policy is in this module.
#
require 'redis'
require 'redis-namespace'
require 'time'
require File.expand_path(File.dirname(__FILE__) + '/../app/helpers/post_helper.rb')
require File.expand_path(File.dirname(__FILE__) + '/../app/helpers/amethyst_helper.rb')
require 'logger'


module Refresh
  NOKOGIRI = true
  CYCLE_TIME = 60 * 60	# time to refresh all Feeds: 1 hour
  INTERVAL_TIME = 5 * 60	# how often to refresh a slice: 5 minutes
  INTERVALS = CYCLE_TIME/INTERVAL_TIME
  VERBOSITY = 2		# default sludge_filter() verbosity
  SLUDGE_HORIZON = 2*3600	# how long to log posts w/ sludge; currently 2 hours, i.e., twice
  REDIS_KEY = 'residue'
  extend NOKOGIRI ? NokogiriRSS : RubyRSS
  extend Padrino::Helpers::FormatHelpers
#  extend Amethyst::App::AmethystHelper
  extend Amethyst::App::PostHelper
  
  LVL2CLR = {error: :red, warning: :yellow, highlight: :green, info: :default, debug: :cyan, devel: :magenta}

  @@redis = Redis::Namespace.new(ROOT, redis: Redis.new)

  SLUDGE = ENV['SLUDGE'] || (ARGV.find{|f| f =~ /^SLUDGE=(.*)/} ? $~[1] : nil)


  def self.log(msg, level = :default)
    logger << msg.colorize(LVL2CLR[level] || :default)
  end


  def self.raw2time(raw)
    if false
      tmp = Time.parse(raw)	# good enough
      verbose = true
    else
      verbose = false
      tmp = case raw
            when /^[a-zA-Z]+, \d+ [a-zA-Z]+ \d+ \d+:\d+:\d+ [-+]\d+$/
              time = Time.rfc2822(raw)
#              STDERR.puts "RFC2822: '#{raw}' => '#{time}' (#{time.zone})"
              time
            when /^[a-zA-Z]+, \d+ [a-zA-Z]+ \d+ \d+:\d{2}(:\d{2})? \w+( \w+)?$/
              # unsure what standard this is
              time = Time.parse(raw)
            when /^\d{4}-?\d{2}-?\d{2}T\d{2}:?\d{2}:?\d{2}(\.\d{2,3})?(Z|[+-]\d{2}:?\d{2})$/
              # this case ISO8601 can also be handled by Time.parse
              time = Time.iso8601(raw)
              STDERR.puts("ISO8601: '#{raw}' => '#{time}' (#{time.zone})") unless time.zone == 'UTC'
              time
            when /^[a-zA-Z]+, \d+ [a-zA-Z]+ \d+ \d+:\d+:\d+ (GMT|UTC)$/
              time = Time.httpdate(raw)
#              STDERR.puts "RFC 2616: '#{raw}' => '#{time}' (#{time.zone})"
              time
            when /^\d{4}-?\d{2}-?\d{2} \d{2}:?\d{2}:?\d{2} [+-]\d{2}:?\d{2}/
              # unsure what standard this is
              time = Time.parse(raw)
            else
              time = Time.parse(raw)
              verbose = true
              time
            end
    end
    STDERR.puts("TIME: '#{raw}' => '#{tmp}' (#{tmp.zone})") if verbose 
#    STDERR.puts("TIME: '#{raw}' => '#{tmp}' (#{tmp.zone})") if tmp.zone.nil?
    tmp.localtime
  end

  
  def self.time_ago_in_words(from_time, include_seconds = false)
    distance_in_minutes = ((Time.now - from_time) / 60.0).round
    case distance_in_minutes
    when 2..99
      "#{distance_in_minutes} minutes"
    else
      distance_of_time_in_words(from_time, Time.now, include_seconds)
    end
  end


  def self.perform(args = nil)
    begin
      if args.nil?
        refresh_slice
      elsif args.is_a?(Integer)
        time = Time.now
        if args < 0
          f = Feed.with_pk(-args)
          log("Deleting: #{f.name} at #{short_datetime(time)}.")
          f.destroy
        else          
          f = Feed.with_pk(args)
          refresh_feed(f, fetch(f), time)
          @@redis.INCR(REDIS_KEY)
          log("First fetch: #{f.name} at #{short_datetime(time)}.")
        end
      else
        log("Invalid argument: #{args.inspect}.", :error)
      end
    rescue
      log("REFRESH: #{$!.inspect}.", :error)
      puts $!.backtrace
    end
  end


  def self.sludge_filter(feed, search, verbosity = VERBOSITY)
    raise ArgumentError if search.nil?

    sql = Post.where(true).full_text_search([:title, :description], search).sql
    m = /\((MATCH .*\))\)\)/.match(sql)
    if !m
      log('OOPS: MATCH expression not found', :error)
    else
      exp = m[1]
      exp <<= ' AS score'
      query = Post.select(:id, :title, :description, Sequel.lit(exp)).where(state: Post::UNREAD).
                where{published_at >= Time.now - (SLUDGE_HORIZON+Refresh::INTERVAL_TIME)}
      case feed
      when Feed
        query = query.where(feed_id: feed.id)
      when Integer
        query = query.where(feed_id: feed)
      when Array
        query = query.where(feed_id: feed)
      end
      boolean = search =~ /[-+<>(~*"]+/
      query = query.full_text_search([:title, :description], search, boolean: boolean)
      log(query.sql, :debug) if verbosity >= 3
      query.each do |q|
        if q[:score] >= 0.5
          if verbosity >= 0
            log("(#{'%0.2f' % q[:score]}) #{!q[:title].empty? ? q[:title] : q[:description]}".colorize(:red))
          end
          if false
            q.update(state: Post::HIDDEN)
          else
            post = Post[q[:id]]
            post.down_vote!
            post.save(changed: true)
          end
        elsif q[:score] >= 0.25
          q.update(state: Post::HIDDEN)
          if verbosity >= 1
            log("(#{'%0.2f' % q[:score]}) #{!q[:title].empty? ? q[:title] : q[:description]}".colorize(:yellow))
          end
        else
          if verbosity >= 2
            log("(#{'%0.2f' % q[:score]}) #{!q[:title].empty? ? q[:title] : q[:description]}".colorize(:magenta))
          end
        end
      end
    end
  end


  def self.fetch(feed)
    rss = nil	# force scope
    url = feed.rss_url
    tries = 3
    begin
      uri = URI.parse(url)
      f = uri.open(redirect: false)
    rescue OpenURI::HTTPRedirect => redirect
      url = redirect.uri.to_s
      case redirect.to_s
      when /^302 /
        log "Temporary redirect to '#{url}'.", :info
      when /^301 /
        log "Permanent redirect to '#{url}'.", :info
        feed.status = 'Permanent redirect.'
        feed.rss_url = url
      else
        log "Unknown redirect to '#{url}' - #{redirect.to_s}.", :error
        feed.status = 'Unknown redirect'
      end
      retry if (tries -= 1) > 0
    rescue OpenURI::HTTPError => e
      if e.to_s =~ /^302 /
        log "Temporary redirect: '#{e}' - #{e.inspect}.", :info
      else
        log "Error fetching '#{feed.name}': #{$!}.", :error
        feed.status = "HTTP error - #{e}"
      end
    rescue SocketError, Errno::ENETUNREACH
      log "No network connection to '#{feed.name}.", :error
      feed.status = 'no network connection'
    rescue
      log "EXCEPTION(#{$!.class.to_s}): #{$!}.", :error
    else
      rss = f.read
      log("Feed '#{url}' is empty or non-existant.", :warning) if rss.size == 0
    end

    rss
  end


  def self.refresh_slice
    # grab time now before lengthy downloads
    now = Time.now

    max_refresh = Feed.refreshable(now + INTERVAL_TIME/2).count

    # Refresh distribution of uneven slices
    residue = (@@redis.get(REDIS_KEY) || 0).to_i
    feed_count = Feed.count
    slice_size, residue = (feed_count + residue).divmod(INTERVALS)
    @@redis.set(REDIS_KEY, residue)
    
    if slice_size == 0
      log "Nothing to fetch at #{Time.now.strftime('%l:%M%P').strip}."
    else
      # Update all Feeds in the slice
      feeds = Feed.slice(slice_size, now + INTERVAL_TIME/2)
      if (fetch_cnt = feeds.count) <= 0
        log "Too early to fetch any feeds.", :warning
      else
        feeds.each do |f|
          refreshed_at = f.previous_refresh
          if refresh_feed(f, fetch(f), now)
            sludge_filter(f, SLUDGE) if SLUDGE

            # Hide unread Posts older than UNREAD_LIMIT
            cutoff = Post.where(feed_id: f[:id], state: Post::UNREAD).order(Sequel.desc(:published_at)).
                       offset(UNREAD_LIMIT-1).get(:published_at)
            if cutoff
              n = Post.where(feed_id: f[:id], state: Post::UNREAD).where{published_at < cutoff}.update(state: Post::HIDDEN)
              log("Hiding #{n} older post(s).", :debug) if n > 0
            end
          end
          
          if refreshed_at
            log "Previous '#{f.name}' refresh #{Refresh.time_ago_in_words(refreshed_at, true)} ago."
          else
            log "Refreshed '#{f.name}' (no previous refresh)."
          end
        end
      
        # Report progress.  The second case is when Amethyst catching up after not running (e.g. hibernation).
        tmp = (fetch_cnt == max_refresh) ? max_refresh : "#{fetch_cnt}:#{max_refresh}"
        log "Fetched #{tmp}/#{feed_count} channels at #{Time.now.strftime('%l:%M%P').strip}."
      end
    end
  end
end
