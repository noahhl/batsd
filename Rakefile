require 'rake/testtask'
require 'yard'
Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['test/**/*_test.rb']
  t.verbose = true
end

task :default => :test

YARD::Rake::YardocTask.new do |t|
  t.files   = ['lib/**/*.rb', "-", "examples/**/*.rb", "doc/persistence.md",  "doc/datatypes.md", "doc/performance.md", "doc/future.md", "doc/why-not.md"] 
end
