# Phase 1: Core Bug Fixes - Research

**Researched:** 2026-03-07
**Domain:** Dart async concurrency, DI container correctness
**Confidence:** HIGH

## Summary

Phase 1 fixes two correctness bugs in `SubEthaScope`: (1) an async singleton race condition where concurrent `locateAsync` calls can invoke the factory multiple times and return different instances, and (2) the complete absence of circular dependency detection, which causes stack overflows instead of descriptive errors.

Both bugs are well-understood with battle-tested solutions. The async race condition is solved with Dart's `Completer` class from `dart:async` -- the first caller creates a `Completer`, starts the factory, and subsequent callers await the same `Completer.future`. Circular dependency detection uses a `Set<_ServiceIdentifier>` resolution stack threaded through `locate`/`locateAsync` calls. These are the exact patterns used by `get_it` (the de facto Dart DI package) and are well-suited to Dart's single-isolate, event-loop-based concurrency model.

**Primary recommendation:** Add a `Completer<T>?` field to `_ServiceFactory` for async resolution tracking, and add a `Set<_ServiceIdentifier>` parameter (defaulting to empty) to both `locate` and `locateAsync` for cycle detection. Both fixes are localized to `SubEthaScope` with no API changes needed at the `DeepThought` facade level.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
No locked decisions -- all implementation decisions delegated to Claude's discretion.

### Claude's Discretion
- **Async race condition fix:** Use Completer pattern -- first caller creates a Completer and starts the factory, subsequent concurrent callers await the same Completer's future. This ensures the factory is invoked exactly once for lazy singletons.
- **Circular dependency detection:** Use a Set-based resolution stack -- track types currently being resolved, throw descriptive `VogonPoetryException` if a type is encountered while already in the resolution stack. Show full dependency chain in error message (e.g., "Circular dependency detected: A -> B -> C -> A").
- **Error messaging:** Include the full type chain in circular dependency errors and the type name in async race condition scenarios. Errors should be developer-friendly and actionable.
- **Test strategy:** Test concurrent access with multiple Future.wait calls for async race condition. Test direct circular (A -> B -> A) and transitive circular (A -> B -> C -> A) dependencies.

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| CORE-01 | Async singleton race condition fixed via Completer pattern (concurrent `locateAsync` calls for same lazy singleton must not invoke factory twice) | Completer pattern verified via Dart API docs and get_it reference implementation. Exact bug location identified at `SubEthaScope.locateAsync()` lines 117-124. |
| CORE-02 | Circular dependency detection during resolution (detect and throw descriptive error instead of stack overflow) | Set-based resolution stack pattern. Affects both `locate()` and `locateAsync()`. Must propagate through parent scope chain. |
| TEST-01 | Unit tests for async singleton race condition fix (concurrent access returns same instance) | `Future.wait` with multiple concurrent `locateAsync` calls. Factory invocation counter. Test with delayed factories to widen the race window. |
| TEST-02 | Unit tests for circular dependency detection (throws descriptive error) | Direct circular (A->B->A), transitive circular (A->B->C->A), and non-circular control cases. Verify error message contains full chain. |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `dart:async` | (SDK built-in) | `Completer` class for async race condition fix | Part of Dart SDK, zero dependency cost |
| `package:test` | ^1.19.2 | Unit test framework | Already in pubspec.yaml dev_dependencies |
| `package:mocktail` | ^1.0.0 | Mocking (if needed for test helpers) | Already in pubspec.yaml dev_dependencies |

### Supporting
No additional dependencies needed. Both fixes use only Dart SDK primitives.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `Completer` | `AsyncMemoizer` from `package:async` | Would add a dependency for something trivially achievable with `Completer`. Overkill. |
| `Set`-based resolution stack | Zone-local variables | Zones add complexity and are harder to reason about. A simple parameter is cleaner. |

**Installation:**
```bash
# No new packages needed -- all tools already in pubspec.yaml
dart pub get
```

## Architecture Patterns

### Affected Files
```
lib/src/
├── sub_etha_scope.dart      # PRIMARY: Both fixes go here
└── vogon_poetry_exception.dart  # No changes needed (already supports descriptive messages)
test/src/
├── sub_etha_scope_test.dart  # NEW: Direct tests for SubEthaScope fixes
└── async_factory_test.dart   # EXISTING: May add concurrent tests here
```

