Sequel.migration do
  up do
    alter_table :words do
      set_column_type :frequency, :smallint, default: 0
    end
    alter_table :feeds do
      add_column :use_body, TrueClass, default: true, null: false
      add_column :log_body, TrueClass, default: false, null: false
      add_column :log_body_words, TrueClass, default: false, null: false
      add_column :use_description, TrueClass, default: true, null: false
      add_column :log_description, TrueClass, default: false, null: false
      add_column :log_description_words, TrueClass, default: false, null: false
    end
  end

  down do
    alter_table :feeds do
      drop_column :use_body
      drop_column :log_body
      drop_column :log_body_words
      drop_column :use_description
      drop_column :log_description
      drop_column :log_description_words
    end
    alter_table :words do
      set_column_type :frequency, :float, default: 0.0
    end
  end
end
