# All periodic refresh of Feeds policy is in this module.
#
require 'redis'
require 'ruby_rss'


module Refresh
  CYCLE_TIME = 60 * 60	# time to refresh all Feeds: 1 hour
  INTERVAL_TIME = 5 * 60	# how often to refresh a slice: 5 minutes
  INTERVALS = CYCLE_TIME/INTERVAL_TIME
  REDIS_KEY = 'residue'
  extend RubyRSS
  extend Padrino::Helpers::FormatHelpers


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


  def self.perform
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
      f.status = nil
      refreshed_at = f.previous_refresh
      RubyRSS.refresh_feed(f, now)
      if refreshed_at
        puts "Refreshed: #{f.name} (#{time_ago_in_words(refreshed_at, true)} ago)."
      else
        puts "Refreshed: #{f.name} (no previous refresh)."
      end
      f.update(next_refresh: now + CYCLE_TIME, previous_refresh: f.previous_refresh, ema_volume: f.ema_volume)
    end

    # Report progress
    tmp = (feeds.size == max_refresh) ? max_refresh : "#{feeds.size}:#{max_refresh}"
    puts "Fetched #{tmp}/#{feed_count} channels at #{Time.now.strftime('%l:%M%P').strip}."
  end
end
