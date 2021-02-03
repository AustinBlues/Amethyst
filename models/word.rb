class Word < Sequel::Model
  many_to_many :word, join_table: :contexts, left_key: :prev_id, right_key: :next_id
  many_to_many :post, join_table: :occurrences


  def before_destroy
    if true
      remove_all_post
    else
      Occurrence.where(word_id: self[:id]).delete
    end
    Context.where(prev_id: self[:id]).delete
    Context.where(next_id: self[:id]).delete

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
