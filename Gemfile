source 'https://rubygems.org'

gem 'eventmachine', '~>1.0.0.rc.4'
gem 'redis', "~> 3.0.2"
gem 'aws-s3', "~> 0.6.3"

if RUBY_PLATFORM == 'java'
  gem 'json-jruby'
else
  gem 'json'
end

group :development, :test do
  gem 'yard'
  gem 'mocha'
  gem 'rake'
end
