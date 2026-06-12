# Phase 2: Core Cleanup - Research

**Researched:** 2026-03-07
**Domain:** Dart package housekeeping -- dead code removal, dependency hygiene, API gap
**Confidence:** HIGH

## Summary

This is a straightforward housekeeping phase with four well-defined requirements. The codebase investigation confirms: (1) `AutoWiring` and `DeepThoughtConfig` are only referenced by each other and by documentation/planning files -- no production code depends on them outside their own files, (2) the `logging` package is imported but undeclared in `pubspec.yaml`, and (3) `DeepThought` has no `reset()` method while `SubEthaScope.reset()` already exists at line 252 with proper `Disposable` cleanup logic.

The only area requiring design judgment is `DeepThought.reset()` -- specifically whether it should also clear `errorNotifier`, reset the logger, or cascade to child scopes. These are flagged as Claude's discretion in CONTEXT.md.

**Primary recommendation:** Execute as three clean tasks -- dependency fix, stub removal, reset method addition -- with `dart analyze --fatal-infos` as the verification gate for each.

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions
- Clean delete both `auto_wiring.dart` and `deep_thought_config.dart` -- no trace left in the codebase
- Remove any imports or references to either class anywhere
- No TODO comments, no backlog entry -- auto-wiring concept is explicitly out of scope (PROJECT.md) and doesn't need tracking
- Barrel file (`lib/deep_thought_injector.dart`) is already correct -- neither stub was exported
- `DeepThought.reset()` delegates to `_scope.reset()` -- that's the core behavior
- Must be idempotent -- calling reset() on an already-empty scope is a no-op, no exceptions
- Export surface review (SubEthaScope exposing internals) flagged for Phase 3 API surface work, not this phase
- Add `logging: ^1.2.0` to pubspec.yaml `dependencies` section (runtime dep, not dev)
- Don't touch the existing logging approach (static Logger + setter pattern) -- just declare the dependency
- The logging pattern itself can be revisited in Phase 3 if needed
- TDD for `reset()` only -- write failing tests first, then implement
- Tests go in existing `deep_thought_injector_test.dart` file (new test group)
- Stub removal doesn't need tests -- `dart analyze` passing proves it's clean

### Claude's Discretion
- Whether `reset()` also clears `errorNotifier` and resets logger (delegate-only vs full reset -- convention-based decision)
- Whether `reset()` cascades to child scopes (parent-only vs recursive -- widget lifecycle context)
- Whether `reset()` logs the event (consistent with existing logging vs silent deliberate action)
- Test depth for `reset()` -- basic delegation vs edge cases (idempotency, re-registration after reset)

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope

</user_constraints>

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| CORE-03 | `logging` dependency properly declared in pubspec.yaml | Verified: `logging` is imported in `deep_thought_injector.dart` line 5 but missing from pubspec.yaml. `dart analyze` already flags this as `depend_on_referenced_packages`. Adding `logging: ^1.2.0` under `dependencies:` resolves it. |
| CORE-04 | `AutoWiring` stub removed from codebase | Verified: `auto_wiring.dart` only references itself and `deep_thought_config.dart`. No production code imports it. Only documentation/planning files mention it. Clean delete is safe. |
| CORE-05 | `DeepThoughtConfig` stub removed from codebase | Verified: `deep_thought_config.dart` is only imported by `auto_wiring.dart`. README.md has a code example referencing it (must be removed). No tests exist for either stub. Clean delete is safe. |
| CORE-06 | `DeepThought.reset()` public method added (delegates to `SubEthaScope.reset()`) | Verified: `SubEthaScope.reset()` exists at line 252 -- disposes `Disposable` services and clears `_factories`. `DeepThought` has no `reset()` method currently. Adding delegation is trivial. |

</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `logging` | ^1.2.0 | Structured logging via `Logger` class | Dart team's official logging package (dart.dev publisher). Already imported in `deep_thought_injector.dart`. User locked version constraint. |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `test` | ^1.19.2 | Unit testing | Already declared as dev_dependency. Used for reset() TDD. |
| `mocktail` | ^1.0.0 | Mocking | Already declared as dev_dependency. Available if needed for reset() tests but likely not required (real SubEthaScope is fine). |
| `very_good_analysis` | ^5.1.0 | Lint rules | Already declared. `dart analyze --fatal-infos` is the verification gate. |

### Alternatives Considered
None. This phase has no library choices to make -- all decisions are locked.

