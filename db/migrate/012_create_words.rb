Sequel.migration do
  up do
    create_table :words do
      primary_key :id
      column :frequency, :float, default: 0.0
      column :flags, :tinyint, default: 0
      column :name, String, collate: :utf8mb4_nopad_bin, index: true, null: false
    end
    stop_words = %w{a about an are as at be by com de en for from how i in is it la
    of on or that the this to was what when where who will with und the www}
    stop_words.each do |sw|
      from(:words).insert(name: sw, frequency: 0.0, flags: 1)
      from(:words).insert(name: sw.capitalize, frequency: 0.0, flags: 1)
    end
    create_table :occurrences do
      foreign_key :post_id, :posts
      foreign_key :word_id, :words
      column :count, :smallint, default: 0
    end
    create_table :contexts do
      foreign_key :prev_id, :words
      foreign_key :next_id, :words
      column :count, :smallint, default: 0
    end
  end

  down do
    drop_table :occurrences
    drop_table :contexts
    drop_table :words
  end
end
