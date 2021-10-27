Amethyst::App.controllers :post do
  before do
    @controller = :post
    @action = request.action
    @current_url = request.fullpath
    @origin = if [:index].include?(@action)
                @current_url
              else
                params.delete(:origin)
              end
    puts("ORIGIN: #{@origin}.") if Padrino.env != :test
  end

  
  get :index do
    @page = (params[:page] || 1).to_i
    if @page <= 0
      redirect url_for(:post, :index, page: 1)
    else
      if params[:order] == 'cull'
        # KLUDGE this is more my use culling The Hill feeds
        now = Time.now
        midnight = Time.new(now.year, now.month, now.day)
#        tmp = Post.unread.where{published_at < midnight}
        tmp = Post.unread.where(Sequel.lit('published_at < ?', midnight))
        @posts = Post.where(title: tmp.map{|p| p[:title]}).order(:title).paginate(@page, PAGE_SIZE)
      else
        order = case params[:order]
                when 'title'
                  :title
                when 'published'
                  Sequel.desc(:published_at)
                when 'id'
                  Sequel.desc(:id)
                else
                  flash[:error] = 'Unsupported order' unless params[:order].nil?
                  Sequel.desc(:published_at)
#                  Sequel.desc(:id)
                end
        @posts = Post.unread.order(order).paginate(@page, PAGE_SIZE)
      end
      if @page > @posts.page_count
        redirect url_for(:post, :index, page: @posts.page_count)
      else
        @context = 'Posts'

        @pagination = {page: @page, order: params[:order], search: params[:search]}	# used in _pagination
        
        @datetime_only = false
        @back_title = 'to Feeds'
        @back_url = url_for(:feed, :index)

        render 'index'
      end
    end
  end


  get :search do
    @back_url = @origin
    @page = (params[:page] || 1).to_i
    @context = "Search: '#{params[:search]}'"
    @pagination = {page: @page, search: params[:search], origin: @origin}	# used in _pagination
    @back_title = case @back_url
                  when /^\/post/
                    'to Posts'
                  when /^\/feed/
                    'to Feeds'
                  when /^\/post\/search/
                    'to Search'
                  else
                    flash[:error] = 'Unknown origin'
                    STDERR.puts "UNKNOWN ORIGIN: #{params[:origin]}."
                    'UNKNOWN'
                  end
    @datetime_only = false
    ds = Post.dataset.full_text_search([:title, :description], params[:search]).reverse(:id)
    @posts = ds.paginate(@page, PAGE_SIZE)

    render 'index'
  end


  get :show, '/post/:id' do
    @context = 'Post'    
    @back_title = case @origin
                  when /search/
                    'to Search'
                  when /feed/
                    'to Feed show'
                  when /post/
                    'to Posts'
                  else
                    'Unknown'
                  end

    @post = Post.with_pk! params['id']
    @post.click!
    @post.save(changed: true)

    render 'show'
  end


#  put :hide, '/post/:id/hide' do
  get :hide, '/post/:id/hide' do
    post = Post.with_pk! params.delete('id')
    post.hide!
    post.save(changed: true)

    if !params[:search].nil?
      params[:origin] = @origin
      puts "HIDE from SEARCH ORIGIN: #{@origin}."
      redirect url_for(:post, :search, params)
    elsif @origin =~ %r{^/post}
      redirect url_for(@origin)
    elsif @origin =~ %r{^/feed}
      redirect url_for(@origin)
    else
      raise "Unknown origin: #{@origin}."
    end
  end

  
#  put :down, '/post/:id/down' do
  get :down, '/post/:id/down' do
    post = Post.with_pk! params[:id]
    post.down_vote!
    post.save(changed: true)


    if !params[:search].nil?
      params[:origin] = @origin
      puts "HIDE from SEARCH ORIGIN: #{@origin}."
      redirect url_for(:post, :search, params)
    elsif @origin =~ %r{^/post}
      redirect url_for(@origin)
    elsif @origin =~ %r{^/feed}
      redirect url_for(@origin)
    else
      raise "Unknown origin: #{@origin}."
    end
#    redirect url_for(:post, params[:search] ? :search : :index, params)
  end

  
#  put :unclick, '/post/:id/unclick' do
  get :unclick, '/post/:id/unclick' do
    post = Post.with_pk! params[:id]
    post.unclick!
    post.save

    redirect @origin
  end
end
