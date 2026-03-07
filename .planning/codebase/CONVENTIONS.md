# Coding Conventions

**Analysis Date:** 2026-03-07

## Naming Patterns

**Files:**
- Use `snake_case.dart` for all Dart source files
- File names match the primary class they contain (e.g., `deep_thought_injector.dart` contains `DeepThought`, `sub_etha_scope.dart` contains `SubEthaScope`)
- Test files mirror source file names with a `_test.dart` suffix (e.g., `deep_thought_injector_test.dart`)

**Classes:**
- Use `PascalCase` for all classes: `DeepThought`, `SubEthaScope`, `VogonPoetryException`, `DeepThoughtConfig`, `AutoWiring`
- Private classes are prefixed with underscore: `_ServiceFactory`, `_ServiceIdentifier`
- Thematic naming inspired by "The Hitchhiker's Guide to the Galaxy" (e.g., `ponder` instead of `register`, `question` instead of `resolve`, `VogonPoetryException` instead of a generic exception name)

**Functions/Methods:**
- Use `camelCase` for all methods and functions
- Public API methods use thematic names: `ponder()`, `ponderAsync()`, `question()`, `questionAsync()`
- Internal/utility methods use standard DI terminology: `register()`, `registerAsync()`, `locate()`, `locateAsync()`, `reset()`, `override()`
- Static factory methods use `fromX` pattern: `DeepThoughtConfig.fromEnvironment()`

**Variables:**
- Use `camelCase` for local variables and parameters
- Private instance fields are prefixed with underscore: `_scope`, `_factories`, `_lock`, `_logger`
- Public fields use `camelCase` without underscore: `parent`, `errorNotifier`
- Prefer `final` for fields and local variables that are not reassigned

**Enums:**
- Enum type uses `PascalCase`: `Lifecycle`
- Enum values use `camelCase`: `Lifecycle.singleton`, `Lifecycle.transient`, `Lifecycle.scoped`

**Constants:**
- Static constants use `camelCase`: `VogonPoetryException.serviceNotFoundError`

## Code Style

**Formatting:**
- `dart format` with default settings (2-space indentation)
- Trailing commas on parameter lists and argument lists to force multi-line formatting
- Run with: `dart format .`

**Linting:**
- `very_good_analysis` v5.1.0 (strict rule set from Very Good Ventures)
- Config: `analysis_options.yaml` includes `package:very_good_analysis/analysis_options.5.1.0.yaml`
- Run with: `dart analyze --fatal-infos`
- Key rules enforced: prefer `final`/`const`, trailing commas, type annotations where required, no implicit dynamic

**Spell Checking:**
- cspell configured in `.github/cspell.json`
- Custom dictionary includes project-specific words (`deep_thought_injector`)
- Runs on all `**/*.md` files in CI

## Import Organization

**Order:**
1. Dart SDK imports (`dart:async`)
2. Package imports (`package:deep_thought_injector/...`, `package:logging/...`, `package:test/...`)
3. Relative imports (`'sub_etha_scope.dart'`)

**Style:**
- Mix of `package:` imports and relative imports exists in `lib/src/` files (see `deep_thought_injector.dart` which uses both `package:deep_thought_injector/src/sub_etha_scope.dart` and `'sub_etha_scope.dart'` for the same file)
- Prefer `package:` imports for cross-directory references
- Use relative imports only within the same `lib/src/` directory

## Library Exports

**Barrel File Pattern:**
- Single public barrel file at `lib/deep_thought_injector.dart`
- Uses `library deep_thought_injector;` directive
- Exports only public API classes: `DeepThought`, `SubEthaScope`, `VogonPoetryException`
- Internal classes (`DeepThoughtConfig`, `AutoWiring`) are NOT exported and remain accessible only via direct `lib/src/` imports

**Example barrel file (`lib/deep_thought_injector.dart`):**
```dart
library deep_thought_injector;

export 'src/deep_thought_injector.dart';
export 'src/sub_etha_scope.dart';
export 'src/vogon_poetry_exception.dart';
```

## Error Handling

**Custom Exception:**
- All domain errors throw `VogonPoetryException` (implements `Exception`)
- Exception carries: `cause` (String), optional `errorCode` (int), optional `stackTrace` (StackTrace)
- Static error codes defined as constants: `VogonPoetryException.serviceNotFoundError = 1001`
- Use `const` constructor when possible: `throw const VogonPoetryException('message')`

**Error Wrapping Pattern in `DeepThought` (`lib/src/deep_thought_injector.dart`):**
```dart
try {
  return _scope.locate<T>(name: name);
} catch (e, s) {
  _logger.severe('Error locating service of type $T: $e\nStack Trace: $s');
  if (errorNotifier != null && e is Exception) {
    errorNotifier!(e, s);
  }
  throw VogonPoetryException(
    'Service of type $T not found. The cosmic poetry of error unfolds.',
    stackTrace: s,
  );
}
```

**Silent Catch Pattern in `AutoWiring` (`lib/src/auto_wiring.dart`):**
- Duplicate registration errors are silently caught with empty `catch` blocks
- Used intentionally to allow "register if not already present" semantics

**Error Notification:**
- `DeepThought.errorNotifier` is an optional callback `void Function(Exception e, StackTrace s)?`
- Called before re-throwing when an error occurs during service resolution
- Intended for integration with crash reporting (Sentry, Crashlytics)

## Logging

**Framework:** `package:logging` (Dart standard logging)

**Patterns:**
- Static `Logger` instance per class: `static Logger _logger = Logger('DeepThought')`
- Logger is replaceable via static setter: `DeepThought.logger = customLogger`
- Log at `severe` level for service resolution failures
- Include interpolated type information and stack traces in log messages

## Comments and Documentation

**Doc Comments (///):**
- All public classes have `///` doc comments
- All public methods have `///` doc comments
- Doc comments are concise, single-line where possible
- Example: `/// Register a service with the injector.`

**Implementation Comments (//):**
- Used for inline explanations of non-obvious logic
- File header comments indicate the file name: `// src/deep_thought.dart`
- TODO/future work noted inline: `// Future auto-wiring: scan constructors...`

**No JSDoc/annotation-based documentation system is used.**

## Class Design

**Constructor Pattern:**
- Named parameters with defaults for optional configuration
- Use initializer lists for final field assignment
- Example: `DeepThought({SubEthaScope? scope}) : _scope = scope ?? SubEthaScope();`

**Generics:**
- Heavy use of generics for type-safe service registration and resolution
- Generic type parameter `T` on `ponder<T>()`, `question<T>()`, `register<T>()`, `locate<T>()`

**Operator Overrides:**
- `_ServiceIdentifier` overrides `==` and `hashCode` for use as `Map` keys
- Uses the standard `identical` + `runtimeType` + field comparison pattern

**Interfaces:**
- `Disposable` abstract class in `lib/src/sub_etha_scope.dart` defines a `dispose()` contract
- Services implementing `Disposable` get cleaned up on `SubEthaScope.reset()`

**Const Usage:**
- Prefer `const` constructors where all fields are final and no computation is needed
- `VogonPoetryException` has a `const` constructor
- `_ServiceIdentifier` has a `const` constructor

---

*Convention analysis: 2026-03-07*
