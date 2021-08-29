# All periodic refresh of Feeds policy is in this module.
#
require 'redis'
require 'redis-namespace'
if false
  require 'nokogiri_rss'
else
  require 'ruby_rss'
end
require 'time'
require File.expand_path(File.dirname(__FILE__) + '/../app/helpers/post_helper.rb')
require File.expand_path(File.dirname(__FILE__) + '/../app/helpers/amethyst_helper.rb')
require 'logger'


module Refresh
  CYCLE_TIME = 60 * 60	# time to refresh all Feeds: 1 hour
  INTERVAL_TIME = 5 * 60	# how often to refresh a slice: 5 minutes
  INTERVALS = CYCLE_TIME/INTERVAL_TIME
  VERBOSITY = 2		# default sludge_filter() verbosity
  SLUDGE_HORIZON = 2*3600	# how long to log posts w/ sludge; currently 2 hours, i.e., twice
  REDIS_KEY = 'residue'
  extend Padrino::Helpers::FormatHelpers
  extend Amethyst::App::AmethystHelper
  extend Amethyst::App::PostHelper

  # fetch() parameters
  LIBCURL = 1
  CURL = 2
  WGET = 3
  MAX_METHOD = 3

  @@curl = Curl::Easy.new
  @@curl.follow_location = true
  
  LVL2CLR = {error: :red, warning: :yellow, highlight: :green, info: :default, debug: :cyan, devel: :magenta}

  @@redis = Redis::Namespace.new(ROOT, redis: Redis.new)

  SLUDGE = ENV['SLUDGE'] || (ARGV.find{|f| f =~ /^SLUDGE=(.*)/} ? $~[1] : nil)


  def self.log(msg, level = :default)
    logger << msg.colorize(LVL2CLR[level] || :default)
  end


  def self.raw2time(raw)
    verbose = false
    if true
      tmp = Time.parse(raw)	# good enough
      verbose = true
    else
      tmp = case raw
            when /^[a-zA-Z]+, \d+ [a-zA-Z]+ \d+ \d+:\d+:\d+ [-+]\d+$/
              time = Time.rfc2822(raw)
#              STDERR.puts "RFC2822: '#{raw}' => '#{time}' (#{time.zone})"
              time
            # this case ISO8601 can also be handled by Time.parse
            when /^\d+-\d+-\d+T\d+:\d+:\d+-\d+:\d+$/
              time = Time.iso8601(raw)
#              STDERR.puts "ISO8601: '#{raw}' => '#{time}' (#{time.zone})"
              time
            when /^[a-zA-Z]+, \d+ [a-zA-Z]+ \d+ \d+:\d+:\d+ (GMT|UTC)$/
              time = Time.httpdate(raw)
#              STDERR.puts "RFC 2616: '#{raw}' => '#{time}' (#{time.zone})"
              time
            else
              time = Time.parse(raw)
              verbose = true
              time
            end
    end
    # KLUDGE
    tmp = tmp.localtime if tmp.zone.nil?
#    STDERR.puts("TIME: '#{raw}' => '#{tmp}' (#{tmp.zone})") if verbose 
    STDERR.puts("TIME: '#{raw}' => '#{tmp}' (#{tmp.zone})") if tmp.zone.nil?
    tmp
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
          refresh_feed(f, time)
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


  def self.fetch(url)
    # open-uri appears to be gagging on IPv6 addresses and doesn't support forcing to IPv4

    rss = nil	# force scope
    method = 0
    while method < MAX_METHOD && (rss.nil? || rss.size == 0) do
      method += 1
      case method
      when LIBCURL
        @@curl.url = url
        begin
          @@curl.perform
        rescue
          STDERR.puts "Exception: #{$!.class.to_s.split('::').last}"
        else
          @@curl = @@curl
#          puts "CURB: #{@@curl.inspect}."
#          puts "CURB: #{@@curl.body.size}."
          puts "CURB: #{@@curl.body}." if 0 < @@curl.body.size && @@curl.body.size < 1000	# debug
          rss = @@curl.body
        end
      when WGET
        rss = %x(wget '#{url}' -4 -q -O -)
        puts "WGET: #{rss.size}."
        rss = nil if $?.to_s !~ /exit 0/
      when CURL
#        rss = %x(curl -s -4 '#{url}')
        rss = %x(curl -s -L '#{url}')
        puts "CURL: #{rss.size}."
        rss = nil if $?.to_s !~ /exit 0/
      else
        raise "PROGRAMMER ERROR"
      end
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
    slice_size = (feed_count + residue) / INTERVALS
    residue = (feed_count + residue) % INTERVALS
    @@redis.set(REDIS_KEY, residue)
    
    if slice_size == 0
      log "Nothing to fetch at #{Time.now.strftime('%l:%M%P').strip}."
    else
      # Update all Feeds in the slice
      feeds = Feed.slice(slice_size)
      feeds.each do |f|
        refreshed_at = f.previous_refresh
        refresh_feed(f, now)

        sludge_filter(f, SLUDGE) if SLUDGE
      
        # Hide unread Posts older than UNREAD_LIMIT
        cutoff = Post.where(feed_id: f[:id], state: Post::UNREAD).order(Sequel.desc(:published_at)).
                   offset(UNREAD_LIMIT-1).get(:published_at)
        if cutoff
          n = Post.where(feed_id: f[:id], state: Post::UNREAD).where{published_at < cutoff}.update(state: Post::HIDDEN)
          log("Hiding #{n} older post(s).", :debug) if n > 0
        end

        if refreshed_at
          log "Refreshed #{Refresh.time_ago_in_words(refreshed_at, true)} ago: #{f.name}."
        else
          log "Refreshed (no previous refresh): #{f.name}."
        end
      end

      # Report progress.  The second case is when Amethyst catching up after not running (e.g. hibernation).
      tmp = (feeds.count == max_refresh) ? max_refresh : "#{feeds.count}:#{max_refresh}"
      log "Fetched #{tmp}/#{feed_count} channels at #{Time.now.strftime('%l:%M%P').strip}."
    end
  end
end
