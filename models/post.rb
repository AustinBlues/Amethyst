class Post < Sequel::Model
  many_to_one :feed
end
