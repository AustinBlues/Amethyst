padrino_env   = ENV["PADRINO_ENV"] ||= ENV["RACK_ENV"] ||= "development"
resque_config = YAML.load_file Padrino.root('config','resque.yml')
Resque.redis  = resque_config[padrino_env]
