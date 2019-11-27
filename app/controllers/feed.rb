require 'resque'


Amethyst::App.controllers :feed do
  get :index do
    @page = (params[:page] || 1).to_i
    @feeds = Feed.order(Sequel.desc(:score)).paginate(@page, PAGE_SIZE)
    render 'index'
  end


  get :show, '/feed/:id' do
    @origin = get_origin!
    
    @feed = Feed.with_pk! params[:id]
    @button = button_to 'Create', @url
    render 'show'
  end
  

  post :create, '/feed' do
    # I'm surprised I have to do this.
    params.delete('authenticity_token')

    # if no genre specified, use N/A.
    params[:genre] = Feed::GENRE.find_index(params[:genre]) || 0
    params[:notes].strip!

    # use NULL if filename is empty or blank
    params[:filename].strip!
    params.delete(:filename) if params[:filename] == ''

    begin
      w = Feed.create(params)
    rescue Sequel::UniqueConstraintViolation => e
      flash[:error] = (/unique_(\w+)s'/ =~ e.to_s) ? "Duplicate #{$~[1]}." : 'Unique Constraint Violation'
      case $~[1]
      when 'title'
        w = Feed.where(title: params[:title]).first
      when 'filename'
        w = Feed.where(filename: params[:filename]).first
      else
        w = Feed.first
      end
    rescue Exception => e
      flash[:error] = "Unknown exception: #{e}."
      w = Feed.first
    end

    # Redirect to index where new feed will appear.
    redirect url_for(:feed, :index, page: w.page_number)
  end
end
