# Testing Patterns

**Analysis Date:** 2026-03-07

## Test Framework

**Runner:**
- `package:test` ^1.19.2
- No config file (uses Dart defaults)

**Assertion Library:**
- Built-in `package:test` matchers (`expect`, `isNotNull`, `equals`, `throwsA`, `isA<T>()`)

**Mocking Library:**
- `package:mocktail` ^1.0.0 (declared as dev dependency, not currently used in existing tests)

**Run Commands:**
```bash
dart test                        # Run all tests
dart test test/src/deep_thought_injector_test.dart  # Run single file
dart test --coverage=coverage    # Run with coverage output
```

**Coverage Commands:**
```bash
dart pub global activate coverage 1.2.0
dart test --coverage=coverage
dart pub global run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info
genhtml coverage/lcov.info -o coverage/    # Generate HTML report
open coverage/index.html                    # View report
```

## Test File Organization

**Location:**
- Tests mirror the `lib/src/` directory structure under `test/src/`
- `lib/src/deep_thought_injector.dart` -> `test/src/deep_thought_injector_test.dart`
- `lib/src/sub_etha_scope.dart` -> no dedicated test file (tested indirectly through `DeepThought`)

**Naming:**
- `{source_file_name}_test.dart`

**Structure:**
```
test/
  src/
    deep_thought_injector_test.dart   # Main injector tests (5 tests)
    async_factory_test.dart           # Async registration tests (1 test)
```

## Test Structure

**Suite Organization (`test/src/deep_thought_injector_test.dart`):**
```dart
import 'package:deep_thought_injector/deep_thought_injector.dart';
import 'package:test/test.dart';

// Dummy service for testing.
class TestService {
  TestService(this.value);
  final int value;
}

void main() {
  group('DeepThought', () {
    test('can be instantiated', () {
      expect(DeepThought(), isNotNull);
    });

    test('can register and retrieve a lazily instantiated service', () {
      final deepThought = DeepThought();
      // ... test body
    });
  });
}
```

**Patterns:**
- `group()` used to organize tests by class/feature name
- Each `test()` has a descriptive English name starting with "can" or a verb phrase
- Fresh `DeepThought()` instance created per test (no shared setUp/tearDown)
- No `setUp` or `tearDown` blocks are used in existing tests
- Standalone `test()` (without group) used for simpler test files (`async_factory_test.dart`)

## Test Data / Fixtures

**Inline Test Doubles:**
- Simple dummy classes defined at the top of each test file
- No shared fixture files or factory utilities

**Pattern (`test/src/deep_thought_injector_test.dart`):**
```dart
class TestService {
  TestService(this.value);
  final int value;
}
```

**Pattern (`test/src/async_factory_test.dart`):**
```dart
class AsyncService {
  AsyncService(this.value);
  final int value;
}
```

**Counter Pattern for Verifying Lazy/Eager Behavior:**
```dart
var counter = 0;
TestService factory() {
  counter++;
  return TestService(100);
}

deepThought.ponder<TestService>(factory);
expect(counter, equals(0));  // Not yet called (lazy)

final service = deepThought.question<TestService>();
expect(counter, equals(1));  // Called exactly once
```

## Mocking

**Framework:** `package:mocktail` ^1.0.0 (available but unused)

**Current State:**
- No mocks exist in the test suite
- All tests use real implementations
- The `SubEthaScope.override()` method exists as a built-in test support mechanism for overriding registrations with concrete instances

**When to Use Mocking:**
- Use `mocktail` when testing code that depends on `DeepThought` or services registered within it
- Use `SubEthaScope.override<T>(instance)` to swap real registrations with test doubles

**SubEthaScope Override Pattern (for testing, in `lib/src/sub_etha_scope.dart`):**
```dart
void override<T>(T instance, {String? name}) {
  final key = _ServiceIdentifier(T, name);
  _factories[key] = _ServiceFactory<T>(
    syncFactory: () => instance,
    asyncFactory: null,
    lazy: false,
    lifecycle: Lifecycle.singleton,
  )..instance = instance;
}
```

## Coverage

**Requirements:** 100% coverage badge displayed in `coverage_badge.svg`

