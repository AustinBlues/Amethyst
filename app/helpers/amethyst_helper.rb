module Amethyst
  class App
    module AmethystHelper
      def page_number(count)
        (count-1)/PAGE_SIZE + 1
      end


      def pages_limit(page, count)
        pages = page_number(count)
        (pages == 0) ? 1 : page.clamp(1, pages)
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