### Pattern 1: Completer-Guarded Async Singleton Resolution
**What:** When `locateAsync` is called for a singleton whose factory hasn't completed yet, all callers share the same `Completer.future` instead of each invoking the factory independently.
**When to use:** Any time an async factory is resolved for a `Lifecycle.singleton` that hasn't been instantiated yet.
**How it works in Dart's concurrency model:** Dart is single-threaded within an isolate. The race occurs because `await` yields execution back to the event loop. Between caller A's `instance == null` check and the factory completing, caller B can enter the same code path. The `Completer` field acts as a "claim flag" that is set synchronously before the first `await`, so subsequent callers see it immediately.

**Implementation approach:**
```dart
// In _ServiceFactory<T>, add:
Completer<T>? _asyncCompleter;

// In SubEthaScope.locateAsync<T>(), replace the singleton resolution block:
if (serviceFactory.asyncFactory != null) {
  if (serviceFactory.lifecycle == Lifecycle.transient) {
    return await serviceFactory.asyncFactory!();
  }
  // Already resolved -- return cached instance
  if (serviceFactory.instance != null) {
    return serviceFactory.instance!;
  }
  // Resolution in progress -- await the same future
  if (serviceFactory._asyncCompleter != null) {
    return serviceFactory._asyncCompleter!.future;
  }
  // First caller -- create Completer, invoke factory
  final completer = Completer<T>();
  serviceFactory._asyncCompleter = completer;
  try {
    final result = await serviceFactory.asyncFactory!();
    serviceFactory.instance = result;
    completer.complete(result);
    return result;
  } catch (e, s) {
    serviceFactory._asyncCompleter = null; // Allow retry on failure
    completer.completeError(e, s);
    rethrow;
  }
}
```

**Key detail:** The `Completer` must be set synchronously (before any `await`) so that the event loop cannot interleave another caller between the null check and the claim. This is what makes it race-safe in Dart's single-threaded model.

**Key detail:** On factory failure, clear the `_asyncCompleter` so subsequent calls can retry instead of being permanently stuck with a failed future. The `completer.completeError` propagates the error to any callers already waiting.

### Pattern 2: Set-Based Circular Dependency Detection
**What:** Pass a `Set<_ServiceIdentifier>` through the resolution call chain. Before invoking a factory, check if the current type is already in the set. If so, throw with the full chain.
**When to use:** Every call to `locate()` and `locateAsync()`.

**Implementation approach:**
```dart
// Add optional parameter to locate/locateAsync (internal, not public API):
T locate<T>({String? name, Set<_ServiceIdentifier>? resolutionStack}) {
  final key = _ServiceIdentifier(T, name);
  final stack = resolutionStack ?? <_ServiceIdentifier>{};

  // Check for circular dependency
  if (stack.contains(key)) {
    final chain = [...stack, key]
        .map((id) => id.type.toString())
        .join(' -> ');
    throw VogonPoetryException(
      'Circular dependency detected: $chain',
    );
  }

  // Add current type to stack before invoking factory
  stack.add(key);

  // ... rest of resolution logic, passing stack to any nested calls
}
```

**Important:** The resolution stack must also be passed through parent scope lookups (`parent!.locate<T>(name: name, resolutionStack: stack)`), because circular dependencies can span scopes.

**Important:** The `locate` and `locateAsync` public signatures use `Set<_ServiceIdentifier>?` as an internal parameter. Since `_ServiceIdentifier` is private to the file, external callers cannot construct this parameter -- it's effectively invisible to the public API. This is clean Dart encapsulation.

### Pattern 3: Chain Representation in Error Messages
**What:** To show the full dependency chain (e.g., "A -> B -> C -> A"), maintain ordering in the resolution stack.
**Consideration:** A `Set` doesn't preserve insertion order in theory, but Dart's `LinkedHashSet` (the default `Set` implementation) DOES preserve insertion order. So `<_ServiceIdentifier>{}` will naturally maintain the chain order.

