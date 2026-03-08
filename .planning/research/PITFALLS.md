# Pitfalls Research

**Domain:** Flutter dependency injection package with widget-tree scoping (competing with get_it, publishing to pub.dev)
**Researched:** 2026-03-07
**Confidence:** HIGH (based on get_it GitHub issues, Flutter framework docs, Provider/Riverpod design decisions, pub.dev scoring documentation, and codebase audit)

## Critical Pitfalls

### Pitfall 1: Widget Lifecycle vs. Scope Lifetime Mismatch

**What goes wrong:**
When DI scopes are tied to individual screen/widget lifecycles, Flutter's navigation timing creates race conditions. During `Navigator.popAndPushNamed()`, the new screen's `initState` fires *before* the old screen's `dispose`. If scope push happens in `initState` and scope pop happens in `dispose`, the wrong scope gets destroyed -- the new screen's freshly-pushed scope is popped by the old screen's dispose callback, leaving the new screen with no valid dependencies.

This is the single most reported issue with get_it's scoping system (see [get_it #247](https://github.com/fluttercommunity/get_it/issues/247), [#158](https://github.com/fluttercommunity/get_it/issues/158)). The get_it maintainer's own advice is "don't tie scopes to screen lifecycles" -- which is an admission that their scoping model is fundamentally mismatched with Flutter's widget tree.

**Why it happens:**
Developers assume widget creation and destruction are symmetrically paired in time. They are not. Flutter's `Element` tree has `deactivate` (temporary removal) and `dispose` (permanent removal), and during navigation transitions, overlapping widget lifecycles mean multiple scopes can be "active" simultaneously. The old widget may be animating out while the new widget is fully built.

**How to avoid:**
The InheritedWidget approach *is* the prevention. By making scopes InheritedWidgets in the tree, scope lifetime is managed by Flutter's element lifecycle, not by manual push/pop calls. When the widget is removed from the tree, its scope dies automatically. No explicit dispose timing needed because Flutter handles element disposal order correctly. Specifically:
- Scope creation = widget inserted into tree (handled by `StatefulWidget.initState` / `build`)
- Scope destruction = `State.dispose()` on the scope provider widget
- Child scopes below in the tree are disposed before parent scopes above (Flutter guarantees bottom-up disposal)
- Never expose manual `pushScope`/`popScope` APIs that decouple scope lifetime from widget lifetime

**Warning signs:**
- Any design where `createScope()` and `disposeScope()` are called manually
- Tests that work in isolation but fail when navigation transitions are animated
- Race conditions in integration tests that "sometimes work"
- Users reporting "my service is null after navigating"

**Phase to address:**
Phase 1 (Flutter widget integration). This is the foundational architectural decision. Getting this wrong means a rewrite.

---

### Pitfall 2: Stale InheritedWidget Dependencies Causing Phantom Rebuilds

