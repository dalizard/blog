class Article
  include Mongoid::Document
  include Mongoid::Slug

  field :title
  field :published_at, :type => Date
  field :body

  slug :title
end
