require File.expand_path(File.dirname(__FILE__) + '/../../test_config.rb')

describe "/feed" do
  before do
    Occurrence.where(true).delete
    Word.all{|w| w.delete}
    Post.all{|p| p.delete}
    Feed.all{|f| f.delete}

    get "/feed"
  end

  after do
    Occurrence.where(true).delete
    Word.all{|w| w.delete}
    Post.all{|p| p.delete}
    Feed.all{|f| f.delete}
  end
    
  it "should return Feeds index" do
    assert_match(/Feeds/, last_response.body)
  end
end
