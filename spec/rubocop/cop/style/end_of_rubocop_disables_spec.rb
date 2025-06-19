require "spec_helper"

RSpec.describe RuboCop::Cop::Rubyfmt::NoEndOfLineRubocopDisables, :config do
  include(RuboCop::RSpec::ExpectOffense)

  it "registers an offense for end-of-line disable" do
    expect_offense(
      <<~OFFENSE
        foo # rubocop:disable Lint/SomeLint
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use multiline rubocop directives instead of end-of-line comments.
      OFFENSE
    )

    expect_correction(
      <<~CORRECTION
        # rubocop:disable Lint/SomeLint
        foo
        # rubocop:enable Lint/SomeLint
      CORRECTION
    )
  end

  it "handles indentation correctly" do
    expect_offense(
      <<~OFFENSE
        def method
          foo # rubocop:disable Lint/SomeLint
              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use multiline rubocop directives instead of end-of-line comments.
        end
      OFFENSE
    )

    expect_correction(
      <<~CORRECTION
        def method
          # rubocop:disable Lint/SomeLint
          foo
          # rubocop:enable Lint/SomeLint
        end
      CORRECTION
    )
  end

  it "does not register offense for standalone disable comment" do
    expect_no_offenses(
      <<~INPUT
        # rubocop:disable Lint/SomeLint
        foo
        # rubocop:enable Lint/SomeLint
      INPUT
    )
  end

  it "does not register offenses for strings" do
    expect_no_offenses(
      <<~INPUT
        <<~FOO
          foo # rubocop:disable Lint/SomeLint
        FOO
      INPUT
    )
  end
end
