class Feed < Sequel::Model
  one_to_many :post
  
  def name
    title || rss_url
  end

  
  def page_number
    1
  end

  def add_score(amt)
    STDERR.puts "SCORE: #{amt + [2.0/self[:ema_volume], amt].min}."
    self[:score] += amt + [2.0/self[:ema_volume], amt].min
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
