require File.expand_path(File.dirname(__FILE__) + '/../app/helpers/amethyst_helper.rb')

class Feed < Sequel::Model
  one_to_many :post
  extend Amethyst::App::AmethystHelper

  
  def before_create
    # Set score so initially in the middle of the Feed.index
    self[:score] ||= (Feed.count == 0) ? 0.0 : (Feed.avg(:score) + Feed.order(:score).first.score)/2.0
    super
  end


  def after_create
    super
    # Initial queue is highest priority (higher than Refresh or daily).
    Resque.enqueue_to('Initial', Refresh, self[:id]) if Padrino.env != :test
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
  def self.slice(size, horizon)
    (size == 0) ? [] : exclude(next_refresh: nil).where{next_refresh <= horizon}.limit(size).order(:next_refresh)
  end


  # Sequel dataset (query) for Feeds to be refreshed on or before limit
  def self.refreshable(horizon)
    exclude(next_refresh: nil).where(Sequel.lit('next_refresh <= ?', horizon))
  end

  def self.age
    dataset.update(score: Sequel[:score]*(1.0 - ALPHA))
    dataset.update(ema_volume: Sequel[:ema_volume]*(1.0 - ALPHA))
  end
end
