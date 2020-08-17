VERBOSITY = 1

sql = Post.where(true).full_text_search([:title, :description], 'Trump Mnuchin Kudlow China').sql
m = /\((MATCH .*\))\)\)/.match(sql)
if !m
  STDERR.puts 'OOPS: MATCH expression not found'
else
  exp = m[1]
  exp <<= ' AS score'
  query = Post.select(:id, :title, :description, Sequel.lit(exp)).where(state: Post::UNREAD).full_text_search([:title, :description],
                                                                                        'Trump Mnuchin Kudlow China')
#  puts query.sql
  hides = 0
  query.each do |p|
    if p[:score] >= 0.5
      puts("(#{p[:score]}) #{!p[:title].empty? ? p[:title] : p[:description]}") if VERBOSITY > 0
      p.update(state: Post::HIDDEN)
      hides += 1
    end
  end
  puts("HIDES: #{hides}.") if VERBOSITY >= 0
end
