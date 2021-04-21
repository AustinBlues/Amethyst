require File.expand_path(File.dirname(__FILE__) + '/../test_config.rb')

describe '/lib/nokogiri' do
  include NokogiriRSS

  before do
    rss_url = "file://#{File.expand_path(File.dirname(__FILE__))}/../../test_data/no_date.xml"
    @feed = Feed.create(rss_url: rss_url, title: 'No date')
  end

  after do
    @feed.destroy
  end

    
  it 'parsing XML with no date for an item' do
    refresh_feed(@feed, Time.now)
    assert_equal 'missing date', @feed.status
  end
end
