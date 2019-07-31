class Feed < Sequel::Model
  def name
    title || rss_url
  end

  
  def page_number
    1
  end
end
