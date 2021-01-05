require File.expand_path(File.dirname(__FILE__) + '/../../test_config.rb')

describe "/post" do
  before do
    Occurrence.truncate
    Context.truncate
    Word.all{|w| w.delete}
    Post.all{|p| p.delete}
    Feed.all{|f| f.delete}

    get "/post"
  end

  after do
    Occurrence.truncate
    Context.truncate
    Word.all{|w| w.delete}
    Post.all{|p| p.delete}
    Feed.all{|f| f.delete}
  end
    
  it "should return Posts index" do
    assert_match(/Posts/, last_response.body)
  end
end
