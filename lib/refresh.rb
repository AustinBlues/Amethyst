# All periodic refresh of Feeds policy is in this module.
#
require "redis"


module Refresh
  CYCLE_TIME = 3600	# time to refresh all Feeds: 1 hour
  INTERVAL_TIME = 300	# how often to refresh a slice: 5 minutes
  INTERVALS = CYCLE_TIME/INTERVAL_TIME
  REDIS_KEY = 'residue'
  
  @@redis = Redis.new


  def self.perform
    now = Time.now
    next_refresh = now + CYCLE_TIME
    max_refresh = Feed.where{refresh_at <= now + INTERVAL_TIME/2}.count

    residue = (@@redis.get(REDIS_KEY) || 0).to_i
    feed_count = Feed.count
    slice = (feed_count + residue) / INTERVALS
    residue = (feed_count + residue) % INTERVALS
    @@redis.set(REDIS_KEY, residue)

    feeds = Feed.limit(slice).order(:refresh_at).all
    feeds.each do |f|
      puts "Refresh: #{f.name} (#{f.refresh_at})."
      f.refresh_at = next_refresh
      f.save
    end
    
    tmp = (feeds.size == max_refresh) ? max_refresh : "#{feeds.size}:#{max_refresh}"
    puts "Fetched #{tmp}/#{feed_count} channels at #{Time.now.strftime('%H:%M')}."
  end
end
