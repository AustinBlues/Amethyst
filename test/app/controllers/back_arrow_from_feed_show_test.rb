require File.expand_path(File.dirname(__FILE__) + '/../../test_config.rb')

describe "/feed" do
  before do
    # Create Feed and Posts in database
    @feed = Feed.create(title: 'Feed 1', rss_url: 'http://127.0.0.1', previous_refresh: Time.now)
    (PAGE_SIZE+5).times do |i|
      Post.create(title: "Post #{i}", feed_id: @feed[:id], ident: i, url: "http://127.0.0.1/#{i}", published_at: Time.now)
    end
  end

  after do
    Feed.truncate
    Post.truncate
  end

  
  it "should return Feeds index" do
    get "/feed/#{@feed[:id]}?page=2"
    assert_match(/#{@feed[:title]}/, last_response.body)
  end
end
