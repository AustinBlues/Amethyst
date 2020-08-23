# All periodic refresh of Feeds policy is in this module.
#
require 'redis'
require 'nokogiri_rss'
require 'time'
#require 'ruby_rss'
require File.expand_path(File.dirname(__FILE__) + '/../app/helpers/amethyst_helper.rb')
require 'logger'

module Refresh
  CYCLE_TIME = 60 * 60	# time to refresh all Feeds: 1 hour
  INTERVAL_TIME = 5 * 60	# how often to refresh a slice: 5 minutes
  INTERVALS = CYCLE_TIME/INTERVAL_TIME
  REDIS_KEY = 'residue'
  extend Padrino::Helpers::FormatHelpers
#  extend RubyRSS
  extend NokogiriRSS
  extend Amethyst::App::AmethystHelper

  @@redis = Redis.new


  def self.raw2time(raw)
    verbose = false
    if true
      tmp = Time.parse(raw)
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
    if args.nil?
      refresh_slice
    elsif args.is_a?(Integer)
      time = Time.now
      f = Feed.with_pk(args)
      refresh_feed(f, time)
      Refresh.log "First fetch: #{f.name} at #{short_datetime(time)}."
    else
      log "Invalid argument: #{args.inspect}.", :error
    end
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

    # Update all Feeds in the slice
    feeds = Feed.slice(slice_size).all
    feeds.each do |f|
      refreshed_at = f.previous_refresh
      refresh_feed(f, now)

      # Hide unread Posts older than UNREAD_LIMIT
      cutoff = Post.where(feed_id: f[:id], state: Post::UNREAD).order(Sequel.desc(:published_at)).
                 offset(UNREAD_LIMIT-1).get(:published_at)
      if cutoff
        n = Post.where(feed_id: f[:id], state: Post::UNREAD).where{published_at < cutoff}.update(state: Post::HIDDEN)
        log("Hiding #{n} older post(s).", :debug) if n > 0
      end
      
      if refreshed_at
        Refresh.log "Refreshed #{Refresh.time_ago_in_words(refreshed_at, true)} ago: #{f.name}."
      else
        Refresh.log "Refreshed (no previous refresh): #{f.name}."
      end
    end

    sludge = nil
    if sludge = ENV['SLUDGE']
      # run Sludge filter is AGAINST string supplied as export
    elsif ARGV.find{|f| f =~ /^SLUDGE=(.*)/}
      # run Sludge filter is AGAINST string supplied on command line
      sludge = $~[1]
    end
    Sludge.filter(feeds.map{|f| f[:id]}, sludge, 0) if sludge

    # Report progress.  The second case is when Amethyst catching up after not running (e.g. hibernation).
    tmp = (feeds.size == max_refresh) ? max_refresh : "#{feeds.size}:#{max_refresh}"
    log "Fetched #{tmp}/#{feed_count} channels at #{Time.now.strftime('%l:%M%P').strip}."
  end
end
