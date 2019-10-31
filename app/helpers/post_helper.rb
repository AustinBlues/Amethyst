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
    end

    helpers PostHelper
  end
end
