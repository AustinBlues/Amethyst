Amethyst::App.controllers :post do
  get :index do
    @origin = get_origin!
    @page = (params[:page] || 1).to_i
    @controller = :post
    @action = :index
    @options = {page: @page}
    
    if params[:feed_id].nil?
      @posts = Post.unread.order(Sequel.desc(:published_at))
      tmp = pages_limit(@page, @posts.count)
      if tmp != @page
        redirect url_for(:post, :index, page: tmp)
      else
        @context = 'Posts'
        @datetime_only = false
        @posts = @posts.paginate(@page, PAGE_SIZE) if PAGINATED

        render 'index'
      end
    else
      @options[:feed_id] = @feed_id = params[:feed_id]
      feed = Feed.with_pk! @feed_id
      @context = feed.name	# allow URL for new Feeds that haven't refreshed or have no title tag
      @feed_page = feed.page_number
      @posts = Post.unread.where(feed_id: @feed_id).order(Sequel.desc(:published_at))
      tmp = pages_limit(@page, @posts.count)
      if tmp != @page
        redirect url_for(:post, :index, feed_id: @feed_id, page: tmp)
      else
        @datetime_only = true
        @posts = @posts.paginate(@page, PAGE_SIZE) if PAGINATED

        render 'index'
      end
    end
  end


  get :search do
    @origin = get_origin!
    @page = (params[:page] || 1).to_i
    @controller = :post
    @action = :search
    @context = "Search: '#{params[:search]}'"
    @options = {page: @page, search: params[:search]}
    @posts = Post.dataset.full_text_search([:title, :description], params[:search])
    @posts = @posts.paginate(@page, PAGE_SIZE) if PAGINATED

    render 'index'
  end


  get :show, '/post/:id' do
    @origin = get_origin!
    @back_title = (@origin =~ /search/) ? 'to Search' : 'to Posts'

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
