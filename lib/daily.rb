module Daily
  extend Amethyst::App::PostHelper

  # Exponential Moving Average (i.e. Feed volume and score) parameters
  ALPHA = 2.0/(EMA_DAYS + 1.0)

  # done this way so can be used by Resque
  def self.perform
    Refresh.log "Daily maintenance at #{short_datetime(Time.now)}."
    Feed.age
    Post.zombie_killer
  end
end
