Sequel.migration do
  up do
    alter_table :posts do
      drop_column :hide
      drop_column :click
    end
  end

  down do
    alter_table :posts do
      add_column :hide, TrueClass, limit: 1, default: 0, null: false
      add_column :click, TrueClass, limit: 1, default: 0, null: false
    end
  end
end
