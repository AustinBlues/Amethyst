Sequel.migration do
  up do
    drop_table :contexts
  end

  down do
    create_table :contexts do
      foreign_key :prev_id, :words
      foreign_key :next_id, :words
      column :count, :smallint, default: 0
    end
  end
end