**Installation (new):**
```bash
# No new packages to install beyond adding logging to pubspec.yaml
dart pub get
```

## Architecture Patterns

### Current File Structure (what changes)
```
lib/
├── deep_thought_injector.dart    # Barrel file -- NO CHANGES (stubs were never exported)
└── src/
    ├── auto_wiring.dart          # DELETE (CORE-04)
    ├── deep_thought_config.dart  # DELETE (CORE-05)
    ├── deep_thought_injector.dart # ADD reset() method, FIX duplicate import (CORE-06)
    ├── sub_etha_scope.dart       # NO CHANGES (reset() already exists, _lock removal optional)
    └── vogon_poetry_exception.dart # NO CHANGES
test/
└── src/
    ├── deep_thought_injector_test.dart  # ADD reset() test group (CORE-06)
    ├── sub_etha_scope_test.dart         # NO CHANGES
    └── async_factory_test.dart          # NO CHANGES
```

### Pattern 1: Facade Delegation
**What:** `DeepThought` wraps `SubEthaScope` and delegates all operations, adding logging and error notification.
**When to use:** `reset()` follows this exact pattern -- delegate to `_scope.reset()`, optionally add logging.
**Example:**
```dart
// Source: lib/src/deep_thought_injector.dart (existing pattern)
// question() delegates to _scope.locate() and adds logging + error handling
T question<T>({String? name}) {
  try {
    return _scope.locate<T>(name: name);
  } catch (e, s) {
    _logger.severe('Error locating service of type $T: $e\nStack Trace: $s');
    // ... error notification ...
  }
}
```

### Pattern 2: TDD in Existing Test Groups
**What:** Add test groups to existing test files rather than creating new files.
**When to use:** Per CONTEXT.md, reset() tests go in `deep_thought_injector_test.dart` as a new `group('reset', ...)`.
**Example:**
```dart
// Source: test/src/deep_thought_injector_test.dart (existing structure)
void main() {
  group('DeepThought', () {
    // ... existing tests ...
    group('reset', () {
      test('clears all registrations', () {
        // register -> reset -> question throws
      });
    });
  });
}
```

### Anti-Patterns to Avoid
- **Partial stub removal:** Leaving orphaned imports, references in comments, or dangling documentation. The grep confirms references exist in `README.md`, `CLAUDE.md`, `AGENTS.md`, and planning docs. Source files must be fully clean; documentation updates are within scope.
- **Over-engineering reset():** This is a delegation method. Don't add state machine patterns, async reset, or event broadcasting. Keep it simple.
- **Fixing lint warnings beyond scope:** `dart analyze` currently shows ~40 infos/warnings. This phase only needs to ensure zero *new* issues from our changes and removal of issues from deleted files. Existing warnings are not this phase's problem.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Dependency declaration | Custom build scripts | `pubspec.yaml` `dependencies:` section | Standard Dart package management |
| Cleanup verification | Manual file checking | `dart analyze --fatal-infos` | Catches undeclared deps, unused imports, missing refs automatically |
| Service disposal | Custom disposal tracking | `SubEthaScope.reset()` | Already handles Disposable interface check + factory map clearing |

**Key insight:** `SubEthaScope.reset()` already does the hard work -- iterates factories, checks for `Disposable`, calls `dispose()`, clears the map. `DeepThought.reset()` just delegates.

## Common Pitfalls

### Pitfall 1: Duplicate Import in deep_thought_injector.dart
**What goes wrong:** Line 3 imports `package:deep_thought_injector/src/sub_etha_scope.dart` and line 6 imports `sub_etha_scope.dart` (relative). These are the same file. `dart analyze` already flags this as `duplicate_import`.
**Why it happens:** Historical layering of imports during development.
**How to avoid:** Remove line 6 (the relative import). Keep the `package:` import per `always_use_package_imports` lint rule.
**Warning signs:** `dart analyze` output shows `duplicate_import` warning.

### Pitfall 2: README References to DeepThoughtConfig
**What goes wrong:** `README.md` lines 76-79 contain a code example that imports and uses `DeepThoughtConfig`. If the class is deleted but README is not updated, the documentation references a nonexistent class.
**Why it happens:** Documentation is easy to forget when deleting code.
**How to avoid:** Remove the "Configuration & Overrides" section from README.md (lines 73-80).
**Warning signs:** Grep for `DeepThoughtConfig` across the entire repo after deletion.

