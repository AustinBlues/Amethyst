Amethyst::App.controllers :post do
  get :index do
    if params[:feed_id]
      @posts = Post.where(feed_id: params[:feed_id]).order(Sequel.desc(:published_at)).all
      @context = @posts[0].feed.title
    else
      @posts = Post.order(Sequel.desc(:published_at)).all
      @context = 'Posts'
    end
    render 'index'
  end
end
