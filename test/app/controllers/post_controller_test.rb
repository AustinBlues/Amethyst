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
  end

  after do
    Feed.all{|f| f.destroy}	# should destroy all Posts too
  end


  describe 'when displaying Posts index' do
    it 'should return Post index, page 2' do
      get '/post?page=2'
      assert_match(/Posts/, last_response.body)
      assert_match(/#{@feed[:title]}/, last_response.body)

      p = Nokogiri::HTML.parse(last_response.body)

      # check Post show has expected title
      assert_equal(@posts[EXTRA-1][:title], p.at_css('td a').content.strip)
    end
  end
end
