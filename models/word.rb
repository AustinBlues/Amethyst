class Word < Sequel::Model
  many_to_many :word, join_table: :contexts, left_key: :prev_id, right_key: :next_id
  many_to_many :post, join_table: :occurrences
end
