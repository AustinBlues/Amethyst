require 'htmlentities'


class Post < Sequel::Model
  many_to_one :feed
  ONE_DAY = 24 * 60 * 60

  # state enumeration
  STATES = %w{UNREAD READ HIDDEN DOWN_VOTED}
  UNREAD = 0
  READ = 1
  HIDDEN = 2
  DOWN_VOTED = 3

  SCORE = {READ => 1.0, DOWN_VOTED => -1.0}
  SCORE.default = 0

  @@entities_decoder = HTMLEntities.new	# DB handles UTF-8/Unicode


  def before_create
    self[:title] = @@entities_decoder.decode(self[:title]) unless self[:title].nil?	# preserve nil
    self[:description] = @@entities_decoder.decode(self[:description]) unless self[:description].nil?	# preserve nil
    super
  end

  
  def name
    (self[:title] && !self[:title].empty?) ? self[:title] : SafeBuffer.new("<b><em>Post #{id}</em></b>")
  end


  def clicked?
    self[:state] == READ
  end


  def click!
    state_to(READ)
  end


  def unclick!
    state_to(UNREAD)
  end
  

  def hidden?
    self[:state] == HIDDEN
  end


  def hide!
    state_to(HIDDEN)
  end


  def unhide!
    state_to(UNREAD)
  end


  def down_vote!
    state_to(DOWN_VOTED)
  end

  
  def state_to(new_state)
    if self[:state] != new_state
      # back out old state scoring
      feed.add_score(-SCORE[self[:state]])
      case self[:state]
      when READ
        feed.clicks -= 1
      when HIDDEN
        feed.hides -= 1
      when DOWN_VOTED
        feed.down_votes -= 1
      end

      case new_state
      when READ
        feed.clicks += 1
      when HIDDEN
        feed.hides += 1
      when DOWN_VOTED
        feed.down_votes += 1
      end
      feed.add_score(+SCORE[new_state])
      feed.save(changed: true)
      self[:state] = new_state
    end
  end

  
  
  def zombie?
    self[:previous_refresh] && feed[:previous_refresh] && (self[:previous_refresh] < feed[:previous_refresh])
  end

  
  def self.unread
    where(state: UNREAD)
  end


  def self.zombie_listing
    now = Time.now
    
#    zombie = where(Sequel.lit('previous_refresh <= ?', now - DAYS_OF_THE_DEAD*ONE_DAY))
#    zombie_cnt = zombie.count
#    unread_cnt = zombie.where(state: UNREAD).count

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


  def self.zombie_killer
    zombie = where(Sequel.lit('previous_refresh <= ?', Time.now - DAYS_OF_THE_DEAD*ONE_DAY))
    zombie_cnt = zombie.count
    unread_cnt = zombie.where(state: UNREAD).count
    puts "Deleting all #{DAYS_OF_THE_DEAD}+ day zombies: #{zombie_cnt}, #{unread_cnt} unread."
    zombie.delete
  end
end
