require 'logger'

module Sludge
  VERBOSITY = 0

  def self.filter(feed, search, verbosity = VERBOSITY)
    raise ArgumentError if search.nil?
    sql = Post.where(true).full_text_search([:title, :description], search).sql
    m = /\((MATCH .*\))\)\)/.match(sql)
    if !m
      logger << 'OOPS: MATCH expression not found'.colorize(:red)
    else
      exp = m[1]
      exp <<= ' AS score'
      query = Post.select(:id, :title, :description, Sequel.lit(exp)).where(state: Post::UNREAD)
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
      logger << query.sql.colorize(:blue) if verbosity >= 3
      hides = 0
      query.each do |p|
        if p[:score] >= 0.5
          logger << "(#{'%0.2f' % p[:score]}) #{!p[:title].empty? ? p[:title] : p[:description]}".colorize(:red) if verbosity >= 0
          p.update(state: Post::HIDDEN)
          hides += 1
        elsif p[:score] >= 0.25
          logger << "(#{'%0.2f' % p[:score]}) #{!p[:title].empty? ? p[:title] : p[:description]}".colorize(:yellow) if verbosity > 0
        elsif true
          logger << "(#{'%0.2f' % p[:score]}) #{!p[:title].empty? ? p[:title] : p[:description]}".colorize(:magenta) if verbosity > 1
        end
      end
#     logger << "HIDES: #{hides}.".colorize(:default) if verbosity == 0
    end
  end
end
