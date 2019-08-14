Amethyst::App.controllers :post do
  get :index do
    @origin = get_origin!
    
    if params[:feed_id].nil?
      @posts = Post.where(click: false, hide: false).order(Sequel.desc(:published_at)).all
      @context = 'Posts'
    else
      @posts = Post.where(feed_id: params[:feed_id], click: false, hide: false).order(Sequel.desc(:published_at)).all
      if !@posts.empty?
        @context = @posts[0].feed.title
      else
        feed = Feed.with_pk! params[:feed_id]
        @context = feed.title
      end
    end
    render 'index'
  end

  get :show, '/post/:id' do
    @origin = get_origin!
    
    @post = Post.with_pk! params[:id]
    @post.click = true
    @post.save

    @post.feed.score += 1.0
    @post.feed.clicks += 1
    @post.feed.save

    render 'show'
  end
end
