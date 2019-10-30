Sequel.migration do
  up do
    alter_table :feeds do
      set_column_type :previous_refresh, :timestamp
      set_column_type :next_refresh, :timestamp
    end
    alter_table :posts do
      set_column_type :dropped_at, :timestamp
      set_column_type :previous_refresh, :timestamp
      set_column_type :published_at, :timestamp
    end
  end

  down do
    alter_table :feeds do
      set_column_type :previous_refresh, :Datetime
      set_column_type :next_refresh, :Datetime
    end
    alter_table :posts do
      set_column_type :dropped_at, :Datetime
      set_column_type :previous_refresh, :Datetime
      set_column_type :published_at, :Datetime
    end
  end
end
