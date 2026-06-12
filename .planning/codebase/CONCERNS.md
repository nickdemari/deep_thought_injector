# Codebase Concerns

**Analysis Date:** 2026-03-07

## Tech Debt

**Undeclared `logging` dependency:**
- Issue: `package:logging/logging.dart` is imported in `lib/src/deep_thought_injector.dart` (line 5) and `lib/src/auto_wiring.dart` (line 7), but `logging` is not declared as a dependency in `pubspec.yaml`. The package only lists `dev_dependencies`. There is no `dependencies:` section at all.
- Files: `pubspec.yaml`, `lib/src/deep_thought_injector.dart`, `lib/src/auto_wiring.dart`
- Impact: `dart pub get` will fail for any consumer of this package. The package cannot be used as-is. This is a blocking issue.
- Fix approach: Add `logging: ^1.2.0` (or appropriate version) under a new `dependencies:` section in `pubspec.yaml`.

**Duplicate import of `sub_etha_scope.dart`:**
- Issue: `lib/src/deep_thought_injector.dart` imports the same file twice -- once as a package import (line 3: `package:deep_thought_injector/src/sub_etha_scope.dart`) and once as a relative import (line 6: `sub_etha_scope.dart`). The comment `// now includes Lifecycle` suggests this was added hastily to get `Lifecycle` in scope, but the package import already covers it.
- Files: `lib/src/deep_thought_injector.dart`
- Impact: Dart's analyzer may warn. Creates confusion about import style conventions. No runtime breakage, but signals sloppy maintenance.
- Fix approach: Remove line 6 (`import 'sub_etha_scope.dart';`). The `Lifecycle` enum is already accessible through the package import on line 3.

**`Lifecycle.scoped` declared but never implemented:**
- Issue: The `Lifecycle` enum in `lib/src/sub_etha_scope.dart` (line 23) defines `scoped`, but no code path in `locate()`, `locateAsync()`, or `register()` handles the `scoped` lifecycle. A service registered with `Lifecycle.scoped` will behave identically to `Lifecycle.singleton` because both fall through to the same `instance ??= factory()` logic.
- Files: `lib/src/sub_etha_scope.dart` (lines 23, 87-133)
- Impact: Misleading API. Users who register with `Lifecycle.scoped` expect scope-limited instances (created per `SubEthaScope` child, not shared globally). Instead they silently get singleton behavior.
- Fix approach: Implement scoped lifecycle handling: create a new instance per child scope, and dispose it when the child scope is reset. This requires tracking which scope owns which instance and resetting scoped instances on `createChildScope()` boundaries.

**`AutoWiring` is a non-functional stub:**
- Issue: `lib/src/auto_wiring.dart` claims to support auto-wiring but the implementation is trivial: it registers a `Logger` and a `DeepThoughtConfig`, then has a vague loop that registers more `Logger` instances (not the declared types). The "auto-register" feature just registers `Logger` objects named after type strings -- it does not actually resolve or instantiate those types.
- Files: `lib/src/auto_wiring.dart`
- Impact: The module is misleading. The `autoWire()` method accepts `dynamic` instead of `DeepThought` (line 12), then immediately checks `is! DeepThought`. This defeats the type system. The auto-register loop (lines 39-43) silently registers `Logger` instances for each entry, which overwrites any previously registered `Logger` because the type key is `Logger` (not the named type).
- Fix approach: Either delete this stub and document it as a planned feature, or implement real auto-wiring with proper type resolution. At minimum, change the parameter from `dynamic` to `DeepThought`.

**`_lock` field declared but never used:**
- Issue: `SubEthaScope` declares `final _lock = Object();` on line 31 of `lib/src/sub_etha_scope.dart`, with the comment "Simple lock object placeholder for thread safety." It is never referenced anywhere.
- Files: `lib/src/sub_etha_scope.dart` (line 31)
- Impact: Dead code. Misleads readers into thinking thread safety is handled. Dart is single-threaded (event loop), so a simple `Object()` lock would not provide meaningful concurrency protection anyway.
- Fix approach: Remove the `_lock` field. If isolate-safe access is needed in the future, use a proper async mutex or document single-isolate-only usage.

**`DeepThoughtConfig.secrets` stored as plaintext `Map<String, String>`:**
- Issue: `lib/src/deep_thought_config.dart` has a `secrets` field (line 21) that holds API keys and sensitive data as a plain `Map<String, String>`. No encryption, no secure storage, no access control.
- Files: `lib/src/deep_thought_config.dart`
- Impact: Secrets are trivially accessible to any code that can resolve `DeepThoughtConfig`. In a Flutter context, this means they persist in memory as plain strings and could appear in heap dumps or debug tools.
- Fix approach: Either remove the `secrets` field (it is not used anywhere in the codebase) or wrap it with a secure accessor pattern that at minimum avoids toString/logging exposure.

