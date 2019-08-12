Amethyst::App.controllers :post do
  get :index do
    STDERR.puts "PARAMS: #{params.inspect}."
    @posts = Post.order(Sequel.desc(:published_at)).all
    render 'index'
  end
end
