class Post < Sequel::Model
  many_to_one :feed
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
#    self[:click]
    self[:state] == READ
  end

  def click!
    self[:click] = true
    self[:state] = READ
    feed.add_score(1.0)
    feed.clicks += 1
    feed.save(changed: true)
  end

  def unclick!
    if self[:state] == READ
      self[:click] = false
      self[:state] = UNREAD
      feed.add_score(-1.0)
      feed.clicks -= 1
      feed.save(changed: true)
    end
  end
  

  def hidden?
#    self[:hide]
    self[:state] == HIDDEN
  end

  def hide!
#    if self[:click]	# click?  Undo
    if self[:state] == READ	# click?  Undo
      self[:click] = false
      feed.add_score(-1.0)	# back out click
      feed.clicks -= 1
    end

#    if !self[:hide]
    if self[:state] != HIDDEN
      self[:hide] = true
      self[:state] = HIDDEN
      self.feed.hides += 1
    end
    
    feed.save(changed: true)
  end

  def unhide!
    if self[:state] == HIDDEN	# self[:hide]
      self[:hide] = false
      self[:state] = UNREAD
      feed.hides -= 1
      feed.save(changed: true)
    end
  end

  def down_vote!
    if self[:state] == READ	# self[:click]
      self[:click] = false
      feed.add_score(-1.0)
      feed.clicks -= 1
    elsif self[:state] == HIDDEN	# self[:hide]
      self[:hide] = false
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
  

  def self.zombie_killer
    now = Time.now
    
    zombie = where(Sequel.lit('previous_refresh <= ?', now - 10*ONE_DAY))
    zombie_cnt = zombie.count
    unread_cnt = zombie.unread.count
    puts "Deleting all 10+ day zombies: #{zombie_cnt}, #{unread_cnt} unread."
    zombie.delete

    9.downto(1).each do |i|
      from = now - (i+1)*ONE_DAY
      to = now - i*ONE_DAY
      zombie = where(Sequel.lit('? <= previous_refresh AND previous_refresh < ?', from, to))
      unread = zombie.where(state: UNREAD)
      unread_cnt = unread.count
#      if unread_cnt > 0
        unread.each do |p|
          puts "'#{p.name}' on #{p.feed.name}."
        end
#      end
      puts "#{i} day zombies: #{zombie.count}, #{unread_cnt} unread."
    end
  end
end
