Amethyst::App.controllers :feed do
  before do
    @controller = :feed
    @action = request.action
    @current_url = request.fullpath
    @origin = if [:index].include?(@action)
                @current_url
              else
                params.delete(:origin)
              end
#    puts "ORIGIN: #{@origin.inspect}."
  end


  get :index do
    @page = (params[:page] || 1).to_i
    if @page <= 0
      redirect url_for(:feed, :index, page: 1)
    else
      # (next_refresh == nil) is a signal that Feed is queued for deletion in background process
      @feeds = Feed.exclude(next_refresh: nil).reverse(:score).paginate(@page, PAGE_SIZE)
      if !@feeds.page_range.cover?(@page)
        redirect url_for(:feed, :index, page: @feeds.page_count)
      else
        @context = 'Feeds'
        @pagination = {page: @page}
        @feed = Feed.new

        render 'index'
      end
    end
  end


  get :show, '/feed/:id' do
    @feed = Feed.with_pk! params[:id]
    page = (params[:page] || 1).to_i
    if page <= 0
      redirect url_for(:feed, :show, id: @feed[:id]), page: 1, origin: @origin
    else
      @posts = Post.unread.where(feed_id: @feed[:id]).reverse(:published_at).paginate(page, PAGE_SIZE)
      if page > @posts.page_count
        redirect url_for(:feed, :show, id: @feed[:id], page: @posts.page_count, origin: @origin)
      else
        @context = @feed.name	# allow URL for new Feeds that haven't refreshed or have no title tag

        @datetime_only = true
        @pagination = {id: params[:id], origin: @origin}
        
        render 'show'
      end
    end
  end
  

  post :create, '/feed' do
    params[:rss_url].strip!
    if !URI.parse(params[:rss_url]).kind_of?(URI::HTTP)
      flash[:error] = "'#{params[:rss_url]}' is not valid."
      redirect @origin
    else
      params.delete('authenticity_token')      # I'm surprised I have to do this.

      params[:next_refresh] = Time.now

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
#        STDERR.puts "Exception in Feed controller: #{$!}."
        Refresh.log "Exception in Feed controller: #{$!}.", :error
        flash[:error] = "Unknown exception: #{e}."
      end

      # Redirect to index where new feed will appear.
      redirect url_for(:feed, :index, page: w.page_number)
    end
  end


  get :edit, with: :id do
    @feed = Feed.with_pk! params[:id]
    url = url_for(:feed, :update, id: @feed[:id])
    partial('feed/form', object: @feed, locals: {url: url, button: button_to('Update', url, method: :put, class: :form)})
  end

  
  put :update, with: :id do
    # I'm surprised I have to do this.
    params.delete('authenticity_token')
    params.delete('_method')

    begin
      %w{use_body log_body log_body_words use_description log_description log_description_words}.each do |flag|
        params[flag] ||= '0'
      end
      puts "PARAMS: #{params.inspect}."
      feed = Feed.load(params).save
    rescue Sequel::UniqueConstraintViolation => e
      flash[:error] = (/unique_(\w+)s'/ =~ e.to_s) ? "Duplicate #{$~[1]}." : 'Unique Constraint Violation'
    rescue
      flash[:error] = 'Unknown exception'
    end
    feed ||= Feed.with_pk! params[:id]

    redirect url(:feed, :index, page: feed.page_number)
  end


  delete :destroy, with: :id do
    feed = Feed[params[:id]]
    if feed
      feed[:next_refresh] = nil
      feed.save(changed: true)
      Resque.enqueue_to('Initial', Refresh, -feed[:id])
      flash[:success] = 'Delete queued'

      redirect url(@origin)
    else
      flash[:warning] = pat(:delete_warning, :model => 'feed', :id => "#{params[:id]}")
      halt 404
    end
  end
end
