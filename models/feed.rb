require File.expand_path(File.dirname(__FILE__) + '/../app/helpers/amethyst_helper.rb')

# Just enough to make Resque work
module Refresh
  @queue = :Refresh
end


class Feed < Sequel::Model
  one_to_many :post
  extend Amethyst::App::AmethystHelper

  
  def before_create
    self[:score] ||= (Feed.count == 0) ? 0.0 : (Feed.avg(:score) + Feed.order(:score).first.score)/2.0
    # KLUDGE: can't ensure, can only make unlikely.  Not really a problem if it is.  No new Post.
#    # ensure won't be refreshed by periodic Refresh.perform calling Refresh.refresh_slice
#    self[:next_refresh] = Time.now + Refresh::INTERVAL_TIME
    super
  end

  def after_create
    super
    Resque.enqueue(Refresh, self[:id]) if Padrino.env != :test
  end

  
  def name
    (title.nil? || title.empty?) ? rss_url : title
  end

  
  def page_number
    tmp = Feed.where(id: self[:id]).select(:score)
    Feed.page_number(Feed.where{score >= tmp}.count)
  end

  
  def add_score(amt)
    # refresh for new Feed may not have occurred yet, i.e. ema_volume == 0.0; so no low volume adjust
#    adjust = (self[:ema_volume] == 0.0) ? 1.0 : amt * (0.5 + [0.25/self[:ema_volume], 3.0].min)
#    adjust = (self[:ema_volume] == 0.0) ? 1.0 : amt * (0.6 + [0.25/self[:ema_volume], 2.0].min)
    adjust = (self[:ema_volume] == 0.0) ? 1.0 : amt * (0.3 + [0.25/self[:ema_volume], 2.0].min)
    self[:score] += adjust
  end


  def unread
    Post.unread.where(feed_id: self[:id])
  end
  
  
  def before_destroy
    Post.where(feed_id: self[:id]).destroy
    super
  end
  
  
  # Sequel dataset (query) for a slice of the oldest Feeds
  def self.slice(size)
    limit(size).order(:next_refresh)
  end


  # Sequel dataset (query) for Feeds to be refreshed on or before limit
  def self.refreshable(limit)
    where(Sequel.lit('next_refresh <= ?', limit))
  end

  def self.age
    dataset.update(score: Sequel[:score]*(1.0 - Aging::ALPHA))
    dataset.update(ema_volume: Sequel[:ema_volume]*(1.0 - Aging::ALPHA))
  end
end
