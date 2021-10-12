require File.expand_path(File.dirname(__FILE__) + '/../app/helpers/amethyst_helper.rb')

class Feed < Sequel::Model
  one_to_many :post
  extend Amethyst::App::AmethystHelper

  @@entities_decoder = HTMLEntities.new	# DB handles UTF-8/Unicode


  def before_create
    self[:title] = @@entities_decoder.decode(self[:title]) if self[:title]	# preserve nil
    # Set score initially in the middle of the Feed.index
    self[:score] ||= (Feed.count == 0) ? 0.0 : (Feed.avg(:score) + Feed.order(:score).first.score)/2.0
    super
  end


  def before_save
    if changed_columns.include?(:rss_url)
      # Initial queue is highest priority (higher than Refresh or daily).
      Resque.enqueue_to('Initial', Refresh, self[:id]) if Padrino.env != :test
    end
    super
  end


  def after_create
    super
    # Initial queue is highest priority (higher than Refresh or daily).
    Resque.enqueue_to('Initial', Refresh, self[:id]) if Padrino.env != :test
  end

  
  def name
    (self[:title] && !self[:title].empty?) ? self[:title] : rss_url
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
    # TODO when is next_refresh nil?
#    (size == 0) ? [] : exclude(next_refresh: nil).where{next_refresh <= horizon}.limit(size).order(:next_refresh)
    # is the below safer or faste?
    (size == 0) ? [] : exclude(next_refresh: nil).where(Sequel.lit('next_refresh <= ?', horizon)).
                         limit(size).order(:next_refresh)
#    (size == 0) ? [] : limit(size).order(:next_refresh)
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
