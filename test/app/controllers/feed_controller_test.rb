require File.expand_path(File.dirname(__FILE__) + '/../../test_config.rb')

describe "/feed" do
  before do
    get "/feed"
  end

  it "should return Feeds index" do
    assert_match(/Feeds/, last_response.body)
  end
end
