class Post < Sequel::Model
  many_to_one :feed

  def name
    (!title.nil? && !title.empty?) ? title : SafeBuffer.new("<b><em>Post #{id}</em></b>")
  end
end
