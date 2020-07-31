require File.expand_path(File.dirname(__FILE__) + '/../../test_config.rb')
require 'nokogiri'

describe "/feed" do
  before do
    # Create Feed and Posts in database
    now = Time.now - PAGE_SIZE
    @feed = Feed.create(title: 'Feed 1', rss_url: 'http://127.0.0.1', previous_refresh: now)
    @posts = (PAGE_SIZE+5).times.map do |i|
      Post.create(title: "Post #{i+1}", feed_id: @feed[:id], ident: i, url: "http://127.0.0.1/#{i}",
                  description: "Post #{i+1} content.", published_at: now+i)
    end
    @origin = "/feed/#{@feed[:id]}?page=2"
  end

  after do
    Feed.truncate
    Post.truncate
  end

  describe 'when showing a Feed' do
    it "should return Feed show, 2nd page and earlist unread Posts" do
      get @origin
      assert_match(/#{@feed[:title]}/, last_response.body)
      assert_match(/#{@posts[0][:title]}/, last_response.body)
      # TODO check all Post for correct HIDE and DOWN links
    end

    it 'should return earliest unread Post and all back links point to origin' do
      get "/post/1?origin=#{CGI.escape(@origin)}"
      p = Nokogiri::HTML.parse(last_response.body)
      assert_equal(@posts[0][:description], p.at_css('p').content.strip)
      links = p.css('div.card a.btn')
      assert_equal('to Feed show', links[0].attr('title'))
      assert_match(@origin, links[0].attr('href'))
      # unclick, hide, down links
      if false
        (1..3).each do |i|
          puts "HREF: #{links[i].attr('href')}."
          assert_match(/origin=#{CGI.escape(@origin)}/, links[i].attr('href'))
        end
      else
        @unclick = links[1].attr('href')
        assert_equal("/post/1/unclick?origin=#{CGI.escape(@origin)}", @unclick)
        @hide = links[2].attr('href')
        assert_equal("/post/1/hide?origin=#{CGI.escape(@origin)}", @hide)
        @down = links[3].attr('href')
        assert_equal("/post/1/down?origin=#{CGI.escape(@origin)}", @down)
      end

      get @unclick
      assert_equal("http://example.org#{@origin}", last_response.location.encode('utf-8'))
      get @hide
      assert_equal("http://example.org#{@origin}", last_response.location.encode('utf-8'))
      get @down
      assert_equal("http://example.org#{@origin}", last_response.location.encode('utf-8'))
    end
  end
end
