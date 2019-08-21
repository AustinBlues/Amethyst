class Post < Sequel::Model
  many_to_one :feed
  ONE_DAY = 24 * 60 * 60

  def name
    (!title.nil? && !title.empty?) ? title : SafeBuffer.new("<b><em>Post #{id}</em></b>")
  end

  def self.zombie_killer
    now = Time.now
    
    # Just report, no actually deleting dropped Posts
    zombie_cnt = where(Sequel.lit('previous_refresh <= ?', now - 10*Aging::ONE_DAY)).count
    unread_cnt = where(click: 0, hide: 0).where(Sequel.lit('previous_refresh <= ?', now - 10*Aging::ONE_DAY)).count
    puts "10+ day zombies: #{zombie_cnt}, #{unread_cnt} unread."

    9.downto(1).each do |i|
      from = now - i*Aging::ONE_DAY
      to = now - (i-1)*Aging::ONE_DAY
      zombie_cnt = where(Sequel.lit('? < previous_refresh AND previous_refresh <= ?', from, to)).count
      unread_cnt = where(click: 0, hide: 0).where(Sequel.lit('? < previous_refresh AND previous_refresh <= ?', from, to)).count
      puts "#{i} day zombies: #{zombie_cnt}, #{unread_cnt} unread."
    end
  end
end
