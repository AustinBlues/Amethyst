require File.expand_path(File.dirname(__FILE__) + '/../test_config.rb')
#require File.expand_path(File.dirname(__FILE__) + '/../../lib/nokogiri_rss.rb')

describe '/lib/nokogiri' do
  before do
    rss_url = "file://#{File.expand_path(File.dirname(__FILE__))}/../../test_data/no_date.xml"
    @feed = Feed.create(rss_url: rss_url, title: 'No date')
  end

  after do
    @feed.destroy if @feed
  end

    
  it 'parsing XML with no date for an item' do
    now = Time.now
    Refresh.refresh_feed(@feed, Refresh.fetch(@feed), now)

    if defined?(Refresh::NOKOGIRI) && Refresh::NOKOGIRI
      assert_equal 'missing date', @feed.status
    else
      # RubyRSS doesn't check for no datetime
      assert_equal now.to_s, (@feed.next_refresh - Refresh::CYCLE_TIME).to_s
    end
  end
end
