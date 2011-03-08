class Article
  include Mongoid::Document
  include Mongoid::Slug

  field :title
  field :published_at, :type => Date
  field :articleid, :type => Integer, :default => 1
  field :body

  slug :title
  
end
