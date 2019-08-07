class Feed < Sequel::Model
  def name
    title || rss_url
  end

  
  def page_number
    1
  end


  # Sequel dataset (query) for a slice of the oldest Feeds
  def self.slice(size)
    limit(size).order(:refresh_at)
  end


  # Sequel dataset (query) for Feeds to be refreshed on or before limit
  def self.refreshable(limit)
#    where{refresh_at <= limit}
    where(Sequel.lit('refresh_at <= ?', limit))
  end
end
