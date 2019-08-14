module Amethyst
  class App
    module AmethystHelper
      def get_origin!
        origin = if [:index].include?(request.action)
                   request.fullpath
                 else
                   params.delete(:origin)
                 end
        puts "ORIGIN: #{origin}."
        origin
      end
    end

    helpers AmethystHelper
  end
end
