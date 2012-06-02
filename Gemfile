source :rubygems

gem 'eventmachine', '~>1.0.0.beta.4'
gem 'redis', "~> 3.0.0.rc1"

group :development, :test do
  gem 'mocha'
  gem 'rake'
end

group :production do
  if defined?(JRUBY_VERSION)
    gem 'json-jruby', '~> 1.7.3'
  end
end
