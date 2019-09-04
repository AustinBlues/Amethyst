Sequel.migration do
  up do
    alter_table :posts do
      add_column :status, String, default: nil, null: true
    end
  end

  down do
    alter_table :posts do
      drop_column :status
    end
  end
end
