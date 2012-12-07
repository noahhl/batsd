source :rubygems

gem 'eventmachine', '~>1.0.0.rc.4'
gem 'redis', "~> 3.0.2"
if RUBY_PLATFORM == 'java'
  gem 'json-jruby'
else
  gem 'json'
end
gem 'terminal-table'
group :development, :test do
  gem 'yard'
  gem 'mocha'
  gem 'rake'
end
