require File.expand_path(File.dirname(__FILE__) + '/../../test_config.rb')
require 'nokogiri'


describe '/feed/show links' do
  EXTRA = 5
  
  before do
    # Create Feed and Posts in database
    now = Time.now - PAGE_SIZE
    @feed = Feed.create(title: 'Feed 1', rss_url: 'http://127.0.0.1', previous_refresh: now, next_refresh: now)
    @posts = (PAGE_SIZE+EXTRA).times.map do |i|
      Post.create(feed_id: @feed[:id], ident: i, url: "http://127.0.0.1/#{i}", title: "Post #{i}",
                  description: "Post #{i} content.", published_at: now+i)
    end

    @origin = "/feed/#{@feed[:id]}?page=2&origin=#{CGI.escape('/feed')}"
  end

  after do
    Feed.all{|f| f.destroy}	# show destroy all Posts too
#    Post.truncate
  end


  describe 'when displaying Feeds show' do
    it 'should return Feed show, page 2' do
      get '/feed'
      p = Nokogiri::HTML.parse(last_response.body)
      link = p.at_css('tbody tr td a').attr('href')
      STDERR.puts "LINK: #{link.inspect}."

      get link	# Feed#show of first (only) listed Feed
      p = Nokogiri::HTML.parse(last_response.body)
      link = p.css('.paginate a')
      assert_equal 2, link.size
      STDERR.puts "LINK: #{link[-1].attr('href').inspect}."

      get link[-1].attr('href')	# get 2nd page of Posts

      p = Nokogiri::HTML.parse(last_response.body)
      l = p.at_css('div.card-header a.navigation')	# link for BACK_ARROW
      assert_equal('/feed', l.attr('href'))
    end
  end
end
