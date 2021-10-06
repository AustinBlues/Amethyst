require File.expand_path(File.dirname(__FILE__) + '/../../test_config.rb')
require 'nokogiri'

describe "/post" do
  EXTRA = 5

  before do
    # Create Feed and Posts in database
    now = Time.now - PAGE_SIZE
    @feed = Feed.create(title: 'Feed 1', rss_url: 'http://127.0.0.1', previous_refresh: now, next_refresh: now)
    @posts = (PAGE_SIZE+EXTRA).times.map do |i|
      Post.create(title: "Post #{i+1}", feed_id: @feed[:id], ident: i, url: "http://127.0.0.1/#{i}",
                  description: "Post #{i+1} content.", published_at: now+i)
    end
    @origin = '/post?page=2'
  end

  after do
    Feed.all{|f| f.destroy}	# should destroy all Posts too
  end


  describe 'when displaying Posts index' do
    it 'should identify as Post index with correct first Post and links' do
      get @origin

      assert_match(/Posts/, last_response.body)
      assert_match(/#{@feed[:title]}/, last_response.body)

      p = Nokogiri::HTML.parse(last_response.body)
      
      link = p.at_css('.card-header a.btn')
      assert_equal(link.attr('title'), 'to Feeds')
      assert_equal(link.attr('href'), '/feed')

      # check first Post has expected title
      assert_equal(@posts[EXTRA-1][:title], p.at_css('td:first-child a').content.strip)

      # check first Post has correct action links
      links = p.css('tbody:first-child a.btn')

      # HIDE, and DOWN links
      assert_equal("/post/#{@posts[EXTRA-1][:id]}/hide?page=2", links[0].attr('href'))
      assert_equal("/post/#{@posts[EXTRA-1][:id]}/down?page=2", links[1].attr('href'))
    end
  end

  describe 'when displaying Post show' do
    if false
      # check HIDE and DOWN have expected redirect
      hide = links[2].attr('href')
      assert_equal("/post/#{@posts[0][:id]}/hide?origin=#{CGI.escape(@origin)}", hide)
      get hide
      puts "RESPONSE: #{last_response.body}"
      assert_equal("http://example.org#{@origin}", last_response.location.encode('utf-8'))

      down = links[3].attr('href')
      assert_equal("/post/#{@posts[0][:id]}/down?origin=#{CGI.escape(@origin)}", down)
      get down
      assert_equal("http://example.org#{@origin}", last_response.location.encode('utf-8'))
    end
  end
end
