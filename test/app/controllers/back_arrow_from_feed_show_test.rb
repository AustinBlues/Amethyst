require File.expand_path(File.dirname(__FILE__) + '/../../test_config.rb')
require 'nokogiri'

describe "/feed" do
  before do
    # Create Feed and Posts in database
    now = Time.now - PAGE_SIZE
    @feed = Feed.create(title: 'Feed 1', rss_url: 'http://127.0.0.1', previous_refresh: now, next_refresh: now)
    @posts = (PAGE_SIZE+5).times.map do |i|
      Post.create(feed_id: @feed[:id], ident: i, url: "http://127.0.0.1/#{i}", title: "Post #{i+1}",
                  description: "Post #{i+1} content.", published_at: now+i)
    end
    @origin = "/feed/#{@feed[:id]}?origin=#{CGI.escape('/feed')}"
  end

  after do
    Feed.all{|f| f.destroy}
#    Post.truncate
  end

  describe 'when showing a Feed' do
    it "should return Feed show, 2nd page" do
      get @origin
      assert_match(/#{@feed[:title]}/, last_response.body)
      assert_match(/#{@posts[0][:title]}/, last_response.body)
    end

    it 'should return earliest unread Post and all back links point to origin' do
      get "/post/#{@posts[0][:id]}?origin=#{CGI.escape(@origin)}"
      p = Nokogiri::HTML.parse(last_response.body)
      assert_equal(@posts[0][:description], p.at_css('p').content.strip)
      links = p.css('div.card a.btn')
      assert_equal('to Feed show', links[0].attr('title'))
      assert_match(@origin, links[0].attr('href'))
      # unclick, hide, down links
        (1..3).each do |i|
        assert_match(/origin=#{CGI.escape(@origin)}/, links[i].attr('href'))
      end
    end
  end
end