### Pitfall 3: CLAUDE.md References to Deleted Classes
**What goes wrong:** `CLAUDE.md` documents `AutoWiring` and `DeepThoughtConfig` in the Architecture section. After deletion, this documentation is misleading for future Claude Code sessions.
**Why it happens:** Project documentation references internal classes.
**How to avoid:** Update CLAUDE.md Architecture section to remove mentions of both deleted classes.
**Warning signs:** Stale class descriptions in project docs.

### Pitfall 4: Forgetting pubspec.yaml Needs a dependencies Section
**What goes wrong:** The current `pubspec.yaml` has NO `dependencies:` section at all -- only `dev_dependencies:`. Adding `logging` requires creating the section, not just adding a line.
**Why it happens:** The project was generated by Very Good CLI which doesn't add runtime deps by default.
**How to avoid:** Add `dependencies:` section above `dev_dependencies:` with `logging: ^1.2.0`.
**Warning signs:** YAML parse errors if indentation is wrong.

### Pitfall 5: reset() Idempotency With Empty Scope
**What goes wrong:** Calling `reset()` on a scope with no registrations should be a no-op. `SubEthaScope.reset()` already handles this correctly (iterating an empty map and clearing it is safe), but tests should verify it.
**Why it happens:** Edge case that's easy to skip.
**How to avoid:** Include an idempotency test: `reset()` on fresh `DeepThought()` does not throw.
**Warning signs:** Exception from empty iteration or null access.

## Code Examples

### DeepThought.reset() Implementation
```dart
// Recommended implementation -- follows existing facade delegation pattern
// reset() delegates to _scope.reset(), consistent with question() -> locate()

/// Resets the injector, disposing all registered services and clearing
/// all registrations.
void reset() {
  _scope.reset();
}
```

### DeepThought.reset() With Optional Logging (Claude's Discretion)
```dart
// Option A: Silent delegation (recommended -- reset is a deliberate action)
void reset() {
  _scope.reset();
}

// Option B: Logged delegation (consistent with question/ponder pattern)
void reset() {
  _logger.info('Resetting Deep Thought injector');
  _scope.reset();
}
```

### Discretion Recommendation: errorNotifier and Logger
```dart
// Recommendation: DO NOT clear errorNotifier or reset logger.
// Rationale: errorNotifier is set by the consumer and persists across
// resets (it's a configuration concern, not a registration concern).
// Logger is static and shared across all instances -- resetting it
// would affect other DeepThought instances.
```

### Discretion Recommendation: Child Scope Cascading
```dart
// Recommendation: DO NOT cascade to child scopes.
// Rationale: DeepThought does not track child scopes. createChildScope()
// returns a new DeepThought instance -- the parent has no reference to it.
// There is no child scope list to iterate. Cascading is architecturally
// impossible without adding a _children tracking field, which is out of
// scope for this phase.
```

### pubspec.yaml Change
```yaml
# Add dependencies section above dev_dependencies
dependencies:
  logging: ^1.2.0

dev_dependencies:
  mocktail: ^1.0.0
  test: ^1.19.2
  very_good_analysis: ^5.1.0
```

