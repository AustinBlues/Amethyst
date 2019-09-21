module Amethyst
  class App
    module AmethystHelper
      def get_origin!
        origin = if [:index].include?(request.action)
                   request.fullpath
                 else
                   params.delete(:origin)
                 end
#        puts "ORIGIN: #{origin}."
        origin
      end

      def flash_class(level)
        case level
        when :notice then 'alert alert-info'
        when :success then 'alert alert-success'
        when :error then 'alert alert-danger'
        when :alert then 'alert alert-warning'
        else
          'alert-warning'
        end
      end

      def short_datetime(time)
        today = Date.today
        fmt = if time.to_date == today
                 '%-l:%M%P'
              elsif time.year == today.year
                '%-m/%-e'
              else
                # should be extended for full century?
                '%-m/%-e/%y'
              end
        time.strftime(fmt)
      end
    end

    helpers AmethystHelper
  end
end
