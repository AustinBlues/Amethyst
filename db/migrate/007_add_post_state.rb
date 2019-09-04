Sequel.migration do
  up do
    alter_table :posts do
      add_column :state, :tinyint, default: 0
    end
    alter_table :feeds do
      add_column :down_votes, :smallint, default: 0
    end
  end

  down do
    alter_table :posts do
      drop_column :state
    end
    alter_table :feeds do
      drop_column :down_votes, :smallint, default: 0
    end
  end
end
