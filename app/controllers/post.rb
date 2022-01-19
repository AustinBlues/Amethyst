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
        titles = Post.unread.where(Sequel.lit('published_at < ?', midnight)).map{|p| p[:title]}
#        @posts = Post.where(title: tmp.map{|p| p[:title]}).order(:title).paginate(@page, PAGE_SIZE)
        tmp = Post.select(Sequel[:posts][:id], Sequel[:posts][:title], :description, :feed_id, :published_at, :state)
        tmp = tmp.where(Sequel[:posts][:title] => titles).join(:feeds, id: :feed_id)
        @posts = tmp.order(Sequel[:posts][:title], Sequel.desc(Sequel[:feeds][:score])).paginate(@page, PAGE_SIZE)
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
                    Refresh.log "UNKNOWN ORIGIN: #{params[:origin]}.", :error
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
    @post = Post.with_pk! params[:id]
    @post.click!
    @post.save(changed: true)

    if RELATED_POSTS_MAX <= 0
      @related = []
    else
      @words = @post.word_cloud.sort{|a, b| b[:count]/b[:frequency] <=> a[:count]/a[:frequency]}
      word_id = @post.word.map(&:id)

      word_strength = Hash.new
      @words.each{|w| word_strength[w[:word_id]] = w[:count]/w[:frequency]}

      relatedness = Hash.new(0)
      Occurrence.where(word_id: word_id).join(:words, id: :word_id).
            exclude(post_id: @post[:id]).where(flags: 0).each do |w|
        relatedness[w[:post_id]] += w[:count]/w[:frequency] + word_strength[w[:word_id]]
      end

      if true
        related_posts = Post.where(id: relatedness.keys, state: Post::UNREAD).order(:id).all
        ids = related_posts.map{|p| p[:id]}
        tmp = Word.join(:occurrences, post_id: ids, word_id: :id).where(flags: 0).where{frequency > 1.0}.
                order(:post_id).all
        related_posts.each do |rp|
          rp[:strength] = (100 * relatedness[rp[:id]]).to_i	# 100 to move into human range
          rp[:wic] = []
        end
        rp = 0
        tmp.each do |t|
          while related_posts[rp][:id] != t[:post_id] do
            rp += 1
          end
          # Words In Common, intersection of Post's words and Posts with those same words
          if word_id.include?(t[:id])
            related_posts[rp][:wic] << t
          end
        end
        related_posts.each do |rp|
          rp[:wic].sort!{|a, b| b[:count]/b[:frequency] <=> a[:count]/a[:frequency]}
          rp[:max] = rp[:wic].first[:count]/rp[:wic].first[:frequency]
          rp[:avg] = rp[:wic].sum{|w| w[:count]/w[:frequency]} / rp[:wic].size
          rp[:min] = rp[:wic].last[:count]/rp[:wic].last[:frequency]
          rp[:size] = rp[:wic].size
          rp[:cull_score] = 0.0
          rp[:cull_size] = 0
          limit = 0.5 * rp[:avg]
          rp[:wic].reverse_each do |word|
            score = word[:count]/word[:frequency]
            if score + rp[:cull_score] <= limit
              rp[:cull_score] += score
              rp[:cull_size] += 1
            end
          end
        end
      end

      related_posts.delete_if{|t| t[:wic].size < WIC_MIN}	# must have at least WIC_MIN Words In Common
      related_posts.sort!{|a, b| b[:strength] <=> a[:strength]}

      @related = related_posts.first(RELATED_POSTS_MAX)
    end

    render 'show'
  end


#  put :hide, '/post/:id/hide' do
  get :hide, '/post/:id/hide' do
    post = Post.with_pk! params.delete('id')
    post.hide!
    post.save(changed: true)

    if !params[:search].nil?
      params[:origin] = @origin
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
    post.save(changed: true)

    redirect @origin
  end
end
