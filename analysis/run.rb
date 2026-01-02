#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "analyzer"
require_relative "config_generator"

module RubyfmtAnalysis
  def self.run(corpus_path: nil)
    corpus_path ||= File.expand_path("corpus.yml", __dir__)
    analyzer = Analyzer.new(corpus_path)
    analyzer.run
  end

  def self.generate_configs(results_path: nil, output_dir: nil)
    results_path ||= File.join(Analyzer::RESULTS_DIR, "latest.json")
    output_dir ||= File.join(Analyzer::RESULTS_DIR, "generated")

    generator = ConfigGenerator.new(results_path)
    generator.generate_configs(output_dir)
  end
end

if __FILE__ == $PROGRAM_NAME
  case ARGV[0]
  when "analyze"
    RubyfmtAnalysis.run
  when "generate"
    RubyfmtAnalysis.generate_configs
  when "full"
    RubyfmtAnalysis.run
    RubyfmtAnalysis.generate_configs
  else
    puts("Usage: ruby run.rb [analyze|generate|full]")
    puts("")
    puts("  analyze  - Run analysis on corpus repos")
    puts("  generate - Generate config files from latest results")
    puts("  full     - Run analysis and generate configs")
    exit(1)
  end
end
