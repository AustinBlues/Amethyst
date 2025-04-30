Sequel.migration do
  up do
    alter_table :words do
      set_column_type :frequency, :mediumint, default: 0
    end
  end

  down do
    raiseraise ActiveRecord::IrreversibleMigration
  end
end
