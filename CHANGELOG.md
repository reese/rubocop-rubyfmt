# Changelog

## 0.1.2

- Disabled `Style/MethodCallWithoutArgsParentheses`. `rubyfmt` will handle parens in the vast majority
  of cases, and it occasionally requires calls with parens when local variables shadow method names.

## 0.1.1

- Disabled `Style/QuotedSymbols`, since `rubyfmt` always double-quotes quoted symbols.

## 0.1.0

- Initial project setup
- Add a custom lint for enforcing multiline rubocop disables
- Add a few initial rubocop configurations
