require File.expand_path(File.dirname(__FILE__) + '/../test_config.rb')

describe "Post Model" do
  before do
    @feed = Feed.create(title: 'Dummy Feed for testing', rss_url: 'http://example.com/')
    @post = Post.create(feed_id: @feed[:id], url: 'http://example.com/post/13')
  end

  after do
    @post.delete if @post
    @feed.delete if @feed
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
