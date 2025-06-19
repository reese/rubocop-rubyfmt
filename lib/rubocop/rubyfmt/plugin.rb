# frozen_string_literal: true

require "lint_roller"

module RuboCop
  module Rubyfmt
    # A plugin that integrates rubocop-rubyfmt with RuboCop's plugin system.
    class Plugin < LintRoller::Plugin
      def about
        LintRoller::About.new(
          name: "rubocop-rubyfmt",
          version: VERSION,
          homepage: "https://github.com/reese/rubocop-rubyfmt",
          description: "Rubocop rules compatible with `rubyfmt`"
        )
      end

      def supported?(context)
        context.engine == :rubocop
      end

      def rules(_context)
        LintRoller::Rules.new(
          type: :path,
          config_format: :rubocop,
          value: Pathname.new(__dir__).join("../../../config/default.yml")
        )
      end
    end
  end
end
