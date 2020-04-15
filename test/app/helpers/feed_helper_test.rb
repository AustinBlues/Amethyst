require File.expand_path(File.dirname(__FILE__) + '/../../test_config.rb')

describe "Amethyst::App::FeedHelper" do
  before do
    @helpers = Class.new
    @helpers.extend Amethyst::App::FeedHelper
  end

  def helpers
    @helpers
  end

#  it "should return nil" do
#    assert_nil helpers.foo
#  end
end
