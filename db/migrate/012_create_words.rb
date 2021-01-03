Sequel.migration do
  up do
    create_table :words do
      primary_key :id
      column :score, :float, default: 0.0
      column :flags, :tinyint, default: 0
      column :name, String, null: false
    end
    create_table :occurrences do
      foreign_key :post_id, :posts
      foreign_key :word_id, :words
      column :score, :float, default: 0.0
    end
    create_table :contexts do
      foreign_key :prev_id, :words
      foreign_key :next_id, :words
      column :score, :float, default: 0.0
    end
  end

  down do
    drop_table :occurrences
    drop_table :contexts
    drop_table :words
  end
end
