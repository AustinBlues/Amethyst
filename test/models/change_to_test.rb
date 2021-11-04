require File.expand_path(File.dirname(__FILE__) + '/../test_config.rb')

describe "change_to instance method" do
  after do
    Feed.all{|f| f.destroy}
  end

  TRANSITIONS = [Post::UNREAD, Post::UNREAD, Post::READ, Post::UNREAD, Post::HIDDEN, Post::UNREAD, Post::DOWN_VOTED,
                 Post::READ, Post::READ, Post::HIDDEN, Post::READ, Post::DOWN_VOTED, Post::HIDDEN, Post::HIDDEN,
                 Post::DOWN_VOTED, Post::DOWN_VOTED, Post::UNREAD]

  it 'change_to() duplicates actions of click!, hide!, etc' do
    feed_old_way = Feed.create(title: 'Feed old way', clicks: 0, hides: 0, down_votes: 0, rss_url: 'http://127.0.0.1/old')
    feed_new_way = Feed.create(title: 'Feed new way', clicks: 0, hides: 0, down_votes: 0, rss_url: 'http://127.0.0.1/new')
    post_old_way = Post.create(feed_id: feed_old_way.id, title: 'Post old way', url: 'http://127.0.0.1/post/old')
    post_new_way = Post.create(feed_id: feed_old_way.id, title: 'Post new way', url: 'http://127.0.0.1/post/new')
    for i in 0..15 do
      pre_state = TRANSITIONS[i]
      post_old_way[:state] = post_new_way[:state] = pre_state
      post_state = TRANSITIONS[i+1]
      case post_state
      when Post::UNREAD
        post_old_way.unclick!
      when Post::READ
        post_old_way.click!
      when Post::HIDDEN
        post_old_way.hide!
      when Post::DOWN_VOTED
        post_old_way.down_vote!
      end
      post_new_way.state_to(post_state)
#      puts "FEED OLD: #{Feed[feed_old_way[:id]].inspect}."
 #     puts "FEED NEW: #{Feed[feed_new_way[:id]].inspect}."
      assert_equal feed_old_way[:score], feed_new_way[:score], "SCORE: #{Post::STATES[pre_state]} => #{Post::STATES[post_state]}"
      assert_equal feed_old_way[:clicks], feed_new_way[:clicks], "CLICKS: #{Post::STATES[pre_state]} => #{Post::STATES[post_state]}"
      assert_equal feed_old_way[:hides], feed_new_way[:hides], "HIDES: #{Post::STATES[pre_state]} => #{Post::STATES[post_state]}"
      assert_equal feed_old_way[:down_votes], feed_new_way[:down_votes], "DOWN: #{Post::STATES[pre_state]} => #{Post::STATES[post_state]}"
#      puts "OLD: #{post_old_way.inspect}."
#      puts "NEW: #{post_new_way.inspect}."
      assert_equal post_old_way[:state], post_new_way[:state], "POST: #{Post::STATES[pre_state]} => #{Post::STATES[post_state]}"
    end
  end
end
