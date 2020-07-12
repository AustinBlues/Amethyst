Amethyst::App.controllers :feed do
  get :index do
    @origin = get_origin!
    record_count = Feed.count
    @page = (params[:page] || 1).to_i
    tmp = pages_limit(@page, record_count)
    if tmp != @page
      redirect url_for(:feed, :index, page: tmp)
    else
      @controller = :feed
      @action = :index
      @context = 'Feeds'
      @options = {page: (params[:page] || 1).to_i}
      @feeds = if !PAGINATED
                 Feed.order(Sequel.desc(:score))
               else
                 Feed.order(Sequel.desc(:score)).paginate(@page, PAGE_SIZE)
               end
      render 'index'
    end
  end


  get :show, '/feed/:id' do
#    @origin = get_origin!
    @feed = Feed.with_pk! params[:id]
    @page = (params[:page] || 1).to_i
    @controller = :feed
    @action = :show

    @options = {page: @page}
    @options[:id] = params[:id]

    @context = @feed.name	# allow URL for new Feeds that haven't refreshed or have no title tag
#    @feed_page = @feed.page_number
    @posts = Post.unread.where(feed_id: @feed.id).order(Sequel.desc(:published_at))
    tmp = pages_limit(@page, @posts.count)
    if tmp != @page
      redirect url_for(:feed, :show, id: @feed.id, page: tmp)
    else
#      @datetime_only = true
      @posts = @posts.paginate(@page, PAGE_SIZE) if PAGINATED

      puts "PAGE_COUNT: #{@posts.page_count}."
      puts "PAGINATION_RECORD_COUNT: #{@posts.pagination_record_count}."
      puts "CURRENT_PAGE_RECORD_COUNT: #{@posts.current_page_record_count}."
#      @button = button_to 'Create', @url
      render 'show'
    end
  end
  

  post :create, '/feed' do
    # I'm surprised I have to do this.
    params.delete('authenticity_token')

    begin
      w = Feed.create(params)
    rescue Sequel::UniqueConstraintViolation => e
      if /unique_(\w+)s'/ !~ e.to_s
        STDERR.puts "'#{params[:rss_url]}' already followed."
        w = Feed.where(rss_url: params[:rss_url]).first
        flash[:warning] = "'#{w.name}' already followed."
      else
        flash[:error] = "Duplicate #{$~[1]}."
        case $~[0]
        when 'title'
          w = Feed.where(title: params[:title]).first
        when 'filename'
          w = Feed.where(filename: params[:filename]).first
        else
          w = Feed.first
        end
      end
    rescue Exception => e
      flash[:error] = "Unknown exception: #{e}."
      w = Feed.first
    end

    # Redirect to index where new feed will appear.
    redirect url_for(:feed, :index, page: w.page_number)
  end


  get :edit, with: :id do
    @feed = Feed.with_pk! params[:id]
    url = url_for(:feed, :update, id: @feed.id)
    partial('feed/form', object: @feed, locals: {url: url, button: button_to('Update', url, method: :put, class: :form)})
  end

  
  put :update, with: :id do
    # I'm surprised I have to do this.
    params.delete('authenticity_token')
    params.delete('_method')

    begin
      feed = Feed.load(params).save
    rescue Sequel::UniqueConstraintViolation => e
      flash[:error] = (/unique_(\w+)s'/ =~ e.to_s) ? "Duplicate #{$~[1]}." : 'Unique Constraint Violation'
    rescue
      flash[:error] = 'Unknown exception'
    ensure
      feed ||= Feed.with_pk! params[:id]
    end

    redirect url(:feed, :index, page: feed.page_number)
  end


  delete :destroy, with: :id do
    feed = Feed[params[:id]]
    if feed
      if feed.destroy
        flash[:success] = 'Delete successful'
      else
        flash[:error] = 'Delete failed'
      end
      redirect url(:feed, :index)
    else
      flash[:warning] = pat(:delete_warning, :model => 'feed', :id => "#{params[:id]}")
      halt 404
    end
  end
end
