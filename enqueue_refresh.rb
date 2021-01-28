require 'rubygems'
require 'resque'


# Just enough to make Resque work
module Refresh
  @queue = :Refresh
end

Resque.redis = Redis::Namespace.new(ENV['PWD'].split('/').last, redis: Redis.new)
Resque.enqueue(Refresh)
