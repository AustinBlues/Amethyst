Amethyst::App.controllers :post do
  get :index do
    @origin = get_origin!

    if params[:feed_id].nil?
      @posts = Post.unread.order(Sequel.desc(:published_at))
      @context = 'Posts'
    else
      feed = Feed.with_pk! params[:feed_id]
      @context = feed.title
      @posts = Post.unread.where(feed_id: params[:feed_id]).order(Sequel.desc(:published_at))
    end
    render 'index'
  end

  get :show, '/post/:id' do
    @origin = get_origin!
    
    @post = Post.with_pk! params[:id]
    @post.click!
    @post.save(changed: true)

    render 'show'
  end

  
#  put :hide, '/post/:id/hide' do
  get :hide, '/post/:id/hide' do
    @origin = get_origin!
    
    @post = Post.with_pk! params[:id]
    @post.hide!
    @post.save(changed: true)

    redirect @origin
  end

  
#  put :down, '/post/:id/down' do
  get :down, '/post/:id/down' do
    @origin = get_origin!
    
    @post = Post.with_pk! params[:id]
    @post.down_vote!
    @post.save

    redirect @origin
  end

  
#  put :unclick, '/post/:id/unclick' do
  get :unclick, '/post/:id/unclick' do
    @origin = get_origin!
    
    @post = Post.with_pk! params[:id]
    @post.unclick!
    @post.save

    redirect @origin
  end
end
