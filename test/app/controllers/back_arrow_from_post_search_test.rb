require File.expand_path(File.dirname(__FILE__) + '/../../test_config.rb')
require 'nokogiri'

describe "/feed" do
  EXTRA = 5

  before do
    Occurrence.where(true).delete
    Word.all{|w| w.delete}
    Post.all{|p| p.delete}
    Feed.all{|f| f.delete}

    # Create Feed and Posts in database
    now = Time.now - PAGE_SIZE
    @feed = Feed.create(title: 'Feed 1', rss_url: 'http://127.0.0.1', previous_refresh: now, next_refresh: now)
    @posts = (PAGE_SIZE+EXTRA).times.map do |i|
      Post.create(feed_id: @feed[:id], ident: i, url: "http://127.0.0.1/#{i}", title: "Post #{i+1}",
                  description: "Post #{i+1} content.", published_at: now+i)
    end

    @origin = "/post?page=2&order=id"
  end

  after do
    Feed.all{|f| f.destroy}	# should destroy all Posts too
  end


  describe 'when showing Posts' do
    it "should return Post index, 2nd page" do
      get @origin
      assert_match(/Posts/, last_response.body)
      assert_match(/#{@posts[0][:title]}/, last_response.body)
    end

    it 'should return oldest Post and all back links point to origin' do
      get "/post/search?page=2&search=Post&origin=#{CGI.escape(@origin)}"
      p = Nokogiri::HTML.parse(last_response.body)
#      puts last_response.body
      assert_equal(@posts[EXTRA-1][:title], p.at_css('td a').content.strip)
      l = p.at_css('div.card-header a.navigation')
      assert_equal('to Posts', l.attr('title'))
      assert_match(@origin, l.attr('href'))
    end
  end
end
