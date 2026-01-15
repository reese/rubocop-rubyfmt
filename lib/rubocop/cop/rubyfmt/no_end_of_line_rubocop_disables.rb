# frozen_string_literal: true

require "rubocop"

module RuboCop
  module Cop
    module Rubyfmt

      # `rubyfmt` always places comments at the beginning of lines, so end-of-line
      # disables cannot be used. The autocorrect for this lint
      #
      # @safety
      #   This cop should only be moving comments and thus should be safe.
      #   However, this is largely intended as a migration mechanism when first
      #   adopting rubyfmt, so this is best-effort and may require some manual fixups.
      #   That said, since it's moving comments only, those fixups should be pretty much entirely
      #   caught by Rubocop, and most of the fixups should just be moving comments such that they
      #   appropriately wrap the offending code.
      #
      #
      # rubocop:disable Lint/RedundantCopDisableDirective
      # ```ruby
      # # good
      # # rubocop:disable Style/ExampleCop
      # bad_call!
      # # rubocop:enable Style/ExampleCop
      #
      # # bad
      # bad_call! # rubocop:disable Style/ExampleCop
      # ````
      # rubocop:enable Lint/RedundantCopDisableDirective
      #
      class NoEndOfLineRubocopDisables < Base
        extend AutoCorrector

        MSG = "Use multiline rubocop directives instead of end-of-line comments."
        DISABLE_PATTERN = /# rubocop:(disable|todo) .*/.freeze

        def on_new_investigation
          processed_source.comments.each do |comment|
            next unless same_line_directive?(comment)

            register_offense(comment)
          end
        end

        private def same_line_directive?(comment)
          comment.text.match?(DISABLE_PATTERN) && !comment_only_line?(comment)
        end

        private def comment_only_line?(comment)
          processed_source.lines[comment.loc.line - 1].strip == comment.text
        end

        private def register_offense(comment)
          add_offense(comment) do |corrector|
            autocorrect(corrector, comment)
          end
        end

        private def autocorrect(corrector, comment)
          line_number = comment.source_range.line
          line = processed_source.lines[line_number - 1]

          # Extract the disable directive
          disable_text = comment.text.match(DISABLE_PATTERN)[0]

          # Find the position where the whitespace before the comment starts
          line_without_comment = line.sub(/#.*$/, "")
          whitespace_before_comment_length = line_without_comment.length - line_without_comment.rstrip.length

          # Create a range that includes the whitespace before the comment
          comment_with_leading_space_range = if whitespace_before_comment_length.positive?
            range_with_leading_space = Parser::Source::Range.new(
              comment.source_range.source_buffer,
              comment.source_range.begin_pos - whitespace_before_comment_length,
              comment.source_range.end_pos
            )
            range_with_leading_space
          else
            comment.source_range
          end

          # Remove the end-of-line comment with its leading whitespace
          corrector.remove(comment_with_leading_space_range)

          # Add the disable directive on the line before
          indent = line[/\A\s*/]
          beginning_of_line = processed_source.buffer.line_range(line_number)
          corrector.insert_before(
            beginning_of_line,
            "#{indent}#{disable_text}\n"
          )

          # Add the enable directive on the line after
          enable_text = disable_text.gsub("disable", "enable")
          end_of_line = processed_source.buffer.line_range(line_number)
          corrector.insert_after(
            end_of_line,
            "\n#{indent}#{enable_text}"
          )
        end
      end
    end
  end
end
