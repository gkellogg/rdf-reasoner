source "http://rubygems.org"

gemspec

gem 'rdf', git: "git://github.com/ruby-rdf/rdf.git", :branch => "develop"
gem 'rdf-vocab', git: "git://github.com/ruby-rdf/rdf-vocab.git", :branch => "develop"

group :development, :test do
  gem 'rake'
  gem 'simplecov', require: false
  gem 'ruby-prof', :platforms => :mri
  gem 'rdf-turtle', git: "git://github.com/ruby-rdf/rdf-turtle.git", :branch => "develop"
end

group :debug do
  gem "wirble"
  gem "redcarpet", platforms: :ruby
  gem "byebug", platforms: :mri_21
end

platforms :rbx do
  gem 'rubysl', '~> 2.0'
  gem 'rubinius', '~> 2.0'
end
