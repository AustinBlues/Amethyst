Sequel.migration do
  up do
    alter_table :feeds do
      set_column_type :score, :float
      set_column_type :moving_avg, :float
    end
  end

  down do
    alter_table :feeds do
      set_column_type :score, Numeric
      set_column_type :moving_avg, Numeric
    end
  end
end
