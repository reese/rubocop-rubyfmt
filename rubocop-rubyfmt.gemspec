# frozen_string_literal: true

require_relative "lib/rubocop/rubyfmt/version"

Gem::Specification.new do |spec|
  spec.name = "rubocop-rubyfmt"
  spec.version = RuboCop::Rubyfmt::VERSION
  spec.authors = ["Reese Williams"]
  spec.email = ["reese@reesew.com"]

  spec.summary = "Rubocop rules for adopting `rubyfmt`"
  spec.description = spec.summary
  spec.homepage = "https://github.com/reese/rubocop-rubyfmt"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/tree/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github Gemfile])
    end
  end

  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.metadata["rubygems_mfa_required"] = "true"
  spec.metadata["default_lint_roller_plugin"] = "RuboCop::Rubyfmt::Plugin"

  spec.add_dependency("lint_roller", "~> 1.1")
  spec.add_dependency("rubocop", ">= 1.72.2")
end
