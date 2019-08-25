require File.expand_path(File.dirname(__FILE__) + '/../../test_config.rb')

describe "/post" do
  before do
    get "/post"
  end

  it "should return Posts index" do
    assert_match(/Posts/, last_response.body)
  end
end
