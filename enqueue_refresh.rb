require 'rubygems'
require 'resque'


# Just enough to make Resque work
module Refresh
  @queue = :Refresh
end


Resque.enqueue(Refresh)