### Test Pattern for reset()
```dart
// Source: follows existing test patterns in deep_thought_injector_test.dart
group('reset', () {
  test('clears all registrations so services are no longer resolvable', () {
    final dt = DeepThought()
      ..ponder<TestService>(() => TestService(42));
    expect(dt.question<TestService>().value, equals(42));

    dt.reset();

    expect(
      () => dt.question<TestService>(),
      throwsA(isA<VogonPoetryException>()),
    );
  });

  test('is idempotent -- calling reset on empty scope does not throw', () {
    final dt = DeepThought();
    expect(() => dt.reset(), returnsNormally);
  });

  test('allows re-registration after reset', () {
    final dt = DeepThought()
      ..ponder<TestService>(() => TestService(1));
    dt.reset();
    dt.ponder<TestService>(() => TestService(2));
    expect(dt.question<TestService>().value, equals(2));
  });
});
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Undeclared transitive deps | Explicit `dependencies:` in pubspec.yaml | Dart 2.x era lint rules | `depend_on_referenced_packages` is an info-level lint that will become a warning/error |
| Dead stub code left "for later" | Remove dead code, track ideas in planning docs only | N/A -- project decision | Eliminates 12 analyzer warnings from deleted files |

**Deprecated/outdated:**
- `AutoWiring` concept: Out of scope per PROJECT.md (dart:mirrors banned in Flutter, code-gen not in scope)
- `DeepThoughtConfig`: Not needed -- DI packages should not be configuration holders

## Existing Issues to Fix Opportunistically

These are pre-existing `dart analyze` findings in files we're already touching:

| File | Issue | Fix |
|------|-------|-----|
| `deep_thought_injector.dart:6` | `duplicate_import` -- relative import of sub_etha_scope | Remove line 6 |
| `deep_thought_injector.dart:4` | `unused_import` -- vogon_poetry_exception (used indirectly via barrel) | Will resolve itself if import style is cleaned up, but this is actually used in catch blocks -- keep it |
| `sub_etha_scope.dart:36` | `unused_field` -- `_lock` field | Can remove but technically outside scope. Note for planner. |

**Recommendation for planner:** Fix the duplicate import in `deep_thought_injector.dart` since we're already editing the file. The `_lock` field in `sub_etha_scope.dart` is a separate concern -- leave it unless the planner wants to bundle it.

## Open Questions

1. **Should `_lock` field in SubEthaScope be removed?**
   - What we know: `_lock` is an `Object()` at line 36 that is never used. `dart analyze` flags it as `unused_field`.
   - What's unclear: Whether to include this in the "cleanup" scope or defer.
   - Recommendation: Include it if we're already verifying `dart analyze` passes. Removing it is a one-line change and reduces analyzer noise. But it's not one of the four requirements, so the planner should decide.

2. **Should AGENTS.md and planning docs be updated?**
   - What we know: `AGENTS.md`, `CLAUDE.md`, `README.md`, and multiple planning docs reference `AutoWiring` and `DeepThoughtConfig`.
   - What's unclear: Which docs are in-scope for this phase.
   - Recommendation: Update `CLAUDE.md` and `README.md` (consumer-facing). Planning docs are historical records and don't need updating. `AGENTS.md` is auto-generated context.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `package:test` 1.19.2+ |
| Config file | None (standard Dart test runner, no config file needed) |
| Quick run command | `dart test test/src/deep_thought_injector_test.dart` |
| Full suite command | `dart test` |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CORE-03 | logging dependency resolves | smoke | `dart pub get && dart analyze --fatal-infos 2>&1 \| grep -c depend_on_referenced_packages` (should be 0) | N/A -- analyzer verification |
| CORE-04 | AutoWiring class removed | smoke | `dart analyze --fatal-infos` (no auto_wiring.dart errors) | N/A -- file deletion verification |
| CORE-05 | DeepThoughtConfig class removed | smoke | `dart analyze --fatal-infos` (no deep_thought_config.dart errors) | N/A -- file deletion verification |
| CORE-06 | DeepThought.reset() works | unit | `dart test test/src/deep_thought_injector_test.dart` | Exists but no reset tests yet -- Wave 0 |

### Sampling Rate
- **Per task commit:** `dart test test/src/deep_thought_injector_test.dart && dart analyze --fatal-infos`
- **Per wave merge:** `dart test && dart analyze --fatal-infos`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `test/src/deep_thought_injector_test.dart` -- add `group('reset', ...)` with tests for CORE-06 (TDD -- tests written first, then implementation)
- No new test files needed
- No framework install needed (already configured)

## Sources

### Primary (HIGH confidence)
- **Source code inspection** -- `lib/src/deep_thought_injector.dart`, `lib/src/sub_etha_scope.dart`, `lib/src/auto_wiring.dart`, `lib/src/deep_thought_config.dart`, `pubspec.yaml` -- all read directly
- **`dart analyze --fatal-infos`** -- run against current codebase, output captured and analyzed
- **`dart pub deps`** -- confirms logging is NOT in resolved dependency tree
- **pub.dev/packages/logging** -- confirmed latest version 1.3.0 (requires Dart 3.4), version 1.2.0 (requires Dart 2.19). Constraint `^1.2.0` is correct for SDK `>=3.0.0 <4.0.0`.

### Secondary (MEDIUM confidence)
- None needed -- this is a code cleanup phase, all facts verified by direct source inspection.

### Tertiary (LOW confidence)
- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- logging package version verified on pub.dev, constraint validated against project SDK
- Architecture: HIGH -- all files read, all references grepped, all analyzer output captured
- Pitfalls: HIGH -- duplicate import confirmed, README reference confirmed, pubspec structure verified

**Research date:** 2026-03-07
**Valid until:** Indefinite -- this is a cleanup phase with no moving-target dependencies
