# All periodic refresh of Feeds policy is in this module.
#
require 'redis'
require 'nokogiri_rss'
#require 'ruby_rss'


module Refresh
  CYCLE_TIME = 60 * 60	# time to refresh all Feeds: 1 hour
  INTERVAL_TIME = 5 * 60	# how often to refresh a slice: 5 minutes
  INTERVALS = CYCLE_TIME/INTERVAL_TIME
  REDIS_KEY = 'residue'
  extend Padrino::Helpers::FormatHelpers
#  extend RubyRSS
  extend NokogiriRSS
  

  @@redis = Redis.new

  
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
      refresh_feed(Feed.with_pk(args), Time.now)
    else
      STDERR.puts "Invalid argument: #{args.inspect}."
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
      refresh_feed(f, now)
    end

    # Report progress
    tmp = (feeds.size == max_refresh) ? max_refresh : "#{feeds.size}:#{max_refresh}"
    puts "Fetched #{tmp}/#{feed_count} channels at #{Time.now.strftime('%l:%M%P').strip}."
  end
end
