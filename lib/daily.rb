require 'benchmark'

module Daily
  extend Amethyst::App::PostHelper

  # Exponential Moving Average (i.e. Feed volume and score) parameters
  ALPHA = 2.0/(EMA_DAYS + 1.0)

  @queue = :daily	# lower priority than upper case names
  
  # done this way so can be used by Resque
  def self.perform
    Refresh.log "Daily maintenance at #{short_datetime(Time.now)}."
    Benchmark.bm do |x|
      x.report('Feed: '){ Feed.age }
      x.report('Zombie: '){ Post.zombie_killer}
      x.report('Word: '){ Word.age }
    end
  end
end
