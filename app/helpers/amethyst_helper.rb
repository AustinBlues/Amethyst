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
    end

    helpers AmethystHelper
  end
end
