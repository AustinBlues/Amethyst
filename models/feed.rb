class Feed < Sequel::Model
  one_to_many :post

  
  def before_create
    self[:score] ||= (Feed.count == 0) ? 0.0 : (Feed.avg(:score) + Feed.order(:score).first.score)/2.0
    # prevent refresh by Resque
    self[:next_refresh] = Time.now + Refresh::CYCLE_TIME
    super
  end

  
  def name
    title || rss_url
  end

  
  def page_number
    1
  end

  
  def add_score(amt)
    # refresh for new Feed may not have occurred yet, i.e. ema_volume == 0.0; so no low volume adjust
#    adjust = (self[:ema_volume] == 0.0) ? 1.0 : amt * (1.0 + [1.0/self[:ema_volume], 4.0].min)
    adjust = (self[:ema_volume] == 0.0) ? 1.0 : amt * (0.5 + [1.0/self[:ema_volume], 4.0].min)
    STDERR.puts "SCORE: #{adjust}."
    self[:score] += adjust
  end


  def unread
    Post.unread.where(feed_id: self[:id])
  end
  
  
  def before_destroy
    Post.where(feed_id: self[:id]).delete
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
