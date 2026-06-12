# Repository Guidelines

## Project Structure & Module Organization
Deep Thought Injector is a reusable Dart package. Public exports live in `lib/deep_thought_injector.dart`, while implementation details are split across `lib/src/` modules such as `auto_wiring.dart`, `deep_thought_config.dart`, and lifecycle helpers. Tests mirror the same layout inside `test/src/` with `*_test.dart` files. The `example/` folder is the place to spike new integrations; keep generated coverage artifacts inside `coverage/` (ignored by git).

## Build, Test, and Development Commands
Run `dart pub get` whenever dependencies change. `dart format .` enforces canonical Dart formatting, and `dart analyze --fatal-infos` applies the Very Good Analysis rules from `analysis_options.yaml`. Execute `dart test` for the fast feedback loop, or use the coverage workflow: `dart test --coverage=coverage && dart pub global run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info`. Regenerate HTML reports with `genhtml coverage/lcov.info -o coverage/`.

## Coding Style & Naming Conventions
Follow the defaults from `package:very_good_analysis`: 2-space indentation, trailing commas for multiline literals, and prefer `final`/`const`. Use PascalCase for classes such as `DeepThoughtInjector`, lowerCamelCase for functions/variables, and snake_case for files (`sub_etha_scope.dart`). Keep public APIs documented with Dart doc comments and surface everything through `lib/deep_thought_injector.dart`.

## Testing Guidelines
Write focused unit tests with the `test` package and `mocktail` for doubles. Keep specs in `test/src/` and mirror the source directory tree. Name tests `<feature>_test.dart` and use `group`/`test` descriptions that read as sentences. Pull requests must include `dart test --coverage=coverage` output when adding behavior and keep coverage at or above the existing badge threshold.

## Commit & Pull Request Guidelines
History currently uses short, lowercase subjects (`first commit`). Continue using concise, imperative subjects and prefer the Conventional Commit prefixes (`feat:`, `fix:`, `refactor:`) to speed up changelog creation. Each PR should describe intent, list the primary changes, call out breaking API updates, and link tracking issues. Include screenshots or snippets when touching developer-facing documentation or example output.

## Configuration Tips
Use `lib/src/deep_thought_config.dart` to encode environment-specific overrides; document new fields in README and expose hooks for downstream apps. When adding logging or diagnostics, surface toggles via the configuration object to keep the package framework-agnostic.
