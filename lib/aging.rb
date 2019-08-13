module Aging
  # Exponential Moving Average (i.e. Feed volume and score) parameters
  DAYS = 20
  ALPHA = 2.0/(DAYS + 1.0)
  ONE_MINUS_ALPHA = 1.0 - ALPHA

#  def self.perform
#    Feed.age(ALPHA_MINUS_ONE)
#  end
end
