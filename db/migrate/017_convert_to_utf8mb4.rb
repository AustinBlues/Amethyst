Sequel.migration do
  up do
    run 'ALTER TABLE posts CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci'
  end

  down do
    run 'ALTER TABLE posts CONVERT TO CHARACTER SET utf8 COLLATE utf8_unicode_ci'
  end
end