**What goes wrong:**
Once a widget calls `context.dependOnInheritedWidgetOfExactType<T>()`, Flutter registers that widget as a dependent of the InheritedWidget. Even if a subsequent rebuild of that widget *doesn't* call the dependency method again, the framework still considers it a dependent and will rebuild it whenever the InheritedWidget's `updateShouldNotify` returns `true`. This is documented Flutter behavior ([flutter #62861](https://github.com/flutter/flutter/issues/62861)) and is *not* a bug -- it is how `InheritedElement.updateDependencies` works.

For a DI package, this means if a widget resolves a service via `context.read<MyService>()` (which internally calls `dependOnInheritedWidgetOfExactType`), that widget will rebuild every time the scope widget rebuilds, even if the service itself hasn't changed. In large trees with many consumers, this causes cascading unnecessary rebuilds.

**Why it happens:**
The InheritedWidget dependency tracking is coarse-grained by default. It tracks "this Element depends on that InheritedElement" -- not "this Element depends on field X of that InheritedElement." Package authors who don't understand this nuance create APIs where every service lookup creates a rebuild dependency.

**How to avoid:**
Implement two distinct access patterns, similar to how Provider does it:
1. **`context.read<T>()`** -- Uses `getInheritedWidgetOfExactType` (note: no "dependOn" prefix), which retrieves the widget *without* registering a dependency. Use for one-time lookups in event handlers, `initState`, etc.
2. **`context.watch<T>()`** -- Uses `dependOnInheritedWidgetOfExactType`, which registers the dependency. Use only in `build()` when the widget should rebuild on scope changes.
3. **`updateShouldNotify`** -- Return `false` when only the scope identity changes but the contained services haven't actually changed. Since a DI scope rarely "changes" (services are registered once), `updateShouldNotify` should almost always return `false` for the base scope widget.

Additionally, consider implementing `InheritedModel` instead of `InheritedWidget` if you want per-service-type granular rebuild tracking. But this adds significant complexity and is probably overkill for v1.

**Warning signs:**
- Widget tests showing rebuilds when no service data changed
- Performance profiling showing excessive `build()` calls in deep widget trees
- Users complaining about "my whole screen rebuilds when I resolve a service"

**Phase to address:**
Phase 1 (Flutter widget integration). The `context.read` vs. `context.watch` distinction must be designed into the extension API from the start.

---

### Pitfall 3: The "Context Must Be Below" Trap

**What goes wrong:**
`BuildContext.dependOnInheritedWidgetOfExactType` can only look *up* the widget tree. If a widget tries to resolve a service from a scope that is a sibling or child in the tree (not an ancestor), it silently returns `null`. The classic manifestation: a developer wraps `MaterialApp` with a scope provider, then tries to access services in a widget that is *also* a direct child of the same parent, not a descendant of the scope provider.

In testing, this is even more treacherous. If `pumpWidget` wraps the test widget incorrectly, scope resolution fails with no useful error message -- just a null.

**Why it happens:**
InheritedWidget lookup is ancestor-only by design. Developers coming from get_it (which uses global lookup, no context needed) will instinctively try to access services from anywhere. The mental model shift from "global registry" to "tree-scoped resolution" trips up every single person the first time.

**How to avoid:**
1. **Never return null from `of()` methods.** Throw an informative error: "No DeepThoughtScope found above this context. Did you forget to wrap your widget tree with DeepThoughtScope?"
2. **Provide both `of()` and `maybeOf()`.** `of()` throws, `maybeOf()` returns null. This is the standard Flutter convention (Theme.of, MediaQuery.of, etc.).
3. **Document the "wrap above MaterialApp" pattern** prominently in the README.
4. **Test helper widgets** that pre-wrap with a scope, making widget tests trivial.

**Warning signs:**
- Null pointer exceptions in user code when trying to resolve services
- GitHub issues asking "why can't I find my service?"
- Users wrapping individual pages instead of the app root

**Phase to address:**
Phase 1 (Flutter widget integration) for the implementation. Phase 3 (Documentation/README) for the user education.

---

### Pitfall 4: Async Singleton Race Conditions

**What goes wrong:**
When `locateAsync<T>()` is called concurrently for a lazy async singleton, the factory executes multiple times. The current implementation checks `if (serviceFactory.instance == null)` then `await`s the factory -- but between the null check and the assignment, another caller can also see null and invoke the factory. You end up with two instances of what should be a singleton, and whichever completes second overwrites the first.

This is *already a known bug* in the codebase (documented in CONCERNS.md). But it becomes **critical** once widget-tree scoping enters the picture, because `didChangeDependencies()` can fire on multiple widgets simultaneously, all trying to resolve the same async service.

**Why it happens:**
Dart is single-threaded but not single-*tick*. `await` yields to the event loop, allowing other microtasks to execute. The check-then-act pattern (`if null, then await factory`) is not atomic across await boundaries.

**How to avoid:**
Use a `Completer<T>` as a synchronization primitive:
```dart
if (serviceFactory._completer == null) {
  serviceFactory._completer = Completer<T>();
  try {
    final instance = await serviceFactory.asyncFactory!();
    serviceFactory.instance = instance;
    serviceFactory._completer!.complete(instance);
  } catch (e, s) {
    serviceFactory._completer!.completeError(e, s);
    serviceFactory._completer = null; // Allow retry
    rethrow;
  }
} else {
  return serviceFactory._completer!.future;
}
```
The first caller creates the Completer and starts the factory. All subsequent callers get the same Completer's future and wait for the same result.

**Warning signs:**
- Flaky tests involving async service resolution
- "Service already registered" errors appearing intermittently
- Duplicate HTTP clients or database connections in production
- Memory usage higher than expected (duplicate singleton instances)

**Phase to address:**
Phase 1 (Core fixes). This must be fixed before Flutter integration, because widget-tree resolution amplifies concurrent access patterns.

---

### Pitfall 5: No Circular Dependency Detection (StackOverflow Instead of Diagnostic)

**What goes wrong:**
If service A's factory resolves service B, and service B's factory resolves service A, the call stack overflows with no useful error. The user gets `StackOverflowError` -- an `Error`, not an `Exception` -- which means the existing `errorNotifier` (which only catches `Exception` types) never fires. The crash report has a wall of identical stack frames with zero diagnostic value.

**Why it happens:**
The `locate()` method has no re-entrancy guard. Each factory invocation can call back into `locate()`, and the recursion depth is unbounded. This is a standard pitfall in service locator implementations and get_it handles it... also poorly (same issue).

**How to avoid:**
Track a resolution-in-progress set:
```dart
final Set<_ServiceIdentifier> _resolving = {};

T locate<T>({String? name}) {
  final key = _ServiceIdentifier(T, name);
  if (_resolving.contains(key)) {
    throw VogonPoetryException(
      'Circular dependency detected: $T is already being resolved. '
      'Resolution chain: ${_resolving.map((k) => k.type).join(" -> ")} -> $T',
    );
  }
  _resolving.add(key);
  try {
    // ... existing resolution logic
  } finally {
    _resolving.remove(key);
  }
}
```
This gives developers an actionable error message showing the exact dependency chain.

**Warning signs:**
- Any lazy singleton whose factory calls `question<T>()` or `locate<T>()`
- Complex dependency graphs with 5+ interrelated services
- Tests that "hang" or crash without clear errors

**Phase to address:**
Phase 1 (Core fixes). Must exist before publishing because circular dependencies are the number one "silent killer" in DI libraries.

---

### Pitfall 6: Pub.dev Score Death by a Thousand Cuts

**What goes wrong:**
The package scores poorly on pub.dev (max 160 points) because of a combination of small oversights that each cost 10-30 points. A package with 80/160 points looks abandoned and untrustworthy. Developers scroll past it. The current codebase has *multiple* scoring landmines:

- `publish_to: none` in pubspec.yaml (blocks publishing entirely)
- No `description` field in pubspec.yaml (or the default VGC boilerplate counts against you)
- `logging` dependency not declared (static analysis will fail)
- Duplicate import (analyzer warning)
- No `example/` directory
- Missing dartdoc on public APIs (need >= 20% coverage for points, but aim for 100%)
- No `topics` field in pubspec.yaml
- No platform declarations
- No `screenshots` field
- Missing `repository` or `homepage` URL
- Inadequate `CHANGELOG.md`

**Why it happens:**
Package authors focus on implementation and forget that pub.dev scoring is a separate, opaque system with specific requirements that aren't always obvious. Running `dart pub publish --dry-run` catches some issues but not all -- pana catches more.

**How to avoid:**
1. Run `pana` locally before every publish attempt: `dart pub global activate pana && pana .`
2. Fix the blocking issues first: undeclared `logging` dep, remove `publish_to: none`, add description
3. Create `example/main.dart` showing basic usage (not `example/lib/main.dart` -- pana specifically looks for `example/main.dart` or `example/example.dart`)
4. Add `topics` (max 5): `dependency-injection`, `service-locator`, `flutter`, `di`, `scoping`
5. Add `screenshots` with at least one image showing the package in action
6. 100% dartdoc on all public members (not just 20% -- you're competing with get_it which has full documentation)
7. Add `funding` URLs if applicable
8. Ensure the README has code examples that are *actually runnable* (pana may verify this in the future)

**Warning signs:**
- `dart pub publish --dry-run` showing warnings
- pana score below 140/160
- Missing sections in the pub.dev package page
- No "likes" or "popularity" after first week (means nobody found it or it looked low-quality)

**Phase to address:**
Phase 2 (Pub.dev preparation). But start checking pana in CI from Phase 1 to catch regressions early.

---

### Pitfall 7: Themed API Names Becoming a Discoverability Disaster

**What goes wrong:**
The Hitchhiker's Guide naming convention (`ponder`, `question`, `SubEthaScope`, `VogonPoetryException`) is memorable for fans, but actively hostile to discoverability. A developer searching for "register" in their IDE autocomplete gets nothing. A developer reading code sees `deepThought.question<AuthService>()` and has no idea this is dependency resolution without reading the docs. In a codebase review, a new team member sees `ponder` and thinks "is this a deliberative AI call?"

get_it succeeds partly because `getIt<T>()` is self-documenting. `sl<T>()` (service locator) is a common alias. Both are immediately comprehensible.

**Why it happens:**
Theme-driven naming is fun to design and great for README marketing, but it creates a permanent tax on every developer who uses the package. The "fun" wears off after the first week; the cognitive overhead is forever.

**How to avoid:**
Provide **both** themed and standard API names. Use standard names as the primary documented API, with themed names as aliases:
```dart
// Primary API (standard naming)
void register<T>(T Function() factory, ...);
T get<T>({String? name});

// Alias API (themed, for fans)
void ponder<T>(T Function() factory, ...) => register<T>(factory, ...);
T question<T>({String? name}) => get<T>(name: name);
```
Document both, but lead README examples with standard names. Let users discover the themed names as a fun bonus, not a requirement.

Exception: `VogonPoetryException` is fine as-is because exception types are rarely typed by hand.

**Warning signs:**
- GitHub issues asking "how do I register a service?"
- Users creating wrapper classes to hide the themed API
- Code review complaints about readability
- Low adoption despite good technical quality

**Phase to address:**
Phase 1 (API design). Retrofitting standard names later is a breaking change. Do it now.

---

### Pitfall 8: Scope Disposal Not Calling dispose() on All Service Instances

**What goes wrong:**
When a scope widget is removed from the tree, its `State.dispose()` must clean up all services registered in that scope. If a service holds resources (HTTP clients, database connections, stream subscriptions, file handles), failing to call `dispose()` on those services causes memory leaks and resource exhaustion. The current implementation only disposes services that implement `Disposable` -- but Flutter's own convention uses `ChangeNotifier.dispose()` and arbitrary cleanup callbacks. Services that extend `ChangeNotifier` (common in Flutter) won't be cleaned up.

Worse, child scopes may hold references to instances created in parent scopes. When the parent scope disposes, child scope references become dangling pointers to disposed objects.

**Why it happens:**
DI libraries typically define their own `Disposable` interface. But Flutter apps already have conventions: `ChangeNotifier` has `dispose()`, streams have `cancel()`, timers have `cancel()`. Forcing all services to implement a custom `Disposable` interface is friction that users skip.

**How to avoid:**
1. Accept a `disposeFunction` parameter during registration: `register<T>(factory, dispose: (instance) => instance.close())`
2. Auto-detect common disposable types: check for `ChangeNotifier`, your own `Disposable`, and provide an extension point
3. When a scope disposes, iterate all factories, call dispose functions, null out instances, and clear the map -- in that order
4. Document clearly: "Services in this scope will be disposed when the scope widget is removed from the tree"
5. For parent scope references: child scopes should NOT dispose services they didn't create. Only dispose what you own.

**Warning signs:**
- Memory profiler showing retained objects after navigation
- "Already disposed" errors when accessing a service after scope change
- HTTP connections remaining open after leaving a feature
- Stream subscription leaks

**Phase to address:**
Phase 1 (Core + Flutter integration). The disposal mechanism needs redesigning before Flutter integration.

---

### Pitfall 9: Breaking the `const` Constructor Convention

**What goes wrong:**
InheritedWidget subclasses should support `const` constructors for optimal performance. Flutter's element tree can skip rebuilding subtrees when the widget configuration hasn't changed, and `const` constructors enable identity-based equality checks that make this optimization work. If the scope widget can't be `const` (because it takes mutable state or non-const parameters), every parent rebuild forces a full subtree rebuild even when the scope hasn't changed.

**Why it happens:**
The scope widget needs to hold a reference to a `SubEthaScope` instance (mutable Map-based container), which prevents it from being `const`. Package authors then don't realize they've killed Flutter's const-propagation optimization for the entire subtree.

**How to avoid:**
Separate the InheritedWidget from the StatefulWidget:
- `DeepThoughtScope` (StatefulWidget) -- creates and manages the SubEthaScope instance in its State
- `_DeepThoughtInherited` (InheritedWidget, internal) -- receives the scope as a constructor parameter and is rebuilt only when the scope actually changes
- This is the standard Provider/Riverpod pattern. The StatefulWidget is the owner, the InheritedWidget is the distributor.

**Warning signs:**
- `updateShouldNotify` being called on every parent rebuild
- Profiler showing unnecessary rebuilds in scope subtrees
- Unable to use `const` keyword when instantiating the scope widget

**Phase to address:**
Phase 1 (Flutter widget integration). Architectural decision that is very hard to change later.

---

### Pitfall 10: Not Supporting Hot Reload / Hot Restart Correctly

**What goes wrong:**
During Flutter hot reload, `State` objects survive but `build()` is called again. During hot restart, everything is rebuilt from scratch. DI packages that cache state in static variables or global singletons can end up in inconsistent states after hot reload:
- Services registered in `main()` are re-registered, causing "already registered" errors
- Old service instances with stale state persist across reloads
- Factory closures capture old variable values

This is invisible in production but makes the development experience miserable. Developers who can't hot reload properly will abandon the package fast.

**Why it happens:**
Static/global state survives hot reload by design. If `DeepThought` is a global singleton (which is the current pattern, mirroring get_it's `GetIt.instance`), hot reload re-executes `main()` which tries to re-register everything.

**How to avoid:**
1. For widget-tree-scoped DI: this mostly solves itself because scope state lives in `State` objects which survive reload correctly
2. For any global/static `DeepThought` instance: support `resetIfExists` or `registerIfAbsent` patterns
3. Handle `reassemble()` in StatefulWidget State (called on hot reload): optionally refresh registrations
4. Test the hot reload path explicitly -- create a test that calls the registration code twice and verify no errors

**Warning signs:**
- "Service already registered" errors during development
- Developers needing to hot restart instead of hot reload
- Stale data appearing after code changes

**Phase to address:**
Phase 1 (Flutter widget integration). Must be tested during development of the scope widget itself.

---

## Technical Debt Patterns

Shortcuts that seem reasonable but create long-term problems.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Keeping AutoWiring stub | Less code to write now | Confuses users, creates false expectations of auto-registration capability, silently swallows errors | Never -- delete it before publishing. Dead code in a published package is a trust killer |
| Storing `_lock = Object()` as unused field | "Placeholder for future thread safety" | Misleads users into thinking concurrency is handled, dead code triggers analyzer warnings | Never -- remove it, document single-isolate-only usage |
| Using `dynamic` in AutoWiring parameter | Accepts any input without compile error | Defeats Dart's type system, hides bugs until runtime, impossible to reason about | Never |
| `DeepThoughtConfig.secrets` as plaintext Map | Quick key-value storage | Security audit failure, potential credential exposure in heap dumps, trust issue for package | Never -- remove the field entirely since it's unused |
| Skipping `isRegistered<T>()` API | Less API surface to maintain | Forces users to try/catch for conditional resolution, makes optional dependencies painful | Acceptable for v0.1, must add before v1.0 |
| Not exporting `DeepThoughtConfig` from barrel file | Keeps internal APIs hidden | Users import `src/` paths directly, coupling to internal file structure | Only if you make it truly internal. Currently it's documented in the README, so export or delete |
| Single test file for all features | Fast initial test setup | Unmaintainable at scale, hard to identify which feature broke, slow test execution | Only in v0.1 prototyping -- split before publish |

## Integration Gotchas

Common mistakes when connecting to Flutter framework features.

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Navigator / GoRouter | Tying scope push/pop to `initState`/`dispose` of individual route pages -- Navigator transition timing breaks this | Use InheritedWidget-based scopes that are *part of the widget tree* within each route's subtree. Scope lifetime follows widget lifetime automatically |
| `Theme.of(context)` and similar | Assuming your `of(context)` method can be called in `initState` -- it can't, because `dependOnInheritedWidgetOfExactType` requires the build phase | Document that `context.watch<T>()` is for `build()` only. Provide `context.read<T>()` for `initState` and event handlers using `getInheritedWidgetOfExactType` (no dependency registration) |
| `AnimationController` and `TickerProvider` | Services that need a `TickerProvider` mixin can't get one from DI because it's a mixin on `State` | Document clearly that `TickerProviderStateMixin`-dependent objects must be created in the widget layer, not registered as DI services |
| `flutter_test` (`pumpWidget`) | Test setup requires wrapping the widget under test with a scope provider. Forgetting this means `of(context)` throws | Provide a `TestDeepThoughtScope` helper or clear documentation showing the test wrapper pattern |
| Platform channels / isolates | Registering platform channel handlers as singletons -- they break across isolates | Document single-isolate limitation. Each isolate needs its own scope. Never share `SubEthaScope` instances across isolates |

## Performance Traps

Patterns that work at small scale but fail as usage grows.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Linear parent-chain traversal for every lookup | Increasing resolve time as scope depth grows | Cache resolved services at child scope level (lookup cache, not ownership) | > 5 nested scopes with frequent resolution in `build()` methods |
| `updateShouldNotify` returning `true` unconditionally | Every scope rebuild triggers rebuild of ALL consumers, cascading through the tree | Return `false` unless the scope's service registry actually changed (which it rarely does after initialization) | Any app with > 10 widgets consuming services from one scope |
| Creating new scope instances on every build | Scope widget rebuilt by parent triggers new InheritedWidget with new scope, invalidating all children | Create scope in `State.initState`, not in `build()`. Use StatefulWidget + InheritedWidget separation | Immediately -- even in small apps with animated parents |
| Resolving services in `build()` without memoization | Each `build()` call traverses the InheritedWidget lookup chain | Use `context.read<T>()` (no subscription) for services that don't change. Only `context.watch<T>()` in `build()` when rebuild-on-change is needed | > 20 widgets resolving services in a single frame |
| No lazy resolution -- eagerly creating all services at scope creation | Slow app startup, high initial memory usage | Default to lazy resolution (current behavior is correct). Only eagerly create services explicitly marked `lazy: false` | Apps with > 50 registered services |

## Security Mistakes

Domain-specific security issues for a DI package.

| Mistake | Risk | Prevention |
|---------|------|------------|
| `DeepThoughtConfig.secrets` storing plaintext credentials | Any code that resolves the config can read all secrets; visible in heap dumps and debug tools | Remove the `secrets` field entirely. DI packages should not be secret stores. Users should use `flutter_secure_storage` or platform keychains |
| Error messages exposing internal type names in production | `VogonPoetryException` messages include `$T` type info, leaking architecture details | Add a `debugMode` flag. In release builds, use generic messages. In debug, include full type info for diagnostics |
| Scope override in production builds | `SubEthaScope.override` allows replacing any service at runtime -- if exposed in production, it's a vector for tampering | Consider making `override` debug-only (assert in debug mode, no-op or throw in release) or document it as test-only API |
| No access control on scope traversal | Any widget can resolve any service from any ancestor scope, even "private" services intended for a specific feature | Consider scope isolation: a child scope can be configured to NOT fall through to the parent for certain types. Not critical for v1, but worth documenting the design direction |

## UX Pitfalls (Developer Experience)

Common developer experience mistakes in DI package design.

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Themed-only API names with no standard alternatives | Developers can't find `register`/`get`/`resolve` in autocomplete; code reviews are confusing | Provide standard names as primary API, themed names as aliases |
| Poor error messages on resolution failure | "Service of this type not found" -- which type? which scope? what's registered? | Include type name, scope name/ID, list of registered types in that scope, and parent scope chain |
| No `isRegistered<T>()` method | Developers must try/catch to check if a service exists; impossible to do optional dependency patterns | Add `isRegistered<T>()` and `isRegisteredAsync<T>()` |
| Throwing on duplicate registration with no way to override | Hot reload breaks, test setup is painful, migration from get_it is harder | Provide `allowReassignment` flag or `registerOrReplace` method |
| Exception types that are `const` but lose stack trace info | `const VogonPoetryException('...')` can't carry dynamic context like stack traces or type names | Non-const factory constructors for exceptions that carry diagnostic info; const for static messages |
| No migration guide from get_it | Developers evaluate packages by "how hard is it to switch" | README section mapping get_it APIs to deep_thought APIs: `getIt<T>()` -> `context.read<T>()`, `registerSingleton` -> `ponder`, etc. |

## "Looks Done But Isn't" Checklist

Things that appear complete but are missing critical pieces.

- [ ] **Widget scope integration:** Often missing proper disposal of scoped services when the scope widget unmounts -- verify all `Disposable` instances get `dispose()` called, and non-Disposable services with custom cleanup functions are also handled
- [ ] **InheritedWidget implementation:** Often missing the `StatefulWidget` + `InheritedWidget` separation pattern -- verify the scope is created in `State`, not rebuilt on every parent rebuild
- [ ] **BuildContext extensions:** Often missing the `read` vs `watch` distinction -- verify `read<T>()` uses `getInheritedWidgetOfExactType` (no subscription) and `watch<T>()` uses `dependOnInheritedWidgetOfExactType` (subscribes to changes)
- [ ] **Async service resolution:** Often missing concurrent-access protection -- verify two simultaneous `await locateAsync<T>()` calls for the same singleton only invoke the factory once (Completer pattern)
- [ ] **Pub.dev example:** Often missing the `example/main.dart` file that pana specifically looks for -- verify it exists at the right path and actually compiles
- [ ] **Dartdoc coverage:** Often missing on extension methods and typedef -- verify `dart doc` generates complete API docs for extensions, not just classes
- [ ] **Test coverage for scope hierarchy:** Often missing parent fallback tests, scope isolation tests, and cross-scope override tests -- verify the entire scope chain is tested, not just single-scope registration/resolution
- [ ] **Error messages:** Often missing context about what *is* registered (only saying what isn't) -- verify error messages include the scope name and list of available types
- [ ] **CHANGELOG.md:** Often missing per-version entries -- verify each published version has its own section with actual change descriptions (not just "bug fixes")
- [ ] **LICENSE file:** Often missing or using wrong license -- verify a LICENSE file exists at root and matches the `license` field in pubspec.yaml

## Recovery Strategies

When pitfalls occur despite prevention, how to recover.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Widget lifecycle vs scope mismatch (rewrite from manual scoping to InheritedWidget) | HIGH | Redesign scope management to use InheritedWidget. All existing manual scope users must migrate. Requires breaking API change (major version bump) |
| Stale InheritedWidget dependencies causing rebuilds | MEDIUM | Add `context.read<T>()` as non-subscribing alternative. Existing `context.watch<T>()` callers must audit and switch where appropriate. Non-breaking addition |
| "Context must be below" confusion | LOW | Better error messages and documentation. No code change needed if `of()` already throws. Add `maybeOf()` if missing |
| Async race condition | MEDIUM | Implement Completer pattern. Technically a behavior change (fewer factory invocations), but existing code that relied on double-invocation was already buggy |
| Circular dependency crash | LOW | Add detection guard to `locate()`. Purely additive -- existing non-circular code is unaffected |
| Low pub.dev score | MEDIUM | Systematic pana audit. Each fix is small, but there are many. Plan 1-2 days of pure pub.dev compliance work |
| Themed API discoverability | HIGH | Adding standard name aliases is non-breaking, but switching README examples and documentation is significant effort. Users who learned themed names must learn "oh there are also standard names" |
| Scope disposal not cleaning up | HIGH | Retrofitting `disposeFunction` parameter is a breaking change to the registration API. Must be a major version bump. Existing services that relied on no-cleanup will now be cleaned up (behavior change) |
| Broken hot reload | LOW | Add `registerIfAbsent` or idempotent registration. Non-breaking addition |
| Breaking `const` constructor convention | HIGH | Restructuring InheritedWidget hierarchy is a rewrite of the widget layer. If done wrong initially, fixing it forces all users to update their widget tree structure |

## Pitfall-to-Phase Mapping

How roadmap phases should address these pitfalls.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Widget lifecycle vs scope mismatch | Phase 1: Flutter Integration | Widget test: create scope widget, navigate away, verify disposal order. No manual push/pop API exists |
| Stale InheritedWidget dependencies | Phase 1: Flutter Integration | Widget test: parent rebuilds, verify child with `context.read<T>()` does NOT rebuild |
| "Context must be below" trap | Phase 1: Flutter Integration + Phase 3: Documentation | Widget test: access scope from above throws informative error. README shows correct wrapping |
| Async race condition | Phase 1: Core Fixes (before Flutter) | Unit test: two concurrent `locateAsync<T>()` calls, verify factory called exactly once |
| Circular dependency detection | Phase 1: Core Fixes (before Flutter) | Unit test: register A depending on B depending on A, verify `VogonPoetryException` with cycle description |
| Pub.dev score | Phase 2: Pub.dev Preparation | `pana .` returns >= 140/160 points. `dart pub publish --dry-run` passes with no warnings |
| Themed API discoverability | Phase 1: API Design | Standard names (`register`, `get`) exist. README leads with standard names. Themed names documented as aliases |
| Scope disposal | Phase 1: Core + Flutter Integration | Widget test: register service with `dispose` callback, remove scope widget from tree, verify callback fired |
| `const` constructor convention | Phase 1: Flutter Integration | Verify `DeepThoughtScope` uses StatefulWidget + InheritedWidget separation. InheritedWidget can be `const` |
| Hot reload support | Phase 1: Flutter Integration | Manual test: hot reload after changing a service registration, verify no "already registered" error |
| AutoWiring stub shipped | Phase 1: Core Cleanup | `AutoWiring` class deleted or properly implemented. No dead stubs in published package |
| Missing `isRegistered<T>()` | Phase 1: Core Fixes | API exists, documented, tested for both registered and unregistered types |
| `DeepThoughtConfig.secrets` | Phase 1: Core Cleanup | Field removed. No plaintext secret storage in the package |

## Sources

- [get_it #247: Widget Lifecycle and Scope Disposal Navigation Issue](https://github.com/fluttercommunity/get_it/issues/247) -- demonstrates the scope-lifecycle mismatch problem
- [get_it #158: How scopes are meant to work?](https://github.com/fluttercommunity/get_it/issues/158) -- documents async popScope confusion
- [get_it #153: A way to request the current scope](https://github.com/fluttercommunity/get_it/issues/153) -- scope tracking limitations
- [get_it #205: Memory Allocation and Performance of using Scopes](https://github.com/fluttercommunity/get_it/issues/205) -- disposal concerns
- [Flutter #62861: Widgets do not remove their dependency on InheritedWidget](https://github.com/flutter/flutter/issues/62861) -- stale dependency tracking behavior
- [Flutter API: InheritedWidget class](https://api.flutter.dev/flutter/widgets/InheritedWidget-class.html) -- official InheritedWidget documentation
- [Flutter API: dependOnInheritedWidgetOfExactType](https://api.flutter.dev/flutter/widgets/BuildContext/dependOnInheritedWidgetOfExactType.html) -- dependency registration mechanism
- [Flutter API: State.dispose](https://api.flutter.dev/flutter/widgets/State/dispose.html) -- widget disposal lifecycle
- [pub.dev: Package scores & pub points](https://pub.dev/help/scoring) -- scoring system breakdown
- [Dart: Publishing packages](https://dart.dev/tools/pub/publishing) -- official publishing guide
- [Dart: Package versioning](https://dart.dev/tools/pub/versioning) -- semver conventions
- [gskinner: Comparing GetIt, Provider, and Riverpod](https://blog.gskinner.com/archives/2021/11/flutter-comparing-getit-provider-and-riverpod.html) -- competitive landscape analysis
- [Stream: Deep Dive Into pub.dev Part Two](https://getstream.io/blog/deep-dive-pub-dev/) -- publishing best practices
- [Codebase CONCERNS.md](../.planning/codebase/CONCERNS.md) -- existing bug documentation for this project

---
*Pitfalls research for: Flutter DI package with widget-tree scoping*
*Researched: 2026-03-07*
