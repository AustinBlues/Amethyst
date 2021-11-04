require File.expand_path(File.dirname(__FILE__) + '/../test_config.rb')
#require File.expand_path(File.dirname(__FILE__) + '/../../lib/nokogiri_rss.rb')

module Nokogiri
  extend Padrino::Helpers::FormatHelpers
  extend NokogiriRSS
end

module Ruby
  extend Padrino::Helpers::FormatHelpers
  extend RubyRSS
end


describe 'NokogiriRSS and RubyRSS agreement' do
  before do
    @nokogiri_url = "#{File.expand_path(File.dirname(__FILE__))}/../../test_data/spectrum1.rss"
    @nokogiri_feed = Feed.create(rss_url: @nokogiri_url, title: 'NokogiriRSS')
    ruby_url = "../../test_data/spectrum1.xml"
    @ruby_feed = Feed.create(rss_url: ruby_url, title: 'RubyRSS')
  end

  after do
    @nokogiri_feed.destroy if @nokogiri_feed
    @ruby_feed.destroy if @ruby_feed
  end

  it 'should match regardless of which RSS parser used' do
    File.open(@nokogiri_url) do |f|
      rss = f.read
      now = Time.now

      Nokogiri.refresh_feed(@nokogiri_feed, rss, now)
      @nokogiri_feed.reload

      Ruby.refresh_feed(@ruby_feed, rss, now)
      @ruby_feed.reload

      @nokogiri_feed.post.each_with_index do |post, i|
        [:ident, :title, :description, :url].each do |tag|
          assert_equal post[tag], @ruby_feed.post[i][tag]
        end
      end
    end
  end
end
