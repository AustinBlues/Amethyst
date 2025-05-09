class Word < Sequel::Model
  many_to_many :post, join_table: :occurrences

  def before_destroy
    remove_all_post
    if true
      Occurrence.where(word_id: self[:id]).delete
    end

    super
  end


  def self.age
    Word.each do |w|
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
