# `rubocop-rubyfmt`

[`rubyfmt`](https://github.com/fables-tales/rubyfmt)-compliant Rubocop configuration.

## Installation

Install the gem and add to the application's Gemfile by executing:

```bash
bundle add rubocop-rubyfmt
```

If bundler is not being used to manage dependencies, install the gem by executing:

```bash
gem install rubocop-rubyfmt
```

## Usage

Add the plugin to your `.rubocop.yml`:

```yaml
plugins:
  - rubocop-rubyfmt
```

## Custom Lints

### `Rubyfmt/NoEndOfLineRubocopDisables`

Rubocop allows two ways to disable lints for a certain expression. You can disable them at the end of a line, like so:

```ruby
'foo' # rubocop:disable Some/Lint
```

Alternatively, you can wrap the whole expression with comments on multiple lines.

```ruby
# rubocop:disable Some/Lint
'foo'
# rubocop:enable Some/Lint
```

`rubyfmt` only supports comments on their own line, and thus the latter is the only one that will work.

`Rubyfmt/NoEndOfLineRubocopDisables` is a custom lint that prevents usages of the end-of-line format, and it includes an autocorrect.

> [!TIP]
> If you're adopting `rubyfmt` for the first time and want to codemod your rubocop disables, you can run _only_ this cop with `bundle exec rubocop --autocorrect --only Rubyfmt/NoEndOfLineRubocopDisables`

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/reese/rubocop-rubyfmt.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
