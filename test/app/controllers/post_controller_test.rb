require File.expand_path(File.dirname(__FILE__) + '/../../test_config.rb')
require 'ruby_rss'


describe "/post" do
  include RubyRSS
  
#  before do
#    get "/post"
#  end

  it "should return Posts index" do
    get "/post"
    assert_match(/Posts/, last_response.body)
  end
end
