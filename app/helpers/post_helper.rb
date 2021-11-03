# Helper methods defined here can be accessed in any controller or view in the application

module Amethyst
  class App
    module PostHelper
      def post_classes(post)
        classes = []
        classes << 'zombie' if post.zombie?
        if post.hidden? || post.state == Post::DOWN_VOTED
          classes << 'hidden'
        elsif post.clicked?
          classes << 'clicked'
        end
        classes.join(' ')
      end

      def short_datetime(time)
        if time.nil?
          'nil'
        else
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
    end

    helpers PostHelper
  end
end
