Sequel.migration do
  up do
    alter_table :feeds do
      add_column :next_refresh, DateTime, null: true
    end
    Sequel::Model.db[:feeds].update(next_refresh: Time.now + Refresh::CYCLE_TIME)
  end

  down do
    alter_table :feeds do
      drop_column :next_refresh
    end
  end
end
