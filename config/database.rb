Sequel::Model.raise_on_save_failure = false # Do not throw exceptions on failure
Sequel::Model.db = case Padrino.env
  when :production  then Sequel.connect("mysql2://rails:mypwd@localhost/#{ROOT}_production",  :loggers => [logger])
  when :production  then Sequel.connect("mysql2://rails:mypwd@localhost/#{ROOT}_development",  :loggers => [logger])
  when :test        then Sequel.connect("mysql2://rails:mypwd@localhost/#{ROOT}_test",        :loggers => [logger])
end
Sequel::Model.db.extension :pagination
Sequel::Model.plugin :update_or_create	# includes find_or_new() method
