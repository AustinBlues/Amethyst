Sequel.migration do
  up do
    alter_table :posts do
      set_column_type :title, :text
    end
  end

  down do
    alter_table :posts do
      set_column_type :title, String
    end
  end
end
