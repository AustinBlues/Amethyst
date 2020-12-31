Sequel.migration do
  up do
    create_table :words do
      primary_key :id
      column :occurrences, :float, default: 0.0
      column :flags, :tinyint, default: 0
      column :name, String, null: false
    end
    create_table :occurrences do
      foreign_key :prev_id, :words, null: false
      foreign_key :next_id, :words, null: false
      column :score, :float, default: 0.0
    end
  end

  down do
    drop_table :words
    drop_table :occurrences
  end
end
