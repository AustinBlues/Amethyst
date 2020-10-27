require File.expand_path(File.dirname(__FILE__) + '/../app/helpers/amethyst_helper.rb')

module Sludge
  extend Amethyst::App::AmethystHelper

  VERBOSITY = 2
  SLUDGE_HORIZON = 2*3600	# 2 hours

  def self.filter(feed, search, verbosity = VERBOSITY)
    raise ArgumentError if search.nil?

    sql = Post.where(true).full_text_search([:title, :description], search).sql
    m = /\((MATCH .*\))\)\)/.match(sql)
    if !m
      log('OOPS: MATCH expression not found'.colorize(:red))
    else
      exp = m[1]
      exp <<= ' AS score'
      query = Post.select(:id, :title, :description, Sequel.lit(exp)).where(state: Post::UNREAD).
                where{published_at >= Time.now - (SLUDGE_HORIZON+Refresh::INTERVAL_TIME)}
      case feed
      when Feed
        query = query.where(feed_id: feed.id)
      when Integer
        query = query.where(feed_id: feed)
      when Array
        query = query.where(feed_id: feed)
      end
      boolean = search =~ /[-+<>(~*"]+/
      query = query.full_text_search([:title, :description], search, boolean: boolean)
      log(query.sql.colorize(:blue)) if verbosity >= 3
      query.each do |q|
        if q[:score] >= 0.5
          log("(#{'%0.2f' % q[:score]}) #{!q[:title].empty? ? q[:title] : q[:description]}".colorize(:red)) if verbosity >= 0
          if false
            q.update(state: Post::HIDDEN)
          else
            post = Post[q[:id]]
            post.down_vote!
            post.save(changed: true)
          end
        elsif q[:score] >= 0.25
          log("(#{'%0.2f' % q[:score]}) #{!q[:title].empty? ? q[:title] : q[:description]}".colorize(:yellow)) if verbosity >= 1
        elsif true
          log("(#{'%0.2f' % q[:score]}) #{!q[:title].empty? ? q[:title] : q[:description]}".colorize(:magenta)) if verbosity >= 2
        end
      end
    end
  end
end
