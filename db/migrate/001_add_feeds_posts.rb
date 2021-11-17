Sequel.migration do
  up do
    create_table :feeds do
      primary_key :id
      String	:rss_url,    unique: true, default: '',  null: false
      String	:title,	     default: nil, null: true
      Numeric	:moving_avg, default: 0.0, null: false
      String   	:status
      Datetime	:refresh_at
      String	:debug,      default: ''
      Integer	:encoding,   limit: 1
      Numeric	:score,      default: 0.0, null: false
      Integer	:clicks,     default: 0, null: false
      Integer	:hides,      default: 0, null: false
    end
    
    create_table :posts do
      primary_key :id
      foreign_key :feed_id
      TrueClass	:click,       limit: 1, default: 0, null: false
      TrueClass	:hide,        limit: 1, default: 0, null: false
      Integer	:undo_queue
      String	:title
      String	:url,         text: true, null: false
      add_column :description, type: :mediumtext
      String	:synopsis,    text: true
      Datetime	:dropped_at
      String	:ident,       text: true
      String	:time
      Datetime	:published_at
      TrueClass	:readability, default: false, null: false
    end
  end

  down do
    drop_table :posts
    drop_table :feeds
  end
end
