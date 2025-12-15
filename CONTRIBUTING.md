# Contributing

Thanks for your interest in contributing.

## Ground rules

- By participating, you agree to follow the Code of Conduct.
- Keep changes focused and incremental.
- Do not include secrets in commits.

## Development workflow

- Run `dart format --set-exit-if-changed .`
- Run `dart analyze`
- Run `dart test`

## Pull requests

- Prefer one file per commit when practical.
- Include tests for behavior changes.
- Avoid `dart:io` in library code to preserve Web compatibility.

## Reporting bugs

Open a GitHub issue with:

- Reproduction steps
- Expected vs actual behavior
- Dart SDK version
- Platform (VM/Flutter/Web)
