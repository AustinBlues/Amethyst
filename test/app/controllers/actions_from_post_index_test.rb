require File.expand_path(File.dirname(__FILE__) + '/../../test_config.rb')
require 'nokogiri'

describe "/post" do
  before do
    Occurrence.where(true).delete
    Word.all{|w| w.delete}
    Post.all{|p| p.delete}
    Feed.all{|f| f.delete}

    # Create Feed and Posts in database
    now = Time.now - PAGE_SIZE
    @feed = Feed.create(title: 'Feed 1', rss_url: 'http://127.0.0.1', previous_refresh: now, next_refresh: now)
    @posts = (PAGE_SIZE+5).times.map do |i|
      Post.create(feed_id: @feed[:id], ident: i, url: "http://127.0.0.1/#{i}", title: "Post #{i+1}",
                  description: "Post #{i+1} content.", published_at: now+i)
    end
    @origin = "/post?page=2"
  end

  after do
    Feed.all{|f| f.destroy}
#    Post.truncate
  end

  describe 'when showing Posts' do
    it 'should return earliest unread Post and all back links point to origin' do
      get @origin
#      puts last_response.body
      p = Nokogiri::HTML.parse(last_response.body)
      header = p.at_css('div.card-header a.navigation')
#      puts "HEADER: #{header.inspect}."
      assert_equal('to Feeds', header.attr('title'))
      assert_equal('/feed', header.attr('href'))

      # hide, down links
      actions = p.css('a.action')
      hide = actions[0].attr('href')
      assert_equal("/post/#{@posts[-(PAGE_SIZE+1)][:id]}/hide?origin=#{CGI.escape(@origin)}", hide)
      down = actions[1].attr('href')
      assert_equal("/post/#{@posts[-(PAGE_SIZE+1)][:id]}/down?origin=#{CGI.escape(@origin)}", down)

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
      
      link = p.at_css('.card .card-header a.navigation')
      # back arrow (LEFT_ARROW)
      assert_equal('to Posts', link.attr('title'))
      assert_match(@origin, link.attr('href'))

      # UNCLICK, HIDE, and DOWN links
      links = p.css('.card .card-header .actions a.action')
      links.each do |l|
        assert_match(/origin=#{CGI.escape(@origin)}/, l.attr('href'))
      end

      # UNCLICK has expected redirect (HIDE and DOWN check above)
      get links[0].attr('href')
      assert_equal("http://example.org#{@origin}", last_response.location.encode('utf-8'))
    end
  end
end
