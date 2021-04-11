require File.expand_path(File.dirname(__FILE__) + '/../test_config.rb')

describe "Post Model" do
  before do
    @feed = Feed.create(title: 'Dummy Feed for testing', rss_url: 'http://example.com/')
    @post = Post.create(title: 'Dummy Post for testing', feed_id: @feed.id, url: 'http://example.com/post/13') 
  end

  after do
    @post.delete if @post
    @feed.delete if @feed
  end


  it 'change_to() duplicates actions of click!, hide!, etc' do
    for pre_state in Post::UNREAD..Post::DOWN_VOTED do
      for post_state in Post::UNREAD..Post::DOWN_VOTED do
        @feed.clicks = @feed.hides = 0
        @feed.save(changes: true)
        @post[:state] = pre_state
        old_way = @post.dup
        new_way = @post.dup
#        puts "FEED: #{Feed[@feed[:id]].inspect}."
#        puts "POST: #{@post.inspect}."
        case post_state
        when Post::UNREAD
          old_way.unclick!
        when Post::READ
          old_way.click!
        when Post::HIDDEN
          old_way.hide!
        when Post::DOWN_VOTED
          old_way.down_vote!
        end
#        puts "FEED: #{Feed[@feed[:id]].inspect}."
        new_way.state_to(post_state)
#        puts "FEED: #{Feed[@feed[:id]].inspect}."
#        puts "OLD: #{old_way.inspect}."
#        puts "NEW: #{new_way.inspect}."
        assert_equal old_way, new_way, "TEST: #{Post::STATES[pre_state]} => #{Post::STATES[post_state]}"
      end
    end
  end

  it 'can click! a Post and clicked? is true' do
    @post.click!
    assert @post.clicked?, 'Post is not clicked? after click!'
  end

  it 'can hide! a Post and hidden? is true' do
    @post.hide!
    assert @post.hidden?, 'Post is not hidden? after hide!'
  end

  it 'can unclick! a click! Post and is neither clicked? nor hidden?' do
    @post.click!
    @post.unclick!
    assert !@post.clicked? && !@post.hidden?, 'Post is clicked? or hidden?'
  end

  it 'can unhide! a hide! Post and it is neither clicked? nor hidden?' do
    @post.hide!
    @post.unhide!
    assert !@post.clicked? && !@post.hidden?, 'Post is clicked? or hidden?'
  end
end
