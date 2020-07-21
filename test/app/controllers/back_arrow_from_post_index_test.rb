require File.expand_path(File.dirname(__FILE__) + '/../../test_config.rb')
require 'nokogiri'

describe "/feed" do
  before do
    # Create Feed and Posts in database
    now = Time.now - PAGE_SIZE
    @test_feed = Feed.create(title: 'Feed 1', rss_url: 'http://127.0.0.1', previous_refresh: now)
    @test_posts = (PAGE_SIZE+5).times.map do |i|
      Post.create(title: "Post #{i+1}", feed_id: @test_feed[:id], ident: i, url: "http://127.0.0.1/#{i}",
                  description: "Post #{i+1} content.", published_at: now+i)
    end
    @test_origin = "/post?page=2"
  end

  after do
    Feed.truncate
    Post.truncate
  end

  describe 'when showing Post index' do
    it "should return Feed show, 2nd page" do
      get @test_origin
      assert_match(/#{@test_posts[0][:title]}/, last_response.body)
    end

    it 'should return earliest unread Post and all back links point to origin' do
      get "/post/1?origin=#{CGI.escape(@test_origin)}"
      p = Nokogiri::HTML.parse(last_response.body)
      assert_equal(@test_posts[0][:description], p.at_css('p').content.strip)
      links = p.css('div.card a.btn')
      assert_equal('to Posts', links[0].attr('title'))
      assert_match(@test_origin, links[0].attr('href'))
      # unclick, hide, down links
        (1..3).each do |i|
        assert_match(/origin=#{CGI.escape(@test_origin)}/, links[i].attr('href'))
      end
    end
  end
end
