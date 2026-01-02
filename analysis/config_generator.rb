# frozen_string_literal: true

require "json"
require "yaml"

module RubyfmtAnalysis
  class ConfigGenerator
    # Any introduction counts
    INTRODUCED_THRESHOLD = 0
    # Need significant increase to recommend disabling
    INCREASED_THRESHOLD = 5

    def initialize(results_path)
      @results = JSON.parse(File.read(results_path), symbolize_names: true)
    end

    def generate_configs(output_dir)
      FileUtils.mkdir_p(output_dir)

      generate_always_disabled(output_dir)
      generate_recommended_disabled(output_dir)
      generate_full_report(output_dir)

      puts("Generated configs in #{output_dir}")
    end

    private

    def generate_always_disabled(output_dir)
      introduced = @results[:categorized][:introduced]

      config = {
        "# rubyfmt always-disable rules" => nil,
        "# These rules conflict with rubyfmt's formatting decisions." => nil,
        "# Generated from analysis of #{@results[:summary][:total_repos]} repos" => nil,
        "# rubyfmt version: #{@results[:rubyfmt_version]}" => nil,
        "# Generated: #{@results[:analyzed_at]}" => nil
      }

      introduced.each do |cop, data|
        config[cop] = {
          "Enabled" => false,
          "# Reason" => "Introduced by rubyfmt (0 → #{data[:total_after]} violations)"
        }
      end

      # Clean up the comment keys and format properly
      yaml_content = build_yaml_with_comments(introduced, "always")
      File.write(File.join(output_dir, "rubyfmt_always_disabled.yml"), yaml_content)
    end

    def generate_recommended_disabled(output_dir)
      increased = @results[:categorized][:increased].select { |_, data| data[:total_delta] >= INCREASED_THRESHOLD }

      yaml_content = build_yaml_with_comments(increased, "recommended")
      File.write(File.join(output_dir, "rubyfmt_recommended_disabled.yml"), yaml_content)
    end

    def build_yaml_with_comments(cops, type)
      lines = []
      lines << "# rubyfmt #{type}-disable rules"
      lines << "#"
      lines << "# Generated from analysis of #{@results[:summary][:total_repos]} repos"
      lines << "# rubyfmt version: #{@results[:rubyfmt_version]}"
      lines << "# Generated: #{@results[:analyzed_at]}"
      lines << ""

      if type == "always"
        lines << "# These rules conflict with rubyfmt's formatting decisions."
        lines << "# They should always be disabled when using rubyfmt."
      else
        lines << "# These rules see increased violations after rubyfmt formatting."
        lines << "# Consider disabling them, or address the underlying code issues."
        lines << "# Uncomment rules you want to re-enable for gradual cleanup."
      end

      lines << ""

      cops.each do |cop, data|
        if type == "always"
          lines << "# #{cop}: 0 → #{data[:total_after]} violations across #{data[:repos_affected]} repos"
        else
          lines <<
            "# #{cop}: #{data[:total_before]} → #{data[:total_after]} (+#{data[:total_delta]}) across #{data[:repos_affected]} repos"
        end

        lines << "#{cop}:"
        lines << "  Enabled: false"
        lines << ""
      end

      lines.join("\n")
    end

    def generate_full_report(output_dir)
      report_lines = []
      report_lines << "# rubyfmt RuboCop Compatibility Analysis"
      report_lines << ""
      report_lines << "## Summary"
      report_lines << ""
      report_lines << "- **rubyfmt version**: #{@results[:rubyfmt_version]}"
      report_lines << "- **Analyzed**: #{@results[:analyzed_at]}"
      report_lines << "- **Repos**: #{@results[:summary][:total_repos]}"
      report_lines << "- **Files formatted**: #{@results[:summary][:total_files_formatted]}"
      report_lines << "- **Violations before**: #{@results[:summary][:total_violations_before]}"
      report_lines << "- **Violations after**: #{@results[:summary][:total_violations_after]}"
      report_lines << ""

      report_lines << "## Rules INTRODUCED by rubyfmt"
      report_lines << ""
      report_lines << "These rules had zero violations before formatting but have violations after."
      report_lines << "**Recommendation**: Always disable these when using rubyfmt."
      report_lines << ""
      report_lines << "| Rule | After | Repos |"
      report_lines << "|------|-------|-------|"
      @results[:categorized][:introduced].each do |cop, data|
        report_lines << "| `#{cop}` | #{data[:total_after]} | #{data[:repos_affected]} |"
      end

      report_lines << ""

      report_lines << "## Rules INCREASED by rubyfmt"
      report_lines << ""
      report_lines << "These rules had some violations before, but more after formatting."
      report_lines << "**Recommendation**: Consider disabling, or clean up the underlying issues."
      report_lines << ""
      report_lines << "| Rule | Before | After | Delta | Repos |"
      report_lines << "|------|--------|-------|-------|-------|"
      @results[:categorized][:increased].each do |cop, data|
        report_lines <<
          "| `#{cop}` | #{data[:total_before]} | #{data[:total_after]} | +#{data[:total_delta]} | #{data[:repos_affected]} |"
      end

      report_lines << ""

      report_lines << "## Rules DECREASED by rubyfmt"
      report_lines << ""
      report_lines << "These rules have fewer violations after formatting."
      report_lines << "**Recommendation**: No action needed."
      report_lines << ""
      report_lines << "| Rule | Before | After | Delta |"
      report_lines << "|------|--------|-------|-------|"
      @results[:categorized][:decreased].each do |cop, data|
        report_lines << "| `#{cop}` | #{data[:total_before]} | #{data[:total_after]} | #{data[:total_delta]} |"
      end

      report_lines << ""

      report_lines << "## Per-Repo Details"
      report_lines << ""
      @results[:repos].each do |repo|
        report_lines << "### #{repo[:repo]} (#{repo[:ref]})"
        report_lines << ""
        report_lines << "- Files formatted: #{repo[:files_formatted]}"
        report_lines << "- Violations: #{repo[:before_total]} → #{repo[:after_total]}"
        report_lines << ""
      end

      File.write(File.join(output_dir, "ANALYSIS_REPORT.md"), report_lines.join("\n"))
    end
  end
end
