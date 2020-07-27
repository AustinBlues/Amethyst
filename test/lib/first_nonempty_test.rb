require File.expand_path(File.dirname(__FILE__) + '/../test_config.rb')
require 'ruby_rss'

describe '/lib' do
  include RubyRSS
  
  it 'first_nonblank should return nil for nil or blank args' do
    [nil, '', ' '].each do |arg|
      assert_nil first_nonblank(arg)
    end
  end

  it 'first_nonblank should return arg for blank arg' do
    arg = Time.now.to_s
    assert_equal arg, first_nonblank(arg)
  end

  it 'first_nonblank should return nil for nil or blank second args' do
    [nil, '', ' '].each do |arg|
      assert_nil first_nonblank(nil, arg)
    end
  end

  it 'first_nonblank should return arg for blank second arg' do
    arg = Time.now.to_s
    assert_equal arg, first_nonblank(nil, arg)
  end
end
