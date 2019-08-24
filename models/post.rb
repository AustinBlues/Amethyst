class Post < Sequel::Model
  many_to_one :feed
  ONE_DAY = 24 * 60 * 60

  def name
    (!title.nil? && !title.empty?) ? title : SafeBuffer.new("<b><em>Post #{id}</em></b>")
  end


  def zombie?
    previous_refresh.nil? || previous_refresh < feed.previous_refresh
  end
  

  def self.zombie_killer
    now = Time.now
    
    # Just report, no actually deleting dropped Posts
    zombie_cnt = where(Sequel.lit('previous_refresh <= ?', now - 10*ONE_DAY)).count
    unread_cnt = where(click: 0, hide: 0).where(Sequel.lit('previous_refresh <= ?', now - 10*ONE_DAY)).count
    puts "10+ day zombies: #{zombie_cnt}, #{unread_cnt} unread."

    9.downto(1).each do |i|
      from = now - (i+1)*ONE_DAY
      to = now - i*ONE_DAY
      zombie_cnt = where(Sequel.lit('? <= previous_refresh AND previous_refresh < ?', from, to)).count
      unread_cnt = where(click: 0, hide: 0).where(Sequel.lit('? < previous_refresh AND previous_refresh <= ?', from, to)).count
      if 0 < unread_cnt && unread_cnt <= 10
        where(click: 0, hide: 0).where(Sequel.lit('? < previous_refresh AND previous_refresh <= ?', from, to)).all.each do |p|
          puts "'#{p.name}' on #{p.feed.name}."
        end
      end
      puts "#{i} day zombies: #{zombie_cnt}, #{unread_cnt} unread."
    end
  end
end
