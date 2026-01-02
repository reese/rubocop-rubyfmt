# frozen_string_literal: true

require "rubocop/rake_task"

require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

task(default: %i[spec rubocop])

namespace(:analysis) do
  desc("Run full corpus analysis to determine rubyfmt/rubocop rule conflicts")
  task(:run) do
    require_relative "analysis/run"
    RubyfmtAnalysis.run
  end

  desc("Generate config files from the latest analysis results")
  task(:generate_configs) do
    require_relative "analysis/run"
    RubyfmtAnalysis.generate_configs
  end

  desc("Run full analysis and generate configs")
  task(full: %i[run generate_configs])

  desc("Clean analysis working directory")
  task(:clean) do
    require "fileutils"

    work_dir = File.expand_path("analysis/tmp", __dir__)
    if Dir.exist?(work_dir)
      puts("Removing #{work_dir}...")
      FileUtils.rm_rf(work_dir)
    end
  end

  desc("Clean analysis repos only (keep results)")
  task(:clean_repos) do
    require "fileutils"

    repos_dir = File.expand_path("analysis/tmp/repos", __dir__)
    work_dir = File.expand_path("analysis/tmp/work", __dir__)
    [repos_dir, work_dir].each do |dir|
      if Dir.exist?(dir)
        puts("Removing #{dir}...")
        FileUtils.rm_rf(dir)
      end
    end
  end
end

desc("Run corpus analysis (alias for analysis:run)")
task(analysis: "analysis:run")
