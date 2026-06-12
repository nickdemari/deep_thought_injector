# Technology Stack

**Analysis Date:** 2026-03-07

## Languages

**Primary:**
- Dart >=3.0.0 <4.0.0 - Entire codebase (library source, tests, examples)

**Secondary:**
- YAML - Configuration (`pubspec.yaml`, `analysis_options.yaml`, `.github/workflows/main.yaml`, `.github/dependabot.yaml`)

## Runtime

**Environment:**
- Dart SDK >=3.0.0 <4.0.0 (specified in `pubspec.yaml` under `environment.sdk`)

**Package Manager:**
- `dart pub` (Dart's built-in package manager)
- Lockfile: **not committed** (`pubspec.lock` is in `.gitignore`)

## Frameworks

**Core:**
- This is a standalone Dart library (no Flutter dependency). It is a dependency injection / service locator package.
- Created with [Very Good CLI](https://github.com/VeryGoodOpenSource/very_good_cli) (Mason-based project scaffolding)

**Testing:**
- `test` ^1.19.2 - Dart's standard test framework (`pubspec.yaml` dev_dependency)
- `mocktail` ^1.0.0 - Mocking library (`pubspec.yaml` dev_dependency; not currently used in test files)

**Linting/Analysis:**
- `very_good_analysis` ^5.1.0 - Strict analysis rules (`pubspec.yaml` dev_dependency)
- Configuration: `analysis_options.yaml` includes `package:very_good_analysis/analysis_options.5.1.0.yaml`

**Build/Dev:**
- No custom build tooling. Standard `dart` CLI commands are the entire toolchain.

## Key Dependencies

**Critical (runtime):**
- `logging` (from `package:logging/logging.dart`) - Used in `lib/src/deep_thought_injector.dart` and `lib/src/auto_wiring.dart` for structured logging. **WARNING: This package is imported but NOT listed in `pubspec.yaml` dependencies.** It only resolves because it is a transitive dependency of the test SDK or analysis package. This is a bug -- it must be added to `pubspec.yaml` under `dependencies`.

**Dev Dependencies:**
- `mocktail` ^1.0.0 - Mock generation for tests (declared but not actually imported in any test file currently)
- `test` ^1.19.2 - Test runner and assertion library
- `very_good_analysis` ^5.1.0 - Lint rule set

## Configuration

**Environment:**
- No `.env` files exist or are expected. This is a library package, not an application.
- `DeepThoughtConfig` (`lib/src/deep_thought_config.dart`) provides a programmatic configuration holder with `environment`, `environmentOverrides`, and `secrets` maps. Consumers instantiate it in their own code.

**Build:**
- `pubspec.yaml` - Package manifest and dependency declarations
- `analysis_options.yaml` - Static analysis configuration (delegates to `very_good_analysis`)

**Publish:**
- `publish_to: none` in `pubspec.yaml` -- this package is NOT published to pub.dev

## Platform Requirements

**Development:**
- Dart SDK >=3.0.0 installed
- Run `dart pub get` to fetch dependencies
- No platform-specific native code; pure Dart

**Production:**
- Consumers add this package as a dependency (or path dependency). It runs anywhere Dart runs (Flutter mobile/web/desktop, server-side Dart, CLI tools).
- No deployment target for the package itself -- it is a library.

## Commands Reference

```bash
dart pub get                    # Install dependencies
dart format .                   # Format code
dart analyze --fatal-infos      # Lint with Very Good Analysis rules
dart test                       # Run all tests
dart test --coverage=coverage   # Run tests with coverage output
```

Coverage report generation:
```bash
dart pub global activate coverage 1.2.0
dart test --coverage=coverage
dart pub global run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info
genhtml coverage/lcov.info -o coverage/
```

---

*Stack analysis: 2026-03-07*
