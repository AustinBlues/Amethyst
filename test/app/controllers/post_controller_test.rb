require File.expand_path(File.dirname(__FILE__) + '/../../test_config.rb')
require 'nokogiri'

describe "/post" do
  EXTRA = 5

  before do
    # Create Feed and Posts in database
    now = Time.now - PAGE_SIZE
    @feed = Feed.create(title: 'Feed 1', rss_url: 'http://127.0.0.1', previous_refresh: now, next_refresh: now)
    @posts = (PAGE_SIZE+EXTRA).times.map do |i|
      Post.create(feed_id: @feed[:id], ident: i, url: "http://127.0.0.1/#{i}", title: "Post #{i+1}",
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
      assert_equal("/post/#{@posts[EXTRA-1][:id]}/hide?origin=#{CGI.escape('/post?page=2')}", links[0].attr('href'))
      assert_equal("/post/#{@posts[EXTRA-1][:id]}/down?origin=#{CGI.escape('/post?page=2')}", links[1].attr('href'))
    end
  end

  describe 'when displaying Post show' do
    it 'should identify as Post show with correct header and Post title and links' do
      origin = 'origin=%2Fpost%3Fpage%3D1'
      get "/post/#{@posts[0][:id]}?#{origin}"

      p = Nokogiri::HTML.parse(last_response.body)

      title = p.at_css('h2.card-title a')
      assert_equal(title.content, @posts[0][:title])
      assert_equal(title.attr('href'), @posts[0][:url])

      # check Post has expected title and URL
      link = p.at_css('.card-header a.btn')
      assert_equal(link.attr('title'), 'to Posts')
      assert_equal(link.attr('href'), '/post?page=1')

      # check first Post has correct action links
      links = p.css('.card-header div a.btn')

      # UNCLICK, HIDE, and DOWN links
      ACTIONS = %w{unclick hide down}
      links.each_with_index do |l, i|
        assert_equal("/post/#{@posts[0][:id]}/#{ACTIONS[i]}?#{origin}", links[i].attr('href'))
      end
    end
  end

  describe 'TBD' do
    if false
      # check HIDE and DOWN have expected redirect
      hide = links[2].attr('href')
      assert_equal("/post/#{@posts[0][:id]}/hide?origin=#{CGI.escape(@origin)}", hide)
      get hide
      assert_equal("http://example.org#{@origin}", last_response.location.encode('utf-8'))

      down = links[3].attr('href')
      assert_equal("/post/#{@posts[0][:id]}/down?origin=#{CGI.escape(@origin)}", down)
      get down
      assert_equal("http://example.org#{@origin}", last_response.location.encode('utf-8'))
    end
  end
end
