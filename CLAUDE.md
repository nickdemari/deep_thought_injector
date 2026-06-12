# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A Dart dependency injection / service locator package themed after "The Hitchhiker's Guide to the Galaxy". Created with Very Good CLI. Not published to pub.dev (`publish_to: none`).

## Commands

```sh
dart pub get                    # Install dependencies
dart format .                   # Format code
dart analyze --fatal-infos      # Lint (Very Good Analysis rules)
dart test                       # Run all tests
dart test test/src/deep_thought_injector_test.dart  # Run a single test file
dart test --coverage=coverage   # Run tests with coverage
```

Coverage report generation:
```sh
dart pub global activate coverage 1.2.0
dart test --coverage=coverage
dart pub global run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info
genhtml coverage/lcov.info -o coverage/
```

## Architecture

**Public barrel file:** `lib/deep_thought_injector.dart` exports `DeepThought`, `SubEthaScope`, and `VogonPoetryException`.

**Core classes and their Hitchhiker's Guide naming:**

- `DeepThought` (`lib/src/deep_thought_injector.dart`) — The main injector facade. `ponder()` / `ponderAsync()` register services; `question()` / `questionAsync()` resolve them. Wraps `SubEthaScope` and adds logging + error notification.
- `SubEthaScope` (`lib/src/sub_etha_scope.dart`) — The actual DI container. Manages a `Map<_ServiceIdentifier, _ServiceFactory>` of registrations. Supports parent-child scope chains (child falls back to parent on lookup), three lifecycles (`Lifecycle.singleton`, `.transient`, `.scoped`), named registrations, sync/async factories, `override()` for testing, and `reset()` with `Disposable` cleanup.
- `VogonPoetryException` (`lib/src/vogon_poetry_exception.dart`) — Custom exception with optional `errorCode` and `stackTrace`.

## Conventions

- Uses `very_good_analysis` v5.1.0 for strict linting (2-space indent, trailing commas, prefer `final`/`const`)
- Tests use `package:test` and `package:mocktail`; test files mirror `lib/src/` structure under `test/src/`
- Commit messages: concise, imperative, prefer Conventional Commit prefixes (`feat:`, `fix:`, `refactor:`)

## CI

GitHub Actions workflow (`.github/workflows/main.yaml`) runs on push/PR to `main`: semantic PR check, spell check (cspell), and the standard Very Good Workflows Dart package job (format, analyze, test with coverage).
