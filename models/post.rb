# coding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/../lib/nokogiri_rss.rb')

class Post < Sequel::Model
  include Sanitize
  many_to_one :feed
  many_to_many :word, join_table: :occurrences
  include Sanitize
  extend Amethyst::App::AmethystHelper

  ONE_DAY = 24 * 60 * 60
  WORDS_LIMIT = 500	# maximum words in word cloud
  WC_MIN = 30	# minimum number of words in word cloud for culling

  VERBOSE = false

  # state enumeration
  STATES = %w{UNREAD READ HIDDEN DOWN_VOTED}
  UNREAD = 0
  READ = 1
  HIDDEN = 2
  DOWN_VOTED = 3

  # action to score adjustment mapping
  SCORE = {READ => 1.0, DOWN_VOTED => -1.0}
  SCORE.default = 0


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
    if feed.log_body || feed.use_body || feed.log_body_words
      begin
        open(self[:url]) do |f|
          f.unlink if f.is_a?(Tempfile)	# Tempfile recommended best practices
          doc = Nokogiri::HTML.parse(f)
          STDOUT.puts("BODY: #{doc.css('body').inner_html}.") if feed.log_body
          tmp = []
          doc.css('body p').each do |p|
            tmp.concat(p.content.split(/[^[[:word:]]]+/))
          end
          # Delete words that are likely programming code
          tmp.delete_if{|w| (w =~ /^[[:xdigit:]]+$/) || (w =~ /^\w+_.*\w$/) || (w =~ /^\d\w+\d$/)}
          cwords = tmp.take(WORDS_LIMIT)
          STDOUT.puts("BWORDS: #{cwords.inspect}.") if feed.log_body_words
        end
      rescue Errno::ENOENT
        Refresh.log "URL '#{self[:url]}' not found.", :error
      rescue OpenURI::HTTPError
#        Refresh.log "URL '#{self[:url]}' forbidden (403).", :error
        Refresh.log "URL '#{self[:url]}' #{$!}.", :error
      rescue RuntimeError
        Refresh.log "#{$!}.", :error
      rescue
        Refresh.log "Unknown error(#{$!.class}): #{$!}.", :error
      end
    end

    dwords = []
    if feed.log_description || feed.use_description || feed.log_description_words
      begin
        STDOUT.puts("DESCRIPTION: #{self[:description]}.") if feed.log_description
        tmp = self[:description].nil? ? [] : self[:description].split(/[^[[:word:]]]+/)
        n = tmp.size
        tmp.delete_if{|w| result = (w !~ /^\w+$/); puts("DELETE: '#{w}'") if result && feed.log_description; result}
        if feed.log_description_words
          n -= tmp.size
          puts("DWORDS: #{n} numbers and words with underscores deleted.") if n != 0
          STDOUT.puts("DWORDS(#{self[:title]}): #{tmp.take(WORDS_LIMIT).inspect}.")
        end
        dwords = tmp.take(WORDS_LIMIT) if feed.use_description
      rescue
        STDERR.puts "EXCEPTION: #{$!}."
        STDERR.puts $!.backtrace
      end
    end

    words = (cwords.size > dwords.size) ? cwords : dwords

    if words.size > WC_MIN
      wc = {}
      words.each do |word|
        if word !~ /^\s*$/
          if wc.key?(word)
            wc[word][:frequency] += 1
          else
            w = Word.update_or_create(name: word) do |w|
              if w.new? || w[:frequency].nil?
                w[:frequency] = 1
              else
                w[:frequency] += 1
              end
            end

            wc[word] = {frequency: w[:frequency].to_i}
            if !Occurrence.where(post_id: self[:id], word_id: w[:id]).get(1)
              Occurrence.create(post_id: self[:id], word_id: w[:id], count: 1)
              wc[word][:count] = 1
            else
              count = Occurrence.where(post_id: self[:id], word_id: w[:id]).get(:count)
              wc[word][:count] = count
            end
            wc[word][:strength] = wc[word][:count].to_f/wc[word][:frequency].to_f
          end
        end
      end

      # calculate word strengths
      avg = 0.0
      wc.each do |key, value|
        value[:strength] = value[:count].to_f/value[:frequency].to_f
        avg += value[:strength]
      end
      avg /= wc.size

      # cull low strength words
      limit = 2.0 * avg
      x = wc.sort_by{|key, value| value[:strength]}
      i = 0
      while x[i][1][:strength] <= limit do
