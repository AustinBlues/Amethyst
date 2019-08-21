module Aging
  # Exponential Moving Average (i.e. Feed volume and score) parameters
  DAYS = 20
  ALPHA = 2.0/(DAYS + 1.0)

  def self.perform
    Feed.age
    Post.zombie_killer
  end
end
