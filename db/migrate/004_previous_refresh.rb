Sequel.migration do
  up do
    alter_table :posts do
      add_column :previous_refresh, DateTime, null: true
    end
    alter_table :feeds do
      rename_column :refresh_at, :previous_refresh
    end
  end

  down do
    alter_table :posts do
      drop_column :previous_refresh
    end
    alter_table :feeds do
      rename_column :previous_refresh, :refresh_at
    end
  end
end
