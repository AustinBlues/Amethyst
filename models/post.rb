class Post < Sequel::Model
  many_to_one :feed

  def name
    !title.empty? ? title : "<b><em>Post #{id}</em></b>"
  end
end
