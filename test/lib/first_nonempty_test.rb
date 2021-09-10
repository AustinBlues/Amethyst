require File.expand_path(File.dirname(__FILE__) + '/../test_config.rb')
require 'ruby_rss'

module RubyRssTest
  extend RubyRSS
end


describe '/lib' do
#  include RubyRSS
  
  it 'first_nonblank should return nil for nil or blank args' do
    [nil, '', ' '].each do |arg|
      assert_nil RubyRssTest.first_nonblank(arg)
    end
  end

  it 'first_nonblank should return arg for blank arg' do
    arg = Time.now.to_s
    assert_equal arg, RubyRssTest.first_nonblank(arg)
  end

  it 'first_nonblank should return nil for nil or blank second args' do
    [nil, '', ' '].each do |arg|
      assert_nil RubyRssTest.first_nonblank(nil, arg)
    end
  end

  it 'first_nonblank should return arg for blank second arg' do
    arg = Time.now.to_s
    assert_equal arg, RubyRssTest.first_nonblank(nil, arg)
  end
end
