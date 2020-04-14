Sequel.migration do
  up do
    alter_table :posts do
      add_full_text_index [:title, :description]
    end
  end

  down do
    alter_table :posts do
      drop_index [:title, :description]
    end
  end
end