#        puts "Culling: '#{x[i][0]}' #{x[i][1][:count]}/#{x[i][1][:frequency].to_i}."
        limit -= x[i][1][:strength]
        wc.delete(x[i][0])
        i += 1
      end
#      puts "Culled: #{x.size-wc.size}/#{x.size}."

      culled_score = 100.0 * wc.inject(0.0){|sum, tuple| sum += tuple[1][:strength]}
      full_score = 100.0 * x.inject(0.0){|sum, tuple| sum += tuple[1][:strength]}
#      puts "Culled score #{'%0.2g' % (100.0 * (1.0 - (culled_score/full_score)))}% less than full score."

      # write the rest to the database
#      puts("WC: #{wc.inspect}.") if self[:title] == 'Dust – a poem by Cathleen Cohen'
      wc.each do |key, value|    
        word = Word.update_or_create(name: key) do |p|
          p[:frequency] = value[:frequency]
        end
        Occurrence.update_or_create(post_id: self[:id], word_id: word[:id]) do |occ|
          occ[:count] = value[:count]
        end
      end
    else
#      puts "No culling of weak words."
      words.each do |word|
        if word !~ /^\s*$/
          w = Word.update_or_create(name: word) do |w|
            if w.new? || w[:frequency].nil?
              w[:frequency] = 1
            else
              w[:frequency] += 1
            end
          end

          if !Occurrence.where(post_id: self[:id], word_id: w[:id]).get(1)
            Occurrence.create(post_id: self[:id], word_id: w[:id], count: 1)
          else
            Occurrence.where(post_id: self[:id], word_id: w[:id]).update(Sequel.lit('count = count+1'))
          end
        end
      end
    end
  end


  def word_cloud(limit = 1.0)
    Word.join(:occurrences, post_id: self[:id], word_id: :id).where(flags: 0).where{frequency > limit}.all
  end


  def title=(str)
    self[:title] = str
    if sanitize!(:title, VARCHAR_MAX)
      Refresh.log(feed.status = 'Post title sanitized', :info) if VERBOSE
    end
  end

  
  def name
    (self[:title] && !self[:title].empty?) ? self[:title] : SafeBuffer.new("<b><em>Post #{id}</em></b>")
  end


  def description=(str)
    self[:description] = str
    if sanitize!(:description, TEXT_MAX)
      Refresh.log(feed.status = 'Post description sanitized', :info) if VERBOSE
    end
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
    if feed
      self[:previous_refresh] && feed[:previous_refresh] && (self[:previous_refresh] < feed[:previous_refresh])
    else
      STDERR.puts "ZOMBIE: #{self.inspect}."
      false
    end
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
      if w[:flags] == 0
        w[:frequency] -= Occurrence.where(word_id: w[:id], post_id: self[:id]).get(:count) || 0.0
        if w[:frequency] < 0
          STDERR.puts "OOPS: '#{w[:name]}' frequency is #{w[:frequency]}, resetting to 0.0."
          w[:frequency] = 0.0
        end
        w.save(changed: true)
      end
    end
    remove_all_word

    super
  end


  def self.zombie_listing
    now = Time.now
    
    zombie = where(Sequel.lit('previous_refresh <= ?', now - DAYS_OF_THE_DEAD*ONE_DAY))
    zombie_cnt = zombie.count
    unread_cnt = zombie.where(state: UNREAD).count

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


  def self.zombie_killer
    zombie = where(Sequel.lit('previous_refresh <= ?', Time.now - DAYS_OF_THE_DEAD*ONE_DAY))
    zombie_cnt = zombie.count
    unread_cnt = zombie.where(state: UNREAD).count
    puts "Deleting all #{DAYS_OF_THE_DEAD}+ day zombies: #{zombie_cnt}, #{unread_cnt} unread."
    zombie.each do |z|
      begin
        z.destroy
      rescue
        STDERR.puts "Exception(#{$!}) destroying '#{z.name}' (#{z[:id]})."
      end
    end
  end
end
