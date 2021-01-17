require File.expand_path(File.dirname(__FILE__) + '/../lib/nokogiri_rss.rb')

class Post < Sequel::Model
  many_to_one :feed
  many_to_many :word, join_table: :occurrences


  def after_create
    create_word_cloud
    super
  end


  def after_update
    # for migration of existing Posts only
    create_word_cloud if word.empty?
    super
  end


  ONE_DAY = 24 * 60 * 60

  # state enumeration
  UNREAD = 0
  READ = 1
  HIDDEN = 2
  DOWN_VOTED = 3


  def create_word_cloud
    words = Post.html2words(self[:description])
    if Padrino.env != :test
#      Refresh.log("CREATE: #{words.inspect}")
    else
#      puts "CREATE: #{words.inspect}"
    end
    
    back2 = back1 = nil
    words.each do |word|
      if word !~ /^\s*$/
        w = Word.update_or_create(name: word) do |w|
          if w.new?
            w[:frequency] = 1.0
          else
            w[:frequency] += 1.0
          end
        end
        w.save_changes
 #       puts "W: #{w.inspect}." if Padrino.env == :test

        if !(o = Occurrence.where(post_id: self[:id], word_id: w[:id]).first)
          o = Occurrence.create(post_id: self[:id], word_id: w[:id], count: 1)
        else
          Occurrence.where(post_id: self[:id], word_id: w[:id]).update(Sequel.lit('count = count + 1'))
          o = Occurrence.where(post_id: self[:id], word_id: w[:id]).first	# for debugging printouts only
        end
 #       puts "O: #{o.inspect}." if Padrino.env == :test

        if back1
          # update_or_create does not work for join tables
          if !(c = Context.where(prev_id: back2, next_id: w[:id]).first)
            c =  Context.create(prev_id: back2, next_id: w[:id], count: 1)
          else
            Context.where(prev_id: back2, next_id: w[:id]).update(Sequel.lit('count = count + 1'))
            c = Context.where(prev_id: back2, next_id: w[:id]).first	# for debugging only
          end
 #         puts "C: #{c.inspect}." if Padrino.env == :test
        end
        back2 = back1
        back1 = w[:id]
      end
    end
    
    if back1
      # update_or_create does not work for join tables
      if !(c = Context.where(prev_id: back2, next_id: nil).first)
        c =  Context.create(prev_id: back2, next_id: nil, count: 1)
      else
        Context.where(prev_id: back2, next_id: nil).update(Sequel.lit('count = count + 1'))
        c = Context.where(prev_id: back2, next_id: nil).first	# for debugging printouts only
      end
 #     puts "C: #{c.inspect}." if Padrino.env == :test
    end
  end

  
  def word_cloud(limit = 1.0)
    Word.join(:occurrences, post_id: self[:id], word_id: :id).where(flags: 0).where{frequency > limit}.all
  end

  
  def name
    (!self[:title].nil? && !self[:title].empty?) ? self[:title] : SafeBuffer.new("<b><em>Post #{id}</em></b>")
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


  def description
    tmp = HTMLEntities.new.decode(self[:description])
    tmp.gsub(%r{\s*<((\!--.*?--)|(/?[-a-zA-Z0-9:]+(\s*[-a-zA-Z:]+=("[^"]*?"|'[^']*?'|\w+|\d+))*\s*/?))>\s*}m, ' ')
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


  def before_destroy
    remove_all_word
    super
  end

  def self.zombie_killer
    now = Time.now
    
    zombie = where(Sequel.lit('previous_refresh <= ?', now - DAYS_OF_THE_DEAD*ONE_DAY))
    zombie_cnt = zombie.count
    unread_cnt = zombie.where(state: UNREAD).count
    puts "Deleting all #{DAYS_OF_THE_DEAD}+ day zombies: #{zombie_cnt}, #{unread_cnt} unread."
    zombie.all {|z| z.destroy}

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
