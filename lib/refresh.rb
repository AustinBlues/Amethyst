# All periodic refresh of Feeds policy is in this module.
#
require 'redis'
require 'ruby_rss'


module Refresh
  CYCLE_TIME = 60 * 60	# time to refresh all Feeds: 1 hour
  INTERVAL_TIME = 5 * 60	# how often to refresh a slice: 5 minutes
  INTERVALS = CYCLE_TIME/INTERVAL_TIME
  REDIS_KEY = 'residue'
  include RubyRSS
  
  @@redis = Redis.new


  def self.perform
    # grab time now before lengthy downloads
    now = Time.now
    next_refresh = now + CYCLE_TIME
    max_refresh = Feed.refreshable(now - CYCLE_TIME + INTERVAL_TIME/2).count

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
      puts "Refreshed: #{f.name} (#{refreshed_at})."
      f.previous_refresh = now
      f.save
    end

    # Report progress
    tmp = (feeds.size == max_refresh) ? max_refresh : "#{feeds.size}:#{max_refresh}"
    puts "Fetched #{tmp}/#{feed_count} channels at #{Time.now.strftime('%H:%M')}."
  end
end
