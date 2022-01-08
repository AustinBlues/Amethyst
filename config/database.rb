Sequel::Model.raise_on_save_failure = false # Do not throw exceptions on failure
login = "#{ENV['DB_USER'] || 'amethyst'}:#{ENV['DB_PWD'] || 'mypwd'}@localhost"
Sequel::Model.db = case Padrino.env
                   when :production  then Sequel.connect("mysql2://#{login}/#{ROOT}_production", :encoding => 'utf8mb4',
                                                         :loggers => [logger])
#                   when :development then Sequel.connect("mysql2://#{login}/#{ROOT}_development",  :loggers => [logger])
                   when :development then Sequel.connect("mysql2://#{login}/#{ROOT}_production", :encoding => 'utf8mb4',
                                                         :loggers => [logger])
                   when :test then Sequel.connect("mysql2://#{login}/#{ROOT}_test", :encoding => 'utf8mb4',
                                                  :loggers => [logger])
end
Sequel::Model.db.extension :pagination
Sequel::Model.plugin :update_or_create	# includes find_or_new() method
