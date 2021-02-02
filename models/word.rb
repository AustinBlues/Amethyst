class Word < Sequel::Model
  many_to_many :word, join_table: :contexts, left_key: :prev_id, right_key: :next_id
  many_to_many :post, join_table: :occurrences

  @word_id = nil

  def before_destroy
    @word_id = self[:id] if @word_id.nil?
    if true
      remove_all_post
    else
      total = Occurrence.where(word_id: self[:id]).sum(:count)
      n = Occurrence.where(word_id: self[:id]).delete
      puts("Word(#{@word_id}): deleting #{n} occurrences totaling #{total}.") if @word_id == self[:id]
    end
    n = Context.where(prev_id: self[:id]).delete
    puts("Word(#{@word_id}): deleting #{n} contexts.") if @word_id == self[:id]
    n = Context.where(next_id: self[:id]).delete
    puts("Word(#{@word_id}): deleting #{n} contexts.") if @word_id == self[:id]
    super
  end


  def self.age
    Word.all do |w|
      total = Occurrence.where(word_id: w[:id]).sum(:count) || 0
      if w[:frequency] != total
        if total == 0 && w[:flags] == 0
          STDERR.puts "Deleting unused, non-stopword '#{w[:name]}'."
          w.destroy
        else
          STDERR.puts "Correcting '#{w[:name]}' from #{w[:frequency]} to #{total.inspect}."
          w[:frequency] = total
          w.save(changed: true)
        end
      end
    end
  end
end