**Alternative:** Use a `List<_ServiceIdentifier>` for the chain display and a `Set<_ServiceIdentifier>` for O(1) lookup. This is more explicit:
```dart
T locate<T>({
  String? name,
  List<_ServiceIdentifier>? resolutionChain,
  Set<_ServiceIdentifier>? resolutionSet,
}) {
  final key = _ServiceIdentifier(T, name);
  final chain = resolutionChain ?? <_ServiceIdentifier>[];
  final seen = resolutionSet ?? <_ServiceIdentifier>{};

  if (seen.contains(key)) {
    final display = [...chain, key]
        .map((id) => id.name != null ? '${id.type}(${id.name})' : '${id.type}')
        .join(' -> ');
    throw VogonPoetryException(
      'Circular dependency detected: $display',
    );
  }

  chain.add(key);
  seen.add(key);
  // ... resolution logic
}
```

**Recommendation:** Use the simpler single-`Set` approach. Dart's default `Set` is `LinkedHashSet` which preserves insertion order, so we get both O(1) lookup and ordered chain display from one data structure. Document this reliance on insertion-order explicitly in a comment.

### Anti-Patterns to Avoid
- **Zone-based resolution tracking:** Using `Zone` values to thread the resolution stack is fragile, hard to test, and doesn't work well with `async`/`await` boundaries. Pass it explicitly.
- **Global/static resolution stack:** A static `Set` on `SubEthaScope` would break with concurrent async resolutions (two unrelated async resolution chains could false-positive as circular). The stack must be per-resolution-chain.
- **Mutex/Lock patterns:** Dart is single-threaded within an isolate. The `_lock = Object()` field in the current code does nothing. Don't add `package:synchronized` or similar. The `Completer` approach is the idiomatic Dart solution.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Async race guard | Custom lock/mutex mechanism | `Completer<T>` from `dart:async` | Dart is single-threaded; Completer is the idiomatic primitive. Locks are for multi-threaded runtimes. |
| Ordered set | Custom linked list | Dart's default `Set` (`LinkedHashSet`) | It already preserves insertion order by default. |

**Key insight:** Dart's single-threaded event loop means the race condition is purely about interleaving at `await` points, not actual thread safety. The fix is therefore simpler than in multi-threaded languages -- you just need to claim the slot synchronously before the first `await`.

## Common Pitfalls

### Pitfall 1: Setting Completer After Await
**What goes wrong:** If you write `serviceFactory.instance = await factory(); completer.complete(instance);` without setting the completer field first, there's still a race window between the null check and the await.
**Why it happens:** Developers think of `await` as "just waiting" but in Dart it yields to the event loop, allowing other microtasks and events to execute.
**How to avoid:** Set `serviceFactory._asyncCompleter = completer` synchronously BEFORE the first `await` in the resolution path.
**Warning signs:** Intermittent test failures where concurrent `locateAsync` calls return different instances.

### Pitfall 2: Forgetting to Clear Completer on Error
**What goes wrong:** If the async factory throws and you don't clear `_asyncCompleter`, all future calls to `locateAsync` for that type will return the failed future's error. The singleton becomes permanently broken.
**Why it happens:** Happy-path-only implementation.
**How to avoid:** In the `catch` block, set `serviceFactory._asyncCompleter = null` before rethrowing. Also call `completer.completeError(e, s)` to propagate to waiters.
**Warning signs:** After a transient error (e.g., network timeout), the service can never be created even if the underlying issue is resolved.

### Pitfall 3: Resolution Stack Not Passed Through Parent Scope
**What goes wrong:** If `locate` delegates to `parent!.locate()` without forwarding the resolution stack, circular dependencies that span parent-child scopes won't be detected.
**Why it happens:** The parent lookup is on a different `SubEthaScope` instance, easy to forget the stack parameter.
**How to avoid:** Always pass `resolutionStack` (or equivalent) when delegating to `parent`.
**Warning signs:** Stack overflow when a child scope service depends on a parent scope service that depends back on a child scope service.

### Pitfall 4: VogonPoetryException const Constructor
**What goes wrong:** `VogonPoetryException` has a `const` constructor, but circular dependency error messages include the dynamic type chain string. Existing code uses `const VogonPoetryException(...)` in some places.
**Why it happens:** Dynamic strings can't be const.
**How to avoid:** New throws with dynamic messages use non-const constructor (`throw VogonPoetryException(...)` without `const`). Don't change existing `const` throws that use static strings.
**Warning signs:** Compile error if you try `const VogonPoetryException('Circular: $chain')`.

