require File.expand_path(File.dirname(__FILE__) + '/../../test_config.rb')
require 'nokogiri'


describe '/feed/search' do
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


  describe 'when displaying Feeds show' do
    it 'should return Feed show, page 2' do
      get @origin
      assert_match(/Feeds/, last_response.body)
      assert_match(/#{@feed[:title]}/, last_response.body)
    end

    it 'should return all Posts' do
      get "/post/search?search=Post&origin=#{CGI.escape(@origin)}"
      p = Nokogiri::HTML.parse(last_response.body)
#      puts last_response.body
      assert_equal(@posts[0][:title], p.at_css('td a').content.strip)
      l = p.at_css('div.card-header a.btn')
      # KLUDGE this is how it is.  Maybe it show read 'to Feed show'
      assert_equal('to Feeds', l.attr('title'))
      assert_match(@origin, l.attr('href'))

      # hide, down links
      actions = p.css('a.action')
      hide = actions[0].attr('href')
      assert_equal("/post/#{@posts[0][:id]}/hide?origin=#{CGI.escape(@origin)}", hide)
      down = actions[1].attr('href')
      assert_equal("/post/#{@posts[0][:id]}/down?origin=#{CGI.escape(@origin)}", down)

      # check HIDE and DOWN have expected redirect
      get hide
      assert_equal("http://example.org#{@origin}", last_response.location.encode('utf-8'))
      get down
      assert_equal("http://example.org#{@origin}", last_response.location.encode('utf-8'))

      # check Post show for correct action links
      get "/post/#{@posts[0][:id]}?origin=#{CGI.escape(@origin)}"
      p = Nokogiri::HTML.parse(last_response.body)
      
      # check Post show has expected description
      assert_equal(@posts[0][:description], p.at_css('p').content.strip)
      
      links = p.css('a.btn')
      # back arrow (LEFT_ARROW)
      assert_equal('to Feed show', links[0].attr('title'))
      assert_match(@origin, links[0].attr('href'))

      # UNCLICK, HIDE, and DOWN links
      (1..3).each do |i|
        assert_match(/origin=#{CGI.escape(@origin)}/, links[i].attr('href'))
      end

      # UNCLICK has expected redirect (HIDE and DOWN check above)
      get links[1].attr('href')
      assert_equal("http://example.org#{@origin}", last_response.location.encode('utf-8'))
    end
  end
end
