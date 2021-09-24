require 'rubygems'
require 'resque'


# Just enough to make Resque work
module Daily
  @queue = :daily
end

Resque.redis = Redis::Namespace.new(ENV['PWD'].split('/').last, redis: Redis.new)
Resque.enqueue(Daily)


