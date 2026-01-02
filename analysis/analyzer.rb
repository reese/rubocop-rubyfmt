# frozen_string_literal: true

require "json"
require "yaml"
require "fileutils"
require "open3"
require "net/http"
require "uri"

module RubyfmtAnalysis
  class Analyzer
    WORK_DIR = File.expand_path("tmp", __dir__)
    REPOS_DIR = File.join(WORK_DIR, "repos")
    RESULTS_DIR = File.join(WORK_DIR, "results")

    def initialize(corpus_path = File.expand_path("corpus.yml", __dir__))
      @config = YAML.load_file(corpus_path)
      @repos = @config["repos"]
      @rubyfmt_config = @config["rubyfmt"]
    end

    def run
      setup_directories
      ensure_rubyfmt_binary

      results = @repos.map do |repo|
        puts("\n#{'=' * 60}")
        puts("Analyzing: #{repo['name']}")
        puts("=" * 60)
        analyze_repo(repo)
      end

      report = generate_report(results)
      save_results(report)
      print_summary(report)

      report
    end

    private

    def setup_directories
      FileUtils.mkdir_p(REPOS_DIR)
      FileUtils.mkdir_p(RESULTS_DIR)
    end

    def ensure_rubyfmt_binary
      @rubyfmt_binary = @rubyfmt_config["binary"]

      if @rubyfmt_binary && File.executable?(@rubyfmt_binary)
        puts("Using rubyfmt binary: #{@rubyfmt_binary}")
        return
      end

      # Check if already downloaded
      version = @rubyfmt_config["version"]
      cached_binary = File.join(WORK_DIR, "rubyfmt-#{version}")

      if File.executable?(cached_binary)
        @rubyfmt_binary = cached_binary
        puts("Using cached rubyfmt #{version}")
        return
      end

      puts("Downloading rubyfmt #{version}...")
      download_rubyfmt(version, cached_binary)
      @rubyfmt_binary = cached_binary
    end

    def download_rubyfmt(version, dest)
      # Detect platform
      platform = case RUBY_PLATFORM
      when /darwin/
        arch = `uname -m`.strip
        arch == "arm64" ? "Darwin-arm64" : "Darwin-x86_64"
      when /linux/
        "Linux"
      else
        raise "Unsupported platform: #{RUBY_PLATFORM}"
      end

      url = "https://github.com/fables-tales/rubyfmt/releases/download/#{version}/rubyfmt-#{version}-#{platform}.tar.gz"
      tarball = "#{dest}.tar.gz"

      # Download
      system("curl", "-L", "-o", tarball, url, exception: true)

      # Extract
      extract_dir = "#{dest}-extract"
      FileUtils.mkdir_p(extract_dir)
      system("tar", "-xzf", tarball, "-C", extract_dir, exception: true)

      # Find and move binary
      binary = Dir.glob("#{extract_dir}/**/rubyfmt*").find { |f| File.executable?(f) }
      raise "Could not find rubyfmt binary in release" unless binary

      FileUtils.mv(binary, dest)
      FileUtils.chmod(0o755, dest)

      # Cleanup
      FileUtils.rm_rf(tarball)
      FileUtils.rm_rf(extract_dir)

      puts("Downloaded rubyfmt to #{dest}")
    end

    def analyze_repo(repo)
      repo_dir = clone_or_update_repo(repo)
      work_copy = prepare_work_copy(repo, repo_dir)

      puts("  Running RuboCop (before rubyfmt)...")
      before = run_rubocop(work_copy, repo["paths"])

      puts("  Running rubyfmt...")
      formatted_files = run_rubyfmt(work_copy, repo["paths"])

      puts("  Running RuboCop (after rubyfmt)...")
      after = run_rubocop(work_copy, repo["paths"])

      diff = diff_violations(before, after)

      {
        repo: repo["name"],
        ref: repo["ref"],
        files_formatted: formatted_files,
        before_total: before.size,
        after_total: after.size,
        diff: diff
      }
    end

    def clone_or_update_repo(repo)
      repo_dir = File.join(REPOS_DIR, repo["name"])

      if Dir.exist?(repo_dir)
        puts("  Using cached repo, checking out #{repo['ref']}...")
        Dir.chdir(repo_dir) do
          system("git", "fetch", "--tags", exception: true)
          system("git", "checkout", repo["ref"], exception: true)
          system("git", "clean", "-fdx", exception: true)
        end
      else
        puts("  Cloning #{repo['url']}...")
        system("git", "clone", "--depth=1", "--branch", repo["ref"], repo["url"], repo_dir, exception: true)
      end

      repo_dir
    end

    def prepare_work_copy(repo, repo_dir)
      # Create a working copy so we don't modify the cached repo
      work_dir = File.join(WORK_DIR, "work", repo["name"])
      FileUtils.rm_rf(work_dir)
      FileUtils.mkdir_p(work_dir)
      FileUtils.cp_r(repo_dir, work_dir)
      # cp_r copies the directory INTO work_dir, so the actual content is nested
      File.join(work_dir, File.basename(repo_dir))
    end

    def run_rubocop(dir, paths)
      target_paths = paths.map { |p| File.join(dir, p) }.select { |p| Dir.exist?(p) }
      return [] if target_paths.empty?

      cmd = [
        "rubocop",
        "--format",
        "json",
        # Ignore repo's .rubocop.yml
        "--force-default-config",
        "--only-recognized-file-types",
        *target_paths
      ]

      stdout, stderr, _status = Open3.capture3(*cmd)

      begin
        result = JSON.parse(stdout)
        parse_violations(result, dir)
      rescue JSON::ParserError => e
        puts("    Warning: RuboCop JSON parse error: #{e.message}")
        puts("    stderr: #{stderr}") unless stderr.empty?
        []
      end
    end

    def parse_violations(rubocop_json, base_dir)
      rubocop_json["files"].flat_map do |file|
        # Normalize path relative to work dir
        relative_path = file["path"].sub("#{base_dir}/", "")

        file["offenses"].map do |offense|
          {
            path: relative_path,
            line: offense["location"]["line"],
            column: offense["location"]["column"],
            cop: offense["cop_name"],
            message: offense["message"],
            severity: offense["severity"]
          }
        end
      end
    end

    def run_rubyfmt(dir, paths)
      formatted = 0

      paths.each do |path|
        full_path = File.join(dir, path)
        next unless Dir.exist?(full_path)

        Dir.glob("#{full_path}/**/*.rb").each do |file|
          _, stderr, status = Open3.capture3(@rubyfmt_binary, "-i", "--prism", file)

          if status.success?
            formatted += 1
          else
            puts("    Warning: rubyfmt failed on #{file}: #{stderr}")
          end
        end
      end

      formatted
    end

    def diff_violations(before, after)
      before_by_cop = before.group_by { |v| v[:cop] }
      after_by_cop = after.group_by { |v| v[:cop] }

      all_cops = (before_by_cop.keys + after_by_cop.keys).uniq.sort

      all_cops.map do |cop|
        before_violations = before_by_cop[cop] || []
        after_violations = after_by_cop[cop] || []

        {
          cop: cop,
          before: before_violations.size,
          after: after_violations.size,
          delta: after_violations.size - before_violations.size,
          # Sample violations for debugging
          sample_new: (after_violations - before_violations).first(3)
        }
      end
    end

    def generate_report(results)
      # Aggregate across all repos
      all_diffs = results.flat_map { |r| r[:diff] }

      aggregated = all_diffs
        .group_by { |d| d[:cop] }
        .transform_values do |entries|
          {
            total_before: entries.sum { |e| e[:before] },
            total_after: entries.sum { |e| e[:after] },
            total_delta: entries.sum { |e| e[:delta] },
            repos_affected: entries.count { |e| e[:delta] != 0 }
          }
        end

      # Categorize
      introduced = aggregated.select { |_, v| v[:total_before].zero? && v[:total_after].positive? }
      increased = aggregated.select { |_, v| v[:total_before].positive? && v[:total_delta].positive? }
      decreased = aggregated.select { |_, v| v[:total_delta].negative? }
      unchanged = aggregated.select { |_, v| v[:total_delta].zero? }

      {
        rubyfmt_version: @rubyfmt_config["version"],
        analyzed_at: Time.now,
        repos: results,
        summary: {
          total_repos: results.size,
          total_files_formatted: results.sum { |r| r[:files_formatted] },
          total_violations_before: results.sum { |r| r[:before_total] },
          total_violations_after: results.sum { |r| r[:after_total] }
        },
        categorized: {
          introduced: introduced.sort_by { |_, v| -v[:total_after] }.to_h,
          increased: increased.sort_by { |_, v| -v[:total_delta] }.to_h,
          decreased: decreased.sort_by { |_, v| v[:total_delta] }.to_h,
          unchanged: unchanged.to_h
        }
      }
    end

    def save_results(report)
      timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
      version = @rubyfmt_config["version"].gsub(/[^a-zA-Z0-9]/, "_")

      json_path = File.join(RESULTS_DIR, "analysis_#{version}_#{timestamp}.json")
      File.write(json_path, JSON.pretty_generate(report))
      puts("\nResults saved to: #{json_path}")

      # Also save a "latest" symlink
      latest_path = File.join(RESULTS_DIR, "latest.json")
      FileUtils.rm_f(latest_path)
      FileUtils.ln_s(File.basename(json_path), latest_path)
    end

    def print_summary(report)
      puts("\n#{'=' * 60}")
      puts("ANALYSIS SUMMARY (rubyfmt #{report[:rubyfmt_version]})")
      puts("=" * 60)

      puts("\nOverview:")
      puts("  Repos analyzed: #{report[:summary][:total_repos]}")
      puts("  Files formatted: #{report[:summary][:total_files_formatted]}")
      puts("  Violations before: #{report[:summary][:total_violations_before]}")
      puts("  Violations after: #{report[:summary][:total_violations_after]}")

      puts("\n" + "-" * 60)
      puts("INTRODUCED by rubyfmt (candidates for always-disable):")
      puts("-" * 60)
      report[:categorized][:introduced].first(15).each do |cop, data|
        puts(format("  %-45s +%-6d (0 → %d)", cop, data[:total_after], data[:total_after]))
      end

      puts("\n" + "-" * 60)
      puts("INCREASED by rubyfmt (candidates for recommended-disable):")
      puts("-" * 60)
      report[:categorized][:increased].first(15).each do |cop, data|
        puts(format("  %-45s +%-6d (%d → %d)", cop, data[:total_delta], data[:total_before], data[:total_after]))
      end

      puts("\n" + "-" * 60)
      puts("DECREASED by rubyfmt (no action needed):")
      puts("-" * 60)
      report[:categorized][:decreased].first(10).each do |cop, data|
        puts(format("  %-45s %-6d (%d → %d)", cop, data[:total_delta], data[:total_before], data[:total_after]))
      end
    end
  end
end
