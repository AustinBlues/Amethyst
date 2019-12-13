# Helper methods defined here can be accessed in any controller or view in the application

module Amethyst
  class App
    module FeedHelper
      # def simple_helper_method
      # ...
      # end

      # format a score
      def score_fmt(score, fmt = '%0.2f')
        if score.nil?
          'NULL' 
        else
          fmt % score
        end
      end

      # format an average
      def avg_fmt(avg)
        '%0.2f' % avg
      end

      def tooltip_fmt(feed)
        "Score: #{score_fmt(feed.score)} Click: #{feed.clicks} Hide: #{feed.hides} Down: #{feed.down_votes} (Vol: #{avg_fmt(feed.ema_volume)})"
      end
    end

    helpers FeedHelper
  end
end
