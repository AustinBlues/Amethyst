Sequel.migration do
  up do
    alter_table :posts do
      set_column_type :description, :mediumtext
    end
  end

  down do
    alter_table :posts do
      set_column_type :description, :text
    end
  end
end
