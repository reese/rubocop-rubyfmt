# rubyfmt/RuboCop Compatibility Analysis

This directory contains tooling to analyze which RuboCop rules conflict with rubyfmt's formatting decisions.

## How It Works

1. Clones a corpus of large Ruby repos (pinned to specific versions)
2. Runs RuboCop on the original code
3. Formats the code with rubyfmt
4. Runs RuboCop again on the formatted code
5. Diffs the violations to categorize rules

## Categories

Rules are categorized based on how they change after rubyfmt formatting:

- **Introduced**: Zero violations before, some after → Always disable
- **Increased**: Some violations before, more after → Consider disabling
- **Decreased**: Fewer violations after → rubyfmt "fixes" these
- **Unchanged**: Same count before/after → Orthogonal to formatting

## Usage

### Run the Full Analysis

```bash
# From repo root
bundle exec rake analysis:full

# Or just the analysis step
bundle exec rake analysis:run

# Or just generate configs from existing results
bundle exec rake analysis:generate_configs
```

### Compare Versions

To compare results between rubyfmt versions:

```bash
ruby analysis/compare_versions.rb \
  analysis/tmp/results/analysis_v0_9_0_*.json \
  analysis/tmp/results/analysis_v0_10_0_*.json
```

## Configuration

Edit `corpus.yml` to:

- Change the rubyfmt version being tested
- Add/remove repos from the corpus
- Adjust which paths are analyzed in each repo

## Output

Results are saved to `tmp/results/` as timestamped JSON files.

Generated configs are written to `../rubocop/generated/`:

- `rubyfmt_always_disabled.yml` - Rules to always disable
- `rubyfmt_recommended_disabled.yml` - Rules to consider disabling
- `ANALYSIS_REPORT.md` - Full markdown report

## Cleaning Up

```bash
# Remove everything (repos, working copies, results)
bundle exec rake analysis:clean

# Keep results, remove repos and working copies
bundle exec rake analysis:clean_repos
```

## Adding to CI

For tracking regressions across rubyfmt versions, you could add a workflow that:

1. Runs analysis on PR branches that bump rubyfmt version
2. Compares results with main branch
3. Comments on PR with any new rule conflicts

See `.github/workflows/` for examples (TODO).
