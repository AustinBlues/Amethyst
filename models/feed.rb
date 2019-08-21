class Feed < Sequel::Model
  one_to_many :post
  
  def name
    title || rss_url
  end

  
  def page_number
    1
  end


  # Sequel dataset (query) for a slice of the oldest Feeds
  def self.slice(size)
    limit(size).order(:previous_refresh)
  end


  # Sequel dataset (query) for Feeds to be refreshed on or before limit
  def self.refreshable(limit)
#    where{previous_refresh <= limit}
    where(Sequel.lit('previous_refresh <= ?', limit))
  end

  def self.age
    dataset.update(score: Sequel[:score]*(1.0 - Aging::ALPHA))
    dataset.update(ema_volume: Sequel[:ema_volume]*(1.0 - Aging::ALPHA))
  end
end
