Sequel.migration do
  up do
    alter_table :feeds do
      rename_column :moving_avg, :ema_volume
    end
  end

  down do
    alter_table :feeds do
      rename_column :ema_volume, :moving_avg
    end
  end
end
