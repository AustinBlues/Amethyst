Sequel.migration do
  up do
    alter_table :feeds do
      drop_column :debug
      drop_column :encoding
    end
    alter_table :posts do
      drop_column :undo_queue
      drop_column :readability
      drop_column :down_votes
      drop_column :status
    end
  end

  down do
    alter_table :feeds do
      add_column :debug, String
      add_column :encoding, Integer, limit: 1
    end
    alter_table :posts do
      add_column :undo_queue, Integer
      add_column :readability, TrueClass, default: false, null: false
      add_column :down_votes, Integer
      add_column :status, String
    end
  end
end
