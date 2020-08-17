require 'logger'

module Sludge
  VERBOSITY = 2
  DEFAULT = 'sludge filter'

  
  def self.filter(feed, search = nil)
    sql = Post.where(true).full_text_search([:title, :description], search || DEFAULT).sql
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
      end
      query = query.full_text_search([:title, :description], search || DEFAULT)
      logger << query.sql.colorize(:blue) if VERBOSITY >= 2
      hides = 0
      query.each do |p|
        if p[:score] >= 0.5
          logger << "(#{'%0.2f' % p[:score]}) #{!p[:title].empty? ? p[:title] : p[:description]}".colorize(:red) if VERBOSITY > 0
#          p.update(state: Post::HIDDEN)
          hides += 1
        elsif p[:score] >= 0.25
          logger << "(#{'%0.2f' % p[:score]}) #{!p[:title].empty? ? p[:title] : p[:description]}".colorize(:yellow) if VERBOSITY > 0
        end
      end
     logger << "HIDES: #{hides}.".colorize(:default) if VERBOSITY >= 0
    end
  end
end
