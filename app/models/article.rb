class Article
  include Mongoid::Document

  field :title
  field :published_at, :type => Date
  field :body

end
