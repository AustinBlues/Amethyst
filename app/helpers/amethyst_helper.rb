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


      def truncate(str, truncate_at, options = {})
        return str.dup unless str.length > truncate_at

#        options[:omission] ||= '...'
        options[:omission] ||= ELLIPSIS
        length_with_room_for_omission = truncate_at - options[:omission].length
        stop = if options[:separator]
                 str.rindex(options[:separator], length_with_room_for_omission) || length_with_room_for_omission
               else
                 length_with_room_for_omission
               end
        "#{str[0...stop]}#{options[:omission]}"
      end
    end

    helpers AmethystHelper
  end
end
