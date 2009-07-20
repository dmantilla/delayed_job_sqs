#version = File.read('README.textile').scan(/^\*\s+([\d\.]+)/).flatten

Gem::Specification.new do |s|
  s.name     = "delayed_job_sqs"
  s.version  = "0.1.2"
  s.date     = "2009-07-17"
  s.summary  = "Asynchronous queue execution using Amazon SQS -- Most of the code was extracted from the delayed_job gem"
  s.email    = "daniel@celect.org"
  s.homepage = "http://github.com/dmantilla/delayed_job_sqs/tree/master"
  s.description = "delayed_job_sqs reuses most of the code from the delayed_job gem by Tobias Lütke. ActiveRecord was replaced by Amazon Simple Queue and other minor changes"
  s.authors  = ["Daniel Mantilla"]

  s.has_rdoc = false
  s.rdoc_options = ["--main", "README.textile"]
  s.extra_rdoc_files = ["README.textile"]

  # run git ls-files to get an updated list
  s.files = %w[
    MIT-LICENSE
    README.textile
    delayed_job_sqs.gemspec
    init.rb
    lib/delayed/job.rb
    lib/delayed/message_sending.rb
    lib/delayed/performable_method.rb
    lib/delayed_job.rb
  ]
end
