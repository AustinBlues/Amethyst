require 'benchmark'

Amethyst::App.controllers :post do
  before do
    @origin = if [:index].include?(request.action)
                request.fullpath
              else
                params.delete(:origin)
              end
#    puts("ORIGIN: #{@origin}.") if Padrino.env != :test
  end

  
  get :index do
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
        @back_title = 'to Feeds'
        @back_url = '/feed'

        render 'index'
      end
    end
  end


  get :search do
    @back_url = @origin
    @page = (params[:page] || 1).to_i
    @controller = :post
    @action = :search
    @context = "Search: '#{params[:search]}'"
    @options = {page: @page, search: params[:search], origin: @origin}
    @back_title = case @origin
                  when /^\/post\/search/
                    'to Search'
                  when /^\/post/
                    'to Posts'
                  when /^\/feed/
                    'to Feeds'
                  else
                    flash[:error] = 'Unknown origin'
                    STDERR.puts "UNKNOWN ORIGIN: #{params[:origin]}."
                    'UNKNOWN'
                  end
    @datetime_only = false
    ds = Post.dataset.full_text_search([:title, :description], params[:search]).order(:state)
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
      @words = @post.word_cloud(0.5).sort{|a, b| b[:count]/b[:frequency] <=> a[:count]/a[:frequency]}
      word_id = @post.word.select{|w| w[:frequency] > 1.0 && w[:flags] == 0}.map(&:id)
#      # The statement below is slower!  Surprised!
#      word_id = Word.where{frequency > 1.0}.where(flags: 0).map(:id)
#      puts "RELATED: #{Post.join(:occurrences, word_id: word_id, post_id: :id).where(state: Post::UNREAD).group(:id).count}."
      relatedness = Hash.new(0)
      Occurrence.where(word_id: word_id).join(:words, id: :word_id).each do |w|
        relatedness[w[:post_id]] += w[:count]/w[:frequency]
#        puts("STRENGTH: #{relatedness[w[:post_id]]}, #{w[:count]}/#{w[:frequency]}.") if w[:post_id] == 29583
      end
      related_posts = Post.where(id: relatedness.keys, state: Post::UNREAD).all
      related_posts.each do |t|
        t[:strength] = (100 * relatedness[t[:id]]).to_i	# 100 to move into human range
        # Words In Common, intersection of Post's words and Posts with those same words
        t[:wic] = t.word_cloud.delete_if{|w| !word_id.include?(w[:id])}
        t[:wic].sort!{|a, b| b[:count]/b[:frequency] <=> a[:count]/a[:frequency]}.map do |w|
          {name: w[:name], count: w[:count], frequency: w[:frequency]}
        end
      end
#      puts "RELATED_POSTS: #{related_posts.inspect}."
      related_posts.delete_if{|t| t[:wic].size < WIC_MIN}	# must have at least WIC_MIN Words In Common
      related_posts.sort!{|a, b| b[:strength] <=> a[:strength]}
#      puts "STRENGTH: #{relatedness.inspect}."
#      puts "RELATED_POSTS: #{related_posts.first(RELATED_POSTS_MAX).map{|t| t[:strength]}}."
      @related = related_posts.first(RELATED_POSTS_MAX)
    end
#    puts "RELATED_POSTS_MAX(#{@related.size}): #{RELATED_POSTS_MAX}; DISPLAY_WORDS: #{DISPLAY_WORDS}."

    render 'show'
  end
  

#  put :hide, '/post/:id/hide' do
  get :hide, '/post/:id/hide' do
    post = Post.with_pk! params[:id]
    post.hide!
    post.save(changed: true)

    redirect @origin
  end

  
#  put :down, '/post/:id/down' do
  get :down, '/post/:id/down' do
    post = Post.with_pk! params[:id]
    post.down_vote!
    post.save(changed: true)

    redirect @origin
  end

  
#  put :unclick, '/post/:id/unclick' do
  get :unclick, '/post/:id/unclick' do
    post = Post.with_pk! params[:id]
    post.unclick!
    post.save

    redirect @origin
  end
end
