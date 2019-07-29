Sequel::Model.raise_on_save_failure = false # Do not throw exceptions on failure
Sequel::Model.db = case Padrino.env
  when :development then Sequel.connect("mysql2://localhost/amethyst_development", :loggers => [logger])
  when :production  then Sequel.connect("mysql2://localhost/amethyst_production",  :loggers => [logger])
  when :test        then Sequel.connect("mysql2://localhost/amethyst_test",        :loggers => [logger])
end