### Pitfall 5: Testing Async Race Conditions With Insufficient Delay
**What goes wrong:** Tests use factories that return instantly (synchronous `Future.value`), so the race window never opens and the test passes even without the fix.
**Why it happens:** Synchronous futures complete in the same microtask, so concurrent calls don't actually interleave.
**How to avoid:** Use `Future.delayed(Duration(...), () => value)` in test factories to ensure the event loop actually yields between callers. Verify the factory invocation count, not just the instance identity.
**Warning signs:** Test passes with AND without the Completer fix.

### Pitfall 6: Named Services in Circular Dependency Chains
**What goes wrong:** If the circular dependency check only considers the `Type` but not the `name`, named registrations could create false positives or miss real cycles.
**Why it happens:** `_ServiceIdentifier` includes both `type` and `name`, but the resolution stack check might only track `Type`.
**How to avoid:** Use `_ServiceIdentifier` (not raw `Type`) as the element type in the resolution stack. This is already the natural choice since it's the map key.
**Warning signs:** False "circular dependency" errors when two services of the same type but different names depend on each other.

## Code Examples

### Example 1: Reproducing the Current Race Condition Bug
```dart
// This test FAILS with current code (factory invoked twice)
test('concurrent locateAsync returns same singleton instance', () async {
  final scope = SubEthaScope();
  var factoryCallCount = 0;

  await scope.registerAsync<String>(
    () async {
      factoryCallCount++;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return 'singleton-value';
    },
  );

  // Launch two concurrent resolutions
  final results = await Future.wait([
    scope.locateAsync<String>(),
    scope.locateAsync<String>(),
  ]);

  expect(results[0], same(results[1]));  // Same instance
  expect(factoryCallCount, equals(1));    // Factory called once
});
```

### Example 2: Reproducing Circular Dependency Stack Overflow
```dart
// This currently causes a stack overflow instead of a descriptive error
test('circular dependency throws VogonPoetryException', () {
  final scope = SubEthaScope();

  // A depends on B
  scope.register<A>(() => A(scope.locate<B>()));
  // B depends on A
  scope.register<B>(() => B(scope.locate<A>()));

  expect(
    () => scope.locate<A>(),
    throwsA(
      isA<VogonPoetryException>().having(
        (e) => e.cause,
        'cause',
        contains('Circular dependency detected'),
      ),
    ),
  );
});
```

### Example 3: Transitive Circular Dependency
```dart
test('transitive circular dependency detected', () {
  final scope = SubEthaScope();

  scope.register<A>(() => A(scope.locate<B>()));
  scope.register<B>(() => B(scope.locate<C>()));
  scope.register<C>(() => C(scope.locate<A>()));

  expect(
    () => scope.locate<A>(),
    throwsA(
      isA<VogonPoetryException>().having(
        (e) => e.cause,
        'cause',
        allOf(
          contains('Circular dependency detected'),
          contains('A'),
          contains('B'),
          contains('C'),
        ),
      ),
    ),
  );
});
```

