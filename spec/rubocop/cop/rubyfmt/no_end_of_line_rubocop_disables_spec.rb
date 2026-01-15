# frozen_string_literal: true

require "spec_helper"

RSpec.describe RuboCop::Cop::Rubyfmt::NoEndOfLineRubocopDisables, :config do
  include(RuboCop::RSpec::ExpectOffense)

  it "registers an offense for end-of-line disable" do
    expect_offense(
      <<~RUBY
        foo # rubocop:disable Lint/SomeLint
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use multiline rubocop directives instead of end-of-line comments.
      RUBY
    )

    expect_correction(
      <<~RUBY
        # rubocop:disable Lint/SomeLint
        foo
        # rubocop:enable Lint/SomeLint
      RUBY
    )
  end

  it "handles indentation correctly" do
    expect_offense(
      <<~RUBY
        def method
          foo # rubocop:disable Lint/SomeLint
              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use multiline rubocop directives instead of end-of-line comments.
        end
      RUBY
    )

    expect_correction(
      <<~RUBY
        def method
          # rubocop:disable Lint/SomeLint
          foo
          # rubocop:enable Lint/SomeLint
        end
      RUBY
    )
  end

  it "does not register offense for standalone disable comment" do
    expect_no_offenses(
      <<~RUBY
        # rubocop:disable Lint/SomeLint
        foo
        # rubocop:enable Lint/SomeLint
      RUBY
    )
  end

  it "does not register offenses for strings" do
    expect_no_offenses(
      <<~RUBY
        <<~FOO
          foo # rubocop:disable Lint/SomeLint
        FOO
      RUBY
    )
  end
end
