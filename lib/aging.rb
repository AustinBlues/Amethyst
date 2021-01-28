module Aging
  # Exponential Moving Average (i.e. Feed volume and score) parameters
  DAYS = 90
  ALPHA = 2.0/(DAYS + 1.0)
  ALPHA2 = 2.0/(2*DAYS + 1.0)

  # done this way so can be used by Resque
  def self.perform
    Feed.age
    Post.zombie_killer
  end
end