### Example 4: Non-Circular Dependencies Must Still Work
```dart
// Control test: linear dependency chain should NOT trigger false positive
test('linear dependency chain resolves correctly', () {
  final scope = SubEthaScope();

  scope.register<C>(() => C());
  scope.register<B>(() => B(scope.locate<C>()));
  scope.register<A>(() => A(scope.locate<B>()));

  expect(scope.locate<A>(), isA<A>());
});
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| No async guard | `Completer`-guarded resolution | Standard since Dart 2.0 | Prevents duplicate factory invocation |
| Stack overflow on cycles | Set-based resolution stack | Common DI pattern | Descriptive errors instead of crashes |
| `package:synchronized` locks | No locks needed | N/A (Dart was always single-threaded per isolate) | Simpler code, no external deps |

**Deprecated/outdated:**
- The `_lock = Object()` field in current `SubEthaScope` does nothing and should be removed. Dart doesn't need object-level locks within a single isolate.

## Open Questions

1. **Should `_asyncCompleter` be cleared after successful resolution?**
   - What we know: After `instance` is set, the `Completer` is no longer needed. Keeping it alive wastes memory.
   - What's unclear: Whether clearing it could cause issues if someone holds a reference to `_asyncCompleter.future` that hasn't resolved yet (edge case with slow listeners).
   - Recommendation: Clear it. Once `instance` is set, subsequent calls hit the `instance != null` fast path and never check the Completer. Any already-awaited futures will have resolved.

2. **Should circular dependency detection happen at registration time or resolution time?**
   - What we know: Registration-time detection would require knowing dependency graphs upfront, which isn't possible with lazy factory closures (you can't inspect what a closure will call). `get_it` does it at registration time only for explicit `dependsOn` declarations.
   - What's unclear: Nothing -- this is clear-cut for our case.
   - Recommendation: Resolution-time detection is the only viable approach for closure-based factories. This is what the CONTEXT.md already specifies.

3. **Should the `_lock` field be removed in this phase?**
   - What we know: It does nothing. It's dead code.
   - What's unclear: Whether removing it is scope creep for this phase (which is "Core Bug Fixes" not "Core Cleanup").
   - Recommendation: Leave it for Phase 2 (Core Cleanup). This phase should be surgically focused on the two bugs.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `package:test` ^1.19.2 |
| Config file | None (uses defaults, analysis_options.yaml for lints) |
| Quick run command | `dart test test/src/sub_etha_scope_test.dart` |
| Full suite command | `dart test` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CORE-01 | Concurrent `locateAsync` for same singleton returns identical instance, factory invoked once | unit | `dart test test/src/sub_etha_scope_test.dart -x` | No -- Wave 0 |
| CORE-01 | Error in async factory propagates to all waiters and allows retry | unit | `dart test test/src/sub_etha_scope_test.dart -x` | No -- Wave 0 |
| CORE-02 | Direct circular dependency (A->B->A) throws VogonPoetryException with chain | unit | `dart test test/src/sub_etha_scope_test.dart -x` | No -- Wave 0 |
| CORE-02 | Transitive circular dependency (A->B->C->A) throws with full chain | unit | `dart test test/src/sub_etha_scope_test.dart -x` | No -- Wave 0 |
| CORE-02 | Non-circular linear dependency chain resolves without false positive | unit | `dart test test/src/sub_etha_scope_test.dart -x` | No -- Wave 0 |
| CORE-02 | Circular dependency across parent-child scopes detected | unit | `dart test test/src/sub_etha_scope_test.dart -x` | No -- Wave 0 |
| TEST-01 | Tests for CORE-01 exist and pass | unit | `dart test test/src/sub_etha_scope_test.dart -x` | No -- Wave 0 |
| TEST-02 | Tests for CORE-02 exist and pass | unit | `dart test test/src/sub_etha_scope_test.dart -x` | No -- Wave 0 |

### Sampling Rate
- **Per task commit:** `dart test test/src/sub_etha_scope_test.dart`
- **Per wave merge:** `dart test`
- **Phase gate:** Full suite green (`dart test && dart analyze --fatal-infos`)

### Wave 0 Gaps
- [ ] `test/src/sub_etha_scope_test.dart` -- new file for direct SubEthaScope unit tests (covers CORE-01, CORE-02, TEST-01, TEST-02)
- [ ] Helper classes for tests (e.g., simple `A`, `B`, `C` classes that accept dependencies)

## Sources

### Primary (HIGH confidence)
- [Completer class - dart:async library](https://api.flutter.dev/flutter/dart-async/Completer-class.html) - API surface, `complete`/`completeError`/`isCompleted`
- [Concurrency in Dart - dart.dev](https://dart.dev/language/concurrency) - Single-threaded event loop model, no shared memory between isolates
- Direct source code analysis of `lib/src/sub_etha_scope.dart` - Confirmed exact bug locations and data structures

### Secondary (MEDIUM confidence)
- [get_it source code](https://github.com/fluttercommunity/get_it/blob/master/lib/get_it_impl.dart) - `pendingResult` pattern for async singleton race prevention, verified via WebFetch
- [get_it issue #210](https://github.com/flutter-it/get_it/issues/210) - Known race condition patterns in Dart DI

### Tertiary (LOW confidence)
- None -- all findings verified against primary sources

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Uses only dart:async (SDK built-in) and existing test dependencies
- Architecture: HIGH - Completer pattern and Set-based cycle detection are well-documented, verified against get_it reference implementation and Dart API docs
- Pitfalls: HIGH - Derived from direct analysis of the source code and Dart's concurrency model

**Research date:** 2026-03-07
**Valid until:** Indefinite -- Dart's Completer API and concurrency model are stable, mature primitives
