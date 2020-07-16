Amethyst::App.controllers :post do
  get :index do
 #   @origin = get_origin!
    @page = (params[:page] || 1).to_i
    if @page <= 0
      redirect url_for(:post, :index, page: 1)
    else
      @posts = Post.unread.order(Sequel.desc(:published_at)).paginate(@page, PAGE_SIZE)
      if @page > @posts.page_count
        redirect url_for(:post, :index, page: @posts.page_count)
      else
        @context = 'Posts'

        @controller = :post
        @action = :index

        @options = {page: @page}

        @datetime_only = false

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
    @post = Post.with_pk! params[:id]
    @post.down_vote!
    @post.save

    redirect request.referer
  end

  
#  put :unclick, '/post/:id/unclick' do
  get :unclick, '/post/:id/unclick' do
    @post = Post.with_pk! params[:id]
    @post.unclick!
    @post.save

    redirect request.referer
  end
end