**CI Enforcement:**
- Very Good Workflows `dart_package.yml` enforces coverage thresholds in CI
- Coverage generated via `dart test --coverage=coverage`

**View Coverage:**
```bash
dart test --coverage=coverage
dart pub global run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info
genhtml coverage/lcov.info -o coverage/
open coverage/index.html
```

## Test Types

**Unit Tests:**
- All existing tests are unit tests targeting the public API of `DeepThought`
- Test synchronous and asynchronous registration/resolution
- Test lifecycle behaviors (singleton vs transient)
- Test error conditions (unregistered service, duplicate registration)

**Integration Tests:**
- Not present. No cross-module or cross-service integration tests.

**E2E Tests:**
- Not present (pure Dart library; no UI or server to drive end-to-end).

## Existing Test Cases

**`test/src/deep_thought_injector_test.dart` (5 tests):**
1. `can be instantiated` -- verifies `DeepThought()` constructor
2. `can register and retrieve a lazily instantiated service` -- lazy singleton: factory not called until `question()`
3. `can register and retrieve a non-lazy instantiated service` -- eager singleton: factory called at `ponder()` time
4. `throws exception when retrieving an unregistered service` -- expects `VogonPoetryException`
5. `transient lifecycle returns a new service each time` -- counter increments on each `question()` call

**`test/src/async_factory_test.dart` (1 test):**
1. `async factory returns a new service` -- `ponderAsync()` + `questionAsync()` with counter verification

## Common Patterns

**Async Testing (`test/src/async_factory_test.dart`):**
```dart
test('async factory returns a new service', () async {
  final deepThought = DeepThought();
  var counter = 0;

  Future<AsyncService> asyncFactory() async {
    counter++;
    return AsyncService(42);
  }

  await deepThought.ponderAsync<AsyncService>(asyncFactory);
  final service = await deepThought.questionAsync<AsyncService>();
  expect(service.value, equals(42));
  expect(counter, equals(1));
});
```

**Error Testing (`test/src/deep_thought_injector_test.dart`):**
```dart
test('throws exception when retrieving an unregistered service', () {
  final deepThought = DeepThought();
  expect(
    () => deepThought.question<TestService>(),
    throwsA(isA<VogonPoetryException>()),
  );
});
```

**Duplicate Registration Error Testing:**
```dart
test('throws exception on duplicate registration', () {
  final deepThought = DeepThought()
    ..ponder<TestService>(() => TestService(300));
  expect(
    () => deepThought.ponder<TestService>(() => TestService(400)),
    throwsA(isA<VogonPoetryException>()),
  );
});
```

## Untested Areas

The following functionality exists in source but has no dedicated test coverage:

- **Named registrations** (`name:` parameter on `ponder`/`question`) -- `lib/src/sub_etha_scope.dart`
- **Child scopes** (`createChildScope()`, parent fallback resolution) -- `lib/src/sub_etha_scope.dart`
- **Scoped lifecycle** (`Lifecycle.scoped`) -- `lib/src/sub_etha_scope.dart`
- **`reset()` method and `Disposable` cleanup** -- `lib/src/sub_etha_scope.dart`
- **`override()` method** -- `lib/src/sub_etha_scope.dart`
- **`errorNotifier` callback** -- `lib/src/deep_thought_injector.dart`
- **Custom logger injection** (`DeepThought.logger = ...`) -- `lib/src/deep_thought_injector.dart`
- **`AutoWiring.autoWire()`** -- `lib/src/auto_wiring.dart`
- **`DeepThoughtConfig` and `fromEnvironment()`** -- `lib/src/deep_thought_config.dart`
- **`VogonPoetryException.toString()`** formatting -- `lib/src/vogon_poetry_exception.dart`
- **Async locate fallback to sync factory** -- `lib/src/sub_etha_scope.dart` lines 126-132

## CI Integration

**GitHub Actions (`.github/workflows/main.yaml`):**
- Runs on push/PR to `main`
- Three jobs:
  1. `semantic_pull_request` -- enforces conventional commit PR titles
  2. `spell-check` -- cspell on all `**/*.md` files
  3. `build` -- Very Good Workflows `dart_package.yml` (format, analyze, test with coverage)

---

*Testing analysis: 2026-03-07*
