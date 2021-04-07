require File.expand_path(File.dirname(__FILE__) + '/../lib/nokogiri_rss.rb')

class Post < Sequel::Model
  many_to_one :feed
  many_to_many :word, join_table: :occurrences
  extend Amethyst::App::AmethystHelper

  ONE_DAY = 24 * 60 * 60
  WORDS_LIMIT = 300	# maximum words in word cloud

  # state enumeration
  UNREAD = 0
  READ = 1
  HIDDEN = 2
  DOWN_VOTED = 3


  def before_create
    super
    if self[:url] =~ / /
      self[:url].gsub!(/ /, '%20')	# fix for Six Questions for mistake
      STDERR.puts "Fixing spaces in URL for '#{self[:title]}' of '#{feed.name}'."
    end
  end


  def after_create
    create_word_cloud
    super
  end


  def create_word_cloud
    cwords = []	# force scope
    begin
      open(self[:url]) do |f|
        f.unlink if f.is_a?(Tempfile)	# Tempfile recommended best practices
        puts("URL(#{f.class.inspect}): #{self[:url]}.") unless f.is_a?(Tempfile) || f.is_a?(StringIO)	# debugging/exploration
        doc = Nokogiri::HTML.parse(f)
        content = doc.css('p').map{|i| i.content}.join(' ')
        cwords = content.split(/[^[[:word:]]]+/).take(WORDS_LIMIT)
      end
    rescue Errno::ENOENT
      Refresh.log "URL '#{self[:url]}' not found.", :error
    rescue OpenURI::HTTPError
      Refresh.log "URL '#{self[:url]}' forbidden (403).", :error
    rescue
      Refresh.log "Unknown error(#{$!.class}): #{$!}.", :error
    end

    dwords = Post.html2words(self[:description]).take(WORDS_LIMIT)

    words = (cwords.size > dwords.size) ? cwords : dwords

    words.each do |word|
      if word !~ /^\s*$/
        w = Word.update_or_create(name: word) do |w|
          if w.new? || w[:frequency].nil?
            w[:frequency] = 1.0
          else
            w[:frequency] += 1.0
          end
        end

        if !Occurrence.where(post_id: self[:id], word_id: w[:id]).get(1)
          Occurrence.create(post_id: self[:id], word_id: w[:id], count: 1)
        else
          Occurrence.where(post_id: self[:id], word_id: w[:id]).update(Sequel.lit('count = count + 1'))
        end
      end
    end
  end


  def word_cloud(limit = 1.0)
    Word.join(:occurrences, post_id: self[:id], word_id: :id).where(flags: 0).where{frequency > limit}.all
  end

  
  def name
    (!self[:title].nil? && !self[:title].empty?) ? self[:title] : SafeBuffer.new("<b><em>Post #{self[:id].inspect}</em></b>")
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
    end
    self[:state] = UNREAD
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
    self[:previous_refresh] && feed[:previous_refresh] && (self[:previous_refresh] < feed[:previous_refresh])
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
    word.each do |w|
      w[:frequency] -= Occurrence.where(word_id: w[:id], post_id: self[:id]).get(:count) || 0.0
      if w[:frequency] < 0
        STDERR.puts "OOPS: '#{w[:name]}' frequency is #{w[:frequency]}, resetting to 0.0."
        w[:frequency] = 0.0
      end
      w.save(changed: true)
    end
    remove_all_word

    super
  end


  def self.zombie_killer
    where(Sequel.lit('previous_refresh <= ?', Time.now - DAYS_OF_THE_DEAD*ONE_DAY)).each do |z|
      z.destroy
    end
  end


  def self.zombie_listing
    now = Time.now
    
    zombie = where(Sequel.lit('previous_refresh <= ?', now - DAYS_OF_THE_DEAD*ONE_DAY))
    zombie_cnt = zombie.count
    unread_cnt = zombie.where(state: UNREAD).count
    STDERR.puts "Deleting all #{DAYS_OF_THE_DEAD}+ day zombies: #{zombie_cnt}, #{unread_cnt} unread."

    (DAYS_OF_THE_DEAD-1).downto(DAYS_OF_THE_DEAD-5).each do |i|
      from = now - (i+1)*ONE_DAY
      to = now - i*ONE_DAY
      zombie = where(Sequel.lit('? <= previous_refresh AND previous_refresh < ?', from, to))
      unread = zombie.where(state: UNREAD)
      unread_cnt = unread.count
      unread.each do |p|
        STDERR.puts "'#{p.name}' on #{p.feed.name}."
      end
      STDERR.puts "#{i} day zombies: #{zombie.count}, #{unread_cnt} unread."
    end
  end
end
