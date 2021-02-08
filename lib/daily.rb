require 'benchmark'

module Daily
  # Exponential Moving Average (i.e. Feed volume and score) parameters
  DAYS = 90
  ALPHA = 2.0/(DAYS + 1.0)
  ALPHA2 = 2.0/(2*DAYS + 1.0)

  @queue = :daily	# lower priority than upper case names
  
  # done this way so can be used by Resque
  def self.perform
    Refresh.log "Daily maintenance at #{short_datetime(Time.now)}."
    Benchmark.bm do |x|
      x.report{ Feed.age }
      x.report{ Post.zombie_killer}
      x.report{ Word.age }
    end
  end
end
