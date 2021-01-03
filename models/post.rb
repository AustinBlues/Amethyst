require File.expand_path(File.dirname(__FILE__) + '/../lib/nokogiri_rss.rb')

class Post < Sequel::Model
  many_to_one :feed
  many_to_many :word


  def after_create
    Refresh.log "CREATE: #{Post.html2words(self[:description]).inspect}"
    back2 = back1 = nil
    Post.html2words(self[:description]).each do |word|
      if word !~ /^\s*$/
        w = Word.update_or_create(name: word) do |w|
          if w.new?
            w[:score] = 1.0
          else
            w[:score] += 1.0
          end
        end
        w.save_changes
        puts "W: #{w.inspect}."

        if !(o = Occurrence.where(post_id: self[:id], word_id: w[:id]).first)
          o = Occurrence.create(post_id: self[:id], word_id: w[:id], score: 1.0)
        else
          Occurrence.where(word_id: 99, post_id: 29183).update(Sequel.lit('score = score + 1.0'))
          o = Occurrence.where(post_id: self[:id], word_id: w[:id]).first	# for debugging only
        end
        puts "O: #{o.inspect}."
        
        if back1
          # update_or_create does not work for join tables
          if !(c = Context.where(prev_id: back2, next_id: w[:id]).first)
            c =  Context.create(prev_id: back2, next_id: w[:id], score: 1.0)
          else
            Context.where(word_id: 99, post_id: 29183).update(Sequel.lit('score = score + 1.0'))
#            sql = "UPDATE contexts SET score=score+1.0 WHERE (prev_id = #{back2}) AND (next_id = #{w[:id]})"
#            Sequel::Model.db.run(Sequel.lit(sql))
            c = Context.where(prev_id: back2, next_id: w[:id]).first	# for debugging only
          end
          puts "C: #{c.inspect}."
        end
        back2 = back1
        back1 = w[:id]
      end
    end
    
    if back1
      # update_or_create does not work for join tables
      if !(c = Context.where(prev_id: back2, next_id: nil).first)
        c =  Context.create(prev_id: back2, next_id: nil, score: 1.0)
      else
        sql = "UPDATE contexts SET score=score+1.0 WHERE (post_id = #{back2}) AND (word_id = #{w[:id]})"
        Sequel::Model.db.run(Sequel.lit(sql))
        c = Context.where(prev_id: back2, next_id: nil).first
      end
      puts "C: #{c.inspect}."
    end
    
    super
  end if Padrino.env == :test


#  def before_update
#    # for migration of existing Posts only
#    Refresh.log "UPDATE: #{Post.html2words(self[:description]).join(' ')}."
#    super
#  end


  ONE_DAY = 24 * 60 * 60

  # state enumeration
  UNREAD = 0
  READ = 1
  HIDDEN = 2
  DOWN_VOTED = 3

  def name
    (!title.nil? && !title.empty?) ? title : SafeBuffer.new("<b><em>Post #{id}</em></b>")
  end

  def clicked?
    self[:state] == READ
  end

  def click!
    self[:state] = READ
    feed.add_score(1.0)
    feed.clicks += 1
    feed.save(changed: true)
  end

  def unclick!
    if self[:state] == READ
      feed.add_score(-1.0)
      feed.clicks -= 1
      feed.save(changed: true)
      self[:state] = UNREAD
    end
  end

  def hidden?
    self[:state] == HIDDEN
  end


  def hide!
    if self[:state] == READ	# click?  Undo
      feed.add_score(-1.0)	# back out click
      feed.clicks -= 1
    end

    if self[:state] != HIDDEN
      self[:state] = HIDDEN
      self.feed.hides += 1
    end
    
    feed.save(changed: true)
  end


  def unhide!
    if self[:state] == HIDDEN
      feed.hides -= 1
      feed.save(changed: true)
      self[:state] = UNREAD
    end
  end

  def down_vote!
    if self[:state] == READ
      feed.add_score(-1.0)
      feed.clicks -= 1
    elsif self[:state] == HIDDEN
      feed.hides -= 1
    end
    self[:state] = DOWN_VOTED
    feed.add_score(-0.25)
    feed.down_votes += 1
    feed.save(changed: true)
  end

  def zombie?
    previous_refresh.nil? || previous_refresh < feed.previous_refresh
  end


  def self.unread
    where(state: UNREAD)
  end


  def self.html2words(text)
    tmp = HTMLEntities.new.decode(text)
#    text.gsub!(%r{\s*<(\!--.*--)|(/?([-a-zA-Z:]+(\s+[-a-zA-Z:]+=("[^"]*?"|'[^']*?'|\w+|\d+))*?\s*/?)>\s*}, ' ')
    tmp.gsub!(%r{\s*<((\!--.*?--)|(/?[-a-zA-Z0-9:]+(\s*[-a-zA-Z:]+=("[^"]*?"|'[^']*?'|\w+|\d+))*\s*/?))>\s*}m, ' ')
    if false
      # BUG: includes quote marks in words
      tmp.split(/\s+/)
    else
      # BUG: Splits contractions
      tmp.split(/[^[[:word:]]]+/)
    end
  end
  

  def self.zombie_killer
    now = Time.now
    
    zombie = where(Sequel.lit('previous_refresh <= ?', now - DAYS_OF_THE_DEAD*ONE_DAY))
    zombie_cnt = zombie.count
    unread_cnt = zombie.where(state: UNREAD).count
    puts "Deleting all #{DAYS_OF_THE_DEAD}+ day zombies: #{zombie_cnt}, #{unread_cnt} unread."
    zombie.delete

    (DAYS_OF_THE_DEAD-1).downto(1).each do |i|
      from = now - (i+1)*ONE_DAY
      to = now - i*ONE_DAY
      zombie = where(Sequel.lit('? <= previous_refresh AND previous_refresh < ?', from, to))
      unread = zombie.where(state: UNREAD)
      unread_cnt = unread.count
      unread.each do |p|
        puts "'#{p.name}' on #{p.feed.name}."
      end
      puts "#{i} day zombies: #{zombie.count}, #{unread_cnt} unread."
    end
  end
end
