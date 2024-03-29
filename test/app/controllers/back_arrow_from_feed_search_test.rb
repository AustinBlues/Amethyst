require File.expand_path(File.dirname(__FILE__) + '/../../test_config.rb')
require 'nokogiri'

describe "/feed" do
  EXTRA = 5

  before do
    Feed.all{|f| f.destroy}
    # Create Feed and Posts in database
    now = Time.now - PAGE_SIZE
    @feed = Feed.create(title: 'Feed 1', rss_url: 'http://127.0.0.1', next_refresh: now)
    @posts = (PAGE_SIZE+EXTRA).times.map do |i|
      Post.create(feed_id: @feed[:id], ident: i, url: "http://127.0.0.1/#{i}", title: "Post #{i+1}",
                  description: "Post #{i+1} content.", published_at: now+i)
    end

    @origin = "/feed"
  end

  after do
    Feed.all{|f| f.destroy}
#    Post.truncate
  end


  describe 'when showing Feeds index' do
    it "should return Feed index, 1st page" do
      get @origin
      assert_match(/Feeds/, last_response.body)
      assert_match(/#{@feed[:title]}/, last_response.body)
    end

    it 'should return oldest Post and all back links point to origin' do
      get "/post/search?page=2&search=Post&origin=#{CGI.escape(@origin)}"
      p = Nokogiri::HTML.parse(last_response.body)
#      puts last_response.body
      assert_equal(@posts[EXTRA-1][:title], p.at_css('td a').content.strip)
      l = p.at_css('div.card-header a.btn')
      assert_equal('to Feeds', l.attr('title'))
      assert_match(@origin, l.attr('href'))
    end
  end
end
