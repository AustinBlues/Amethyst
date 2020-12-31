class Word < Sequel::Model
  many_to_many :word, join_table: :occurrences, left_key: :prev_id, right_key: :next_id
end
