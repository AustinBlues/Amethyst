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

      
      def link_to_post_show(post, origin, datetime_only)
        title = if datetime_only
                  short_datetime(post[:published_at])
                else
                  "#{post.feed.name} #{short_datetime(post[:published_at])}"
                end
        link_to(post.name, url_for(:post, :show, id: post[:id], origin: origin), class: post_classes(post), title: title) 
      end
    end

    helpers PostHelper
  end
end
