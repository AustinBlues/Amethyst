require File.expand_path(File.dirname(__FILE__) + '/../test_config.rb')

describe "Word Model" do
  before do
    Occurrence.truncate
    Context.truncate
    Word.all{|w| w.delete}
    Post.all{|p| p.delete}
    Feed.all{|f| f.delete}
  end

  after do
#    Occurrence.truncate
#    Context.truncate
#    Word.all{|w| w.delete}
#    Post.all{|p| p.delete}
#    Feed.all{|f| f.delete}
  end
  
  it 'can create a simplest word cloud' do
    puts 'Simplest Word cloud.'
    f = Feed.create(title: 'Dummy Feed')
    p = Post.create(feed_id: f[:id], title: 'Dummy Post', url: 'http://example.com', description: 'The quick brown fox.')
  end

  it 'can create a simple word cloud' do
    puts 'Simple Word cloud.'
    f = Feed.create(title: 'Dummy Feed')
    p = Post.create(feed_id: f[:id], title: 'Dummy Post', url: 'http://example.com',
                    description: 'The quick brown fox tripped and tripped.')
  end
end
