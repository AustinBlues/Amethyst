require File.expand_path(File.dirname(__FILE__) + '/../../test_config.rb')
require 'nokogiri'


describe '/post/search' do
  before do
    Occurrence.where(true).delete
    Word.all{|w| w.delete}
    Post.all{|p| p.delete}
    Feed.all{|f| f.delete}

    # Create Feed and Posts in database
    now = Time.now - PAGE_SIZE
    @feed = Feed.create(title: 'Feed 1', rss_url: 'http://127.0.0.1', previous_refresh: now)
    @posts = (PAGE_SIZE+5).times.map do |i|
      Post.create(title: "Post #{i+1}", feed_id: @feed[:id], ident: i, url: "http://127.0.0.1/#{i}",
                  description: "Post #{i+1} content.", published_at: now+i)
    end

    @origin = "/post?page=2"
  end

  after do
    Occurrence.where(true).delete
    Word.all{|w| w.delete}
    Post.all{|p| p.delete}
    Feed.all{|f| f.delete}
  end


  describe 'when displaying Posts index' do
    it 'should return Post index, page 2' do
      get @origin
      assert_match(/Posts/, last_response.body)
      assert_match(/#{@feed[:title]}/, last_response.body)
    end

    it 'should return all Posts in search' do
      get "/post/search?search=Post&origin=#{CGI.escape(@origin)}"
      p = Nokogiri::HTML.parse(last_response.body)
#      puts last_response.body
      assert_equal(@posts[0][:title], p.at_css('td a').content.strip)
      l = p.at_css('div.card-header a.btn')
      # KLUDGE this is how it is.  Maybe it show read 'to Feed show'
      assert_equal('to Posts', l.attr('title'))
      assert_match(@origin, l.attr('href'))

      # check Post show for correct action links
      get "/post/#{@posts[0][:id]}?origin=#{CGI.escape(@origin)}"
      p = Nokogiri::HTML.parse(last_response.body)
      
      # check Post show has expected description
      assert_equal(@posts[0][:description], p.at_css('p').content.strip)
      
      links = p.css('a.btn')
      # back arrow (LEFT_ARROW)
      assert_equal('to Posts', links[0].attr('title'))
      assert_match(@origin, links[0].attr('href'))

      # UNCLICK, HIDE, and DOWN links
      (1..3).each do |i|
        assert_match(/origin=#{CGI.escape(@origin)}/, links[i].attr('href'))
      end

      # HIDE, DOWN links on SHOW page
      if true
        hide = links[2].attr('href')
        assert_equal("/post/#{@posts[0][:id]}/hide?origin=#{CGI.escape(@origin)}", hide)
        down = links[3].attr('href')
        assert_equal("/post/#{@posts[0][:id]}/down?origin=#{CGI.escape(@origin)}", down)
      else
        actions = p.css('a.action')
        hide = actions[1].attr('href')
        assert_equal("/post/#{@posts[0][:id]}/hide?origin=#{CGI.escape(@origin)}", hide)
        down = actions[2].attr('href')
        assert_equal("/post/#{@posts[0][:id]}/down?origin=#{CGI.escape(@origin)}", down)
      end
      # UNCLICK has expected redirect (HIDE and DOWN check below)
      get links[1].attr('href')
      assert_equal("http://example.org#{@origin}", last_response.location.encode('utf-8'))

      # check HIDE and DOWN have expected redirect
      get hide
      assert_equal("http://example.org#{@origin}", last_response.location.encode('utf-8'))
      get down
      assert_equal("http://example.org#{@origin}", last_response.location.encode('utf-8'))
    end
  end
end
