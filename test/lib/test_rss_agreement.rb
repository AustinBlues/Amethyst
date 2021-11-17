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

FILES = %w{spectrum1.rss dw.rdf csps.atom}

describe 'NokogiriRSS and RubyRSS agreement' do
  before do
    Feed.all{|f| f.destroy}
  end

  after do
    Feed.all{|f| f.destroy}
  end

  it 'should match regardless of which RSS parser used' do
    FILES.each do |name|
      nokogiri_url = "#{File.expand_path(File.dirname(__FILE__))}/../../test_data/#{name}"
      nokogiri_feed = Feed.create(rss_url: nokogiri_url, title: 'NokogiriRSS')
      ruby_url = "../../test_data/#{name}"
      ruby_feed = Feed.create(rss_url: ruby_url, title: 'RubyRSS')

      File.open(nokogiri_url) do |f|
        rss = f.read
        now = Time.now
        if name =~ /\.(\w+)/
          kind = $~[1]
          kind.upcase!
        else
          STDERR.puts "Missing file extension"
          exit
        end

        Nokogiri.refresh_feed(nokogiri_feed, rss, now)
        nokogiri_feed.reload

        Ruby.refresh_feed(ruby_feed, rss, now)
        ruby_feed.reload

        max = if nokogiri_feed.post.size == ruby_feed.post.size
                nokogiri_feed.post.size - 1
              else
                STDERR.puts "Post count mismatch: #{nokogiri_feed.post.size} vs. #{ruby_feed.post.size}."
                max = [nokogiri_feed.post.size, ruby_feed.post.size].min - 1
              end
          
        0.upto(max).each do |i|
          [:title, :url, :ident].each do |tag|
            assert_equal nokogiri_feed.post[i][tag], ruby_feed.post[i][tag], "#{kind} #{tag.to_s} mismatch"
          end
          tag = :description
          assert_equal  nokogiri_feed.post[i][tag][0..79], ruby_feed.post[i][tag][0..79], "#{kind} description mismatch"
        end
      end
      nokogiri_feed.destroy
      ruby_feed.destroy
    end
  end
end