**`DeepThoughtConfig` and `AutoWiring` not exported from barrel file:**
- Issue: `lib/deep_thought_injector.dart` exports `DeepThought`, `SubEthaScope`, and `VogonPoetryException`, but not `DeepThoughtConfig` or `AutoWiring`. The README shows importing `DeepThoughtConfig` via a direct `src/` import, which is an anti-pattern.
- Files: `lib/deep_thought_injector.dart`, `README.md` (line 77)
- Impact: Users must import internal paths (`package:deep_thought_injector/src/deep_thought_config.dart`) to use config features. This couples consumers to internal file structure.
- Fix approach: Either export these from the barrel file or mark them as deliberately internal with documentation explaining why.

**Stale file header comment:**
- Issue: `lib/src/deep_thought_injector.dart` line 1 says `// src/deep_thought.dart` but the file is actually named `deep_thought_injector.dart`.
- Files: `lib/src/deep_thought_injector.dart` (line 1)
- Impact: Minor confusion during code navigation.
- Fix approach: Update the comment to `// src/deep_thought_injector.dart` or remove it.

## Known Bugs

**Auto-wiring silently swallows all exceptions:**
- Symptoms: `AutoWiring.autoWire()` wraps every registration in a `try/catch` with empty catch bodies (lines 18-32, 35-47 of `lib/src/auto_wiring.dart`). If registration fails for any reason other than duplicates -- type errors, factory exceptions, etc. -- the failure is silently ignored.
- Files: `lib/src/auto_wiring.dart` (lines 18-32, 35-47)
- Trigger: Any unexpected exception during auto-wiring is swallowed.
- Workaround: Do not use `AutoWiring.autoWire()`. Register dependencies manually.

**Async singleton race condition:**
- Symptoms: If `locateAsync<T>()` is called concurrently for a lazy async singleton, the factory may execute multiple times. The check on line 121 (`if (serviceFactory.instance == null)`) is not atomic -- two concurrent `await`s can both see `null` and both invoke the factory.
- Files: `lib/src/sub_etha_scope.dart` (lines 108-133)
- Trigger: Two `locateAsync<T>()` calls for the same lazy async singleton before the first factory completes.
- Workaround: Ensure callers await the first `locateAsync` before calling it again, or register with `lazy: false` to eagerly initialize.

## Security Considerations

**Secrets in plaintext configuration:**
- Risk: `DeepThoughtConfig.secrets` (type `Map<String, String>?`) stores sensitive values with zero protection. Any code that resolves `DeepThoughtConfig` can read all secrets.
- Files: `lib/src/deep_thought_config.dart` (line 21)
- Current mitigation: None. The field is not used anywhere in the codebase currently.
- Recommendations: Remove the field entirely if unused, or implement a secure vault pattern with access logging.

**Error messages expose type information:**
- Risk: `VogonPoetryException` messages include Dart type names (e.g., `'Service of type $T not found'` in `lib/src/deep_thought_injector.dart` lines 53-54). In production environments, these could leak internal architecture details.
- Files: `lib/src/deep_thought_injector.dart` (lines 49, 53-54, 65-66, 70-71)
- Current mitigation: None.
- Recommendations: Allow configurable error verbosity. Use generic messages in production mode.

## Performance Bottlenecks

**Linear parent-scope chain traversal:**
- Problem: `locate()` and `locateAsync()` walk up the parent chain one scope at a time via recursive calls (lines 90-91 and 112-113 of `lib/src/sub_etha_scope.dart`). With deeply nested scopes, this becomes O(n) per lookup where n is the scope depth.
- Files: `lib/src/sub_etha_scope.dart` (lines 87-105, 108-133)
- Cause: Recursive parent delegation without caching.
- Improvement path: For most DI use cases (2-3 levels), this is fine. If deep nesting becomes common, consider caching resolved services at the child scope level or flattening the lookup map.

## Fragile Areas

**`SubEthaScope` registration/lookup type safety:**
- Files: `lib/src/sub_etha_scope.dart` (lines 88-89)
- Why fragile: The cast `_factories[key] as _ServiceFactory<T>?` on line 89 of `locate()` relies on runtime type matching. If a service is registered with one generic type and looked up with another (e.g., interface vs. implementation), this silently returns `null` rather than producing a helpful error.
- Safe modification: Always register and resolve using the same type parameter. Add integration tests for interface-based registration.
- Test coverage: No tests exist for interface-based registration, parent scope fallback, or named registrations.

**`DeepThought.question()` exception re-wrapping:**
- Files: `lib/src/deep_thought_injector.dart` (lines 45-58)
- Why fragile: The method catches all exceptions, logs them, optionally notifies, then always throws a new `VogonPoetryException`. The original exception type and message are lost in the re-throw. The `errorNotifier` only fires for `Exception` subclasses (line 50: `e is Exception`), silently skipping `Error` types.
- Safe modification: Preserve the original exception as a `cause` field or chain. Consider notifying on `Error` types as well.
- Test coverage: No tests for the `errorNotifier` callback or logging behavior.

