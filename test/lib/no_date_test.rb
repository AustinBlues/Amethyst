require File.expand_path(File.dirname(__FILE__) + '/../test_config.rb')
#require File.expand_path(File.dirname(__FILE__) + '/../../lib/nokogiri_rss.rb')

describe '/lib/nokogiri' do
  before do
    assert Refresh::NOKOGIRI
    rss_url = "file://#{File.expand_path(File.dirname(__FILE__))}/../../test_data/no_date.xml"
    @feed = Feed.create(rss_url: rss_url, title: 'No date')
  end

  after do
    @feed.destroy if @feed
  end

    
  it 'parsing XML with no date for an item' do
    Refresh.refresh_feed(@feed, Time.now)

    assert_equal 'missing date', @feed.status
  end
end
