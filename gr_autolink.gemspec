# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "gr_autolink/version"

Gem::Specification.new do |s|
  s.name        = "gr_autolink"
  s.version     = GrAutolink::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Aaron Patterson', 'Juanjo Bazan', 'Akira Matsuda', 'Brian Percival', 'Jonathan Schatz']
  s.email       = ['aaron@tenderlovemaking.com', 'jjbazan@gmail.com', 'bpercival@goodreads.com', 'jon@divisionbyzero.com']
  s.homepage    = "https://github.com/goodreads/gr_autolink"
  s.summary     = %{Forked version of rails_autolink with new functionality}
  s.description = <<-EOF
This is an adaptation of the extraction of the `auto_link` method from rails
that is the rails_autolink gem.  The `auto_link`
method was removed from Rails in version Rails 3.1.  This gem is meant to
bridge the gap for people migrating...and behaves a little differently from the
parent gem we forked from:

* performs html-escaping of characters such as '&' in strings that are getting
  linkified if the incoming string is not html_safe?
* retains html-safety of incoming string (if input string is unsafe, will return
  unsafe and vice versa)
* fixes at least one bug:
  (<img src="http://some.u.rl"> => <img src="<a href="http://some.u.rl">http://some.u.rl</a>">)
  though can't imagine this is intended behavior, also have trouble believing that
  this was an open bug in rails...
EOF
  s.rubyforge_project = "gr_autolink"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_runtime_dependency "rails", '~> 3.1'
  s.add_development_dependency "arel"
  s.add_development_dependency "rack"
  s.add_development_dependency "minitest"
end
