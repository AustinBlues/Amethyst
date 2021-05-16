module Daily
  extend Amethyst::App::PostHelper

  # done this way so can be used by Resque
  def self.perform
    Refresh.log "Daily maintenance at #{short_datetime(Time.now)}."
    Feed.age
    Post.zombie_killer
  end
end
