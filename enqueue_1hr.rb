require 'rubygems'
require 'resque'

INTERVALS = 12	# KLUDGE

# Just enough to make Resque work
module Refresh
  @queue = :Refresh
end


Resque.redis = Redis::Namespace.new(ENV['PWD'].split('/').last, redis: Redis.new)
INTERVALS.times{Resque.enqueue(Refresh)}
