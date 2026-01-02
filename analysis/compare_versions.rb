# frozen_string_literal: true

require "json"

module RubyfmtAnalysis
  class VersionComparer
    def initialize(results_a_path, results_b_path)
      @results_a = JSON.parse(File.read(results_a_path), symbolize_names: true)
      @results_b = JSON.parse(File.read(results_b_path), symbolize_names: true)
    end

    def compare
      version_a = @results_a[:rubyfmt_version]
      version_b = @results_b[:rubyfmt_version]

      puts("Comparing rubyfmt #{version_a} vs #{version_b}")
      puts("=" * 60)

      compare_introduced
      compare_rule_changes
    end

    private

    def compare_introduced
      introduced_a = Set.new(@results_a[:categorized][:introduced].keys)
      introduced_b = Set.new(@results_b[:categorized][:introduced].keys)

      new_in_b = introduced_b - introduced_a
      fixed_in_b = introduced_a - introduced_b

      if new_in_b.any?
        puts("\nRules newly introduced in #{@results_b[:rubyfmt_version]}:")
        new_in_b.each do |cop|
          data = @results_b[:categorized][:introduced][cop]
          puts("  + #{cop} (#{data[:total_after]} violations)")
        end
      end

      if fixed_in_b.any?
        puts("\nRules no longer introduced in #{@results_b[:rubyfmt_version]}:")
        fixed_in_b.each do |cop|
          puts("  - #{cop}")
        end
      end

      if new_in_b.empty? && fixed_in_b.empty?
        puts("\nNo change in introduced rules between versions.")
      end
    end

    def compare_rule_changes
      all_cops = (@results_a[:categorized].values.flat_map(&:keys) +
        @results_b[:categorized].values.flat_map(&:keys))
        .uniq

      significant_changes = []

      all_cops.each do |cop|
        delta_a = find_delta(@results_a, cop)
        delta_b = find_delta(@results_b, cop)

        diff = delta_b - delta_a
        # Only show significant changes
        next if diff.abs < 5

        significant_changes <<
          {
            cop: cop,
            delta_a: delta_a,
            delta_b: delta_b,
            diff: diff
          }
      end

      return if significant_changes.empty?

      puts("\nSignificant changes in violation deltas:")
      puts("  (negative = improvement, positive = regression)")
      puts("")

      significant_changes.sort_by { |c| c[:diff] }.each do |change|
        direction = change[:diff] < 0 ? "↓" : "↑"
        puts(
          "  #{direction} #{change[:cop]}: #{change[:delta_a]} → #{change[:delta_b]} (#{format_diff(change[:diff])})"
        )
      end
    end

    def find_delta(results, cop)
      [:introduced, :increased, :decreased, :unchanged].each do |category|
        if results[:categorized][category].key?(cop)
          return results[:categorized][category][cop][:total_delta]
        end
      end

      0
    end

    def format_diff(diff)
      n >= 0 ? "+#{diff}" : diff.to_s
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  if ARGV.size != 2
    puts("Usage: ruby compare_versions.rb <results_a.json> <results_b.json>")
    exit(1)
  end

  comparer = RubyfmtAnalysis::VersionComparer.new(ARGV[0], ARGV[1])
  comparer.compare
end
