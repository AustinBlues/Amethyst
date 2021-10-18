require File.expand_path(File.dirname(__FILE__) + '/../../test_config.rb')
require 'nokogiri'


describe '/post/search' do
  EXTRA = 5

  before do
    # Create Feed and Posts in database
    now = Time.now - PAGE_SIZE
    @feed = Feed.create(title: 'Feed 1', rss_url: 'http://127.0.0.1', previous_refresh: now, next_refresh: now)
    @posts = (PAGE_SIZE+EXTRA).times.map do |i|
      Post.create(title: "Post #{i+1}", feed_id: @feed[:id], ident: i, url: "http://127.0.0.1/#{i}",
                  description: "Post #{i+1} content.", published_at: now+i)
    end

    @origin = '/post?page=2?order=id'
  end

  after do
    Feed.all{|f| f.destroy}	# should destroy all Posts too
  end


  describe 'when displaying Posts index' do
    it 'should identify as Post index and have correct links' do
      get @origin

      assert_match(/Posts/, last_response.body)
      assert_match(/#{@feed[:title]}/, last_response.body)

      p = Nokogiri::HTML.parse(last_response.body)

#      puts last_response.body

      link = p.at_css('.card-header a.btn')
      assert_equal(link.attr('title'), 'to Feeds')
      assert_equal(link.attr('href'), '/feed')

      # check Post show for correct action links
      links = p.css('tbody:first-child a.btn')

      # UNCLICK, HIDE, and DOWN links
      links.each do |l|
        assert_match(/origin=#{CGI.escape(@origin)}/, l.attr('href'))
      end

      # check HIDE and DOWN have expected redirect
      hide = links[0].attr('href')
      assert_equal("/post/#{@posts[EXTRA-1][:id]}/hide?origin=#{CGI.escape(@origin)}", hide)
      get hide
      assert_equal("http://example.org#{@origin}", last_response.location.encode('utf-8'))

      down = links[1].attr('href')
      assert_equal("/post/#{@posts[EXTRA-1][:id]}/down?origin=#{CGI.escape(@origin)}", down)
      get down
      assert_equal("http://example.org#{@origin}", last_response.location.encode('utf-8'))
    end
    
    it 'should return all Posts in search' do
      get "/post/search?search=Post&origin=#{CGI.escape(@origin)}"
      p = Nokogiri::HTML.parse(last_response.body)
#      puts last_response.body
      assert_equal(@posts[PAGE_SIZE+EXTRA-1][:title], p.at_css('td a').content.strip)
      l = p.at_css('div.card-header a.btn')
      # KLUDGE this is how it is.  Maybe it should read 'to Feed show'
      assert_equal('to Posts', l.attr('title'))
      assert_match(@origin, l.attr('href'))	# back arrow
    end
  end
end