## Scaling Limits

**Single-isolate only:**
- Current capacity: Works within a single Dart isolate.
- Limit: `SubEthaScope`'s internal `Map` is not safe across isolates. The `_lock` field (which was presumably intended for this) is unused.
- Scaling path: For multi-isolate Flutter apps, each isolate needs its own `DeepThought` instance. Document this limitation clearly.

## Dependencies at Risk

**No runtime dependencies declared:**
- Risk: `logging` package is imported but not in `pubspec.yaml`. The package has zero declared runtime dependencies, making it appear dependency-free, but it is not.
- Impact: The package will not resolve when consumed by other projects. `dart pub get` will fail.
- Migration plan: Add `logging` to `dependencies` in `pubspec.yaml`.

## Missing Critical Features

**No service unregistration:**
- Problem: Once registered, a service cannot be individually removed. The only option is `reset()` which clears everything.
- Blocks: Testing scenarios where you need to swap a single service, or dynamic plugin architectures.

**No circular dependency detection:**
- Problem: If service A's factory resolves service B, and B's factory resolves A, the call stack will overflow with no helpful error message.
- Blocks: Safe usage in complex dependency graphs. Users get a `StackOverflowError` instead of a diagnostic message.

**No `isRegistered<T>()` check:**
- Problem: There is no way to check whether a type is registered without catching an exception. The only discovery mechanism is `question<T>()` which throws on miss.
- Blocks: Conditional registration patterns, optional dependency resolution, and clean fallback logic.

## Test Coverage Gaps

**`AutoWiring` has zero tests:**
- What's not tested: The entire `lib/src/auto_wiring.dart` module -- auto-registration of Logger, DeepThoughtConfig, autoRegister list parsing, invalid input handling.
- Files: `lib/src/auto_wiring.dart`
- Risk: Any change to AutoWiring could break silently. The swallowed exceptions mean bugs won't even surface.
- Priority: Low (the module is a stub), but if it is ever promoted to real functionality, tests are mandatory first.

**`DeepThoughtConfig` has zero tests:**
- What's not tested: The `fromEnvironment()` factory, the config fields, environment override behavior.
- Files: `lib/src/deep_thought_config.dart`
- Risk: Configuration logic is untested. Changes could break without notice.
- Priority: Low (trivial class), but should be tested before adding real behavior.

**Child scopes not tested:**
- What's not tested: `createChildScope()`, parent fallback resolution, scope isolation, scoped lifecycle behavior.
- Files: `lib/src/sub_etha_scope.dart` (lines 36, 87-93, 108-113)
- Risk: The parent-child scope chain is a core feature with no test coverage. Regressions would go undetected.
- Priority: High. Scope hierarchies are a fundamental DI feature and the implementation has subtle edge cases.

**Named registrations not tested:**
- What's not tested: Registering multiple services of the same type with different names, resolving by name, name collision behavior.
- Files: `lib/src/sub_etha_scope.dart` (`_ServiceIdentifier` class, `name` parameter throughout)
- Risk: The `_ServiceIdentifier` equality/hashCode logic (lines 12-19) is untested. A hash collision bug would cause silent service misresolution.
- Priority: High. Named registrations are a key differentiator and the custom `hashCode` implementation needs verification.

**`override()` not tested:**
- What's not tested: Overriding a registered service with an instance, overriding non-existent registrations, type safety of overrides.
- Files: `lib/src/sub_etha_scope.dart` (lines 146-154)
- Risk: The `override()` method is intended for testing support but is itself untested.
- Priority: Medium.

**`reset()` and `Disposable` not tested:**
- What's not tested: That `reset()` calls `dispose()` on `Disposable` instances, that the factory map is cleared, that services are no longer resolvable after reset.
- Files: `lib/src/sub_etha_scope.dart` (lines 136-143, 173-175)
- Risk: Resource leaks if `Disposable.dispose()` stops being called.
- Priority: Medium.

**`errorNotifier` callback not tested:**
- What's not tested: That the notifier fires on service resolution failure, that it receives the correct exception and stack trace, that it handles `Error` vs `Exception` correctly.
- Files: `lib/src/deep_thought_injector.dart` (lines 16, 50-51, 67-68)
- Risk: Integration error reporting (Sentry, Crashlytics) could silently stop working.
- Priority: Medium.

**No `pubspec.lock` committed:**
- What's not tested: Reproducible dependency resolution. The `.gitignore` excludes `pubspec.lock`, which is correct for packages but means CI resolves whatever versions are current, potentially causing flaky builds.
- Files: `.gitignore` (line 7)
- Risk: Low for packages (this is the Dart convention), but worth noting that test behavior could vary across environments.
- Priority: Low.

---

*Concerns audit: 2026-03-07*
