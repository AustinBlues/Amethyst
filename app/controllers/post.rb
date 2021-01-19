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
    @datetime_only = true
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
    @words = @post.word_cloud(0.5).sort{|a, b| b[:count]/b[:frequency] <=> a[:count]/a[:frequency]}
    tmp = @post.word.select{|w| w[:frequency] > 1.0 && w[:flags] == 0}.map(&:id)
    puts "RELATED: #{Post.join(:occurrences, word_id: tmp, post_id: :id).where(state: Post::UNREAD).group(:id).count}."
    word = Occurrence.where(word_id: tmp).join(:words, id: :word_id).all
    tmp2 = {}
    word.each do |w|
      puts "W: #{w.inspect}."
      if tmp2[w[:post_id]].nil?
        tmp2[w[:post_id]] = w[:count]/w[:frequency]
      else
        tmp2[w[:post_id]] += w[:count]/w[:frequency]
      end
    end
    strength = tmp2.map{|key, value| {post_id: key, strength: value}}
    strength.sort!{|a, b| b[:strength] <=> a[:strength]}
    puts "STRENGTH: #{strength.first(5).inspect}."
    tmp = Post.where(id: strength.map{|p| p[:post_id]}, state: Post::UNREAD).all
    tmp.each_with_index do |t, i|
      t[:strength] = strength[i][:strength]
    end
    @related = tmp.first(3)
    
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
