# Roadmap: Deep Thought Injector

## Overview

This roadmap takes Deep Thought Injector from a solid pure-Dart DI core to a published Flutter package with widget-scoped dependency injection. The journey is: fix known core bugs, clean up stubs, build the widget integration layer (the entire value proposition), prove it works with tests, then package it for pub.dev with documentation and metadata. The core bugs must be fixed before widget integration amplifies them. The widget layer must exist before documentation can describe it. Nine phases, each delivering one verifiable capability.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Core Bug Fixes** - Fix async singleton race condition and add circular dependency detection with tests proving correctness
- [ ] **Phase 2: Core Cleanup** - Remove stubs, fix undeclared dependency, add public reset method
- [ ] **Phase 3: API Surface** - Add standard registration/resolution aliases and utility methods alongside themed names
- [ ] **Phase 4: Widget Provider Foundation** - Build DeepThoughtProvider with InheritedWidget and automatic parent-child scope chaining
- [ ] **Phase 5: BuildContext Consumer API** - Add BuildContext extensions for ergonomic service resolution from the widget tree
- [ ] **Phase 6: Scoped Lifecycle and Disposal** - Wire Lifecycle.scoped to widget scope lifetime with automatic disposal on unmount
- [ ] **Phase 7: Widget Test Suite** - Comprehensive widget tests covering provider lifecycle, nesting, scoped instances, and context extensions
- [ ] **Phase 8: Pub.dev Metadata and Analysis** - Prepare pubspec.yaml metadata and pass dart pub publish dry-run with zero warnings
- [ ] **Phase 9: Documentation and Examples** - Dartdoc coverage, example app, README with get_it comparison, and CHANGELOG

## Phase Details

### Phase 1: Core Bug Fixes
**Goal**: The core DI container handles concurrent async resolution and circular dependencies correctly, with tests proving both
**Depends on**: Nothing (first phase)
**Requirements**: CORE-01, CORE-02, TEST-01, TEST-02
**Success Criteria** (what must be TRUE):
  1. Two concurrent `locateAsync` calls for the same lazy singleton return the identical instance (factory invoked exactly once)
  2. Registering services with circular dependencies and resolving them throws a descriptive `VogonPoetryException` instead of a stack overflow
  3. Unit tests for both behaviors pass and cover edge cases (nested async, transitive circular deps)
**Plans:** 2 plans

Plans:
- [ ] 01-01-PLAN.md — Fix async singleton race condition with Completer pattern (TDD)
- [ ] 01-02-PLAN.md — Add circular dependency detection with Set-based resolution stack (TDD)

### Phase 2: Core Cleanup
**Goal**: The codebase is free of dead stubs and has correct dependency declarations, ready to build new features on
**Depends on**: Phase 1
**Requirements**: CORE-03, CORE-04, CORE-05, CORE-06
**Success Criteria** (what must be TRUE):
  1. `logging` package is declared in pubspec.yaml and `dart pub get` resolves without warnings
  2. `AutoWiring` class and `DeepThoughtConfig` class no longer exist in the codebase (no references, no imports)
  3. `DeepThought.reset()` is a public method that delegates to `SubEthaScope.reset()` and clears all registrations in scope
  4. `dart analyze` passes with zero errors after cleanup
**Plans**: TBD

Plans:
- [ ] 02-01: TBD
- [ ] 02-02: TBD

### Phase 3: API Surface
**Goal**: Developers can use standard DI naming conventions (register/get) alongside themed names, and can verify and query registrations
**Depends on**: Phase 2
**Requirements**: API-01, API-02, API-03, API-04
**Success Criteria** (what must be TRUE):
  1. `register()` and `registerAsync()` work identically to `ponder()` and `ponderAsync()` (same parameters, same behavior)
  2. `get<T>()` and `getAsync<T>()` work identically to `question<T>()` and `questionAsync<T>()` (same parameters, same behavior)
  3. `verify()` resolves all sync registrations at startup and throws descriptive error listing which registration failed and why
  4. `isRegistered<T>()` returns true/false correctly for registered and unregistered types, including named registrations
**Plans**: TBD

Plans:
- [ ] 03-01: TBD
- [ ] 03-02: TBD

### Phase 4: Widget Provider Foundation
**Goal**: Flutter developers can wrap widget subtrees with DeepThoughtProvider to create DI scopes that automatically chain into parent-child hierarchies
**Depends on**: Phase 3
**Requirements**: WIDG-01, WIDG-02
**Success Criteria** (what must be TRUE):
  1. `DeepThoughtProvider` is a StatefulWidget that creates a `DeepThought` scope and exposes it to descendants via InheritedWidget
  2. A `DeepThoughtProvider` nested inside another `DeepThoughtProvider` automatically establishes a parent-child scope relationship (child scope falls back to parent for unregistered types)
  3. The provider accepts a registration callback where users register services for that scope
**Plans**: TBD

Plans:
- [ ] 04-01: TBD
- [ ] 04-02: TBD

### Phase 5: BuildContext Consumer API
**Goal**: Developers can resolve services from the nearest scope ancestor using familiar BuildContext extension syntax
**Depends on**: Phase 4
**Requirements**: WIDG-03, WIDG-04, WIDG-05
**Success Criteria** (what must be TRUE):
  1. `context.question<T>()` resolves a service from the nearest `DeepThoughtProvider` ancestor and throws if not found
  2. `context.maybeQuestion<T>()` returns null instead of throwing when no service or no provider is found
  3. `context.deepThought` returns the `DeepThought` instance from the nearest provider for direct scope manipulation
  4. All three extensions throw a clear error when called from a context that has no `DeepThoughtProvider` ancestor (except `maybeQuestion` which returns null)
**Plans**: TBD

Plans:
- [ ] 05-01: TBD
- [ ] 05-02: TBD

### Phase 6: Scoped Lifecycle and Disposal
**Goal**: Services registered with Lifecycle.scoped are tied to their widget scope's lifetime and all disposable services are cleaned up automatically when the scope unmounts
**Depends on**: Phase 5
**Requirements**: WIDG-06, WIDG-07
**Success Criteria** (what must be TRUE):
  1. A service registered as `Lifecycle.scoped` creates one instance per widget scope (not shared across scopes, not shared with parent/child)
  2. When a `DeepThoughtProvider` widget unmounts, all `Disposable` services in that scope have their `dispose()` called
  3. Scoped services in a child scope are disposed when the child unmounts, without affecting the parent scope's services
  4. Disposal order is deterministic (LIFO -- last registered, first disposed)
**Plans**: TBD

Plans:
- [ ] 06-01: TBD
- [ ] 06-02: TBD

### Phase 7: Widget Test Suite
**Goal**: The widget integration layer is proven correct with comprehensive widget tests covering all integration scenarios
**Depends on**: Phase 6
**Requirements**: TEST-03, TEST-04, TEST-05, TEST-06
**Success Criteria** (what must be TRUE):
  1. Widget tests verify `DeepThoughtProvider` creates and disposes scopes correctly through the StatefulWidget lifecycle
  2. Widget tests verify nested providers create proper parent-child hierarchies with fallback resolution
  3. Widget tests verify `Lifecycle.scoped` creates per-scope instances that are disposed on unmount
  4. Widget tests verify all BuildContext extensions (`question`, `maybeQuestion`, `deepThought`) resolve from the correct scope
  5. All widget tests pass with `flutter test`
**Plans**: TBD

Plans:
- [ ] 07-01: TBD
- [ ] 07-02: TBD

### Phase 8: Pub.dev Metadata and Analysis
**Goal**: The package passes all pub.dev publishing checks with zero warnings and has complete metadata for discoverability
**Depends on**: Phase 7
**Requirements**: DOCS-05, DOCS-06
**Success Criteria** (what must be TRUE):
  1. pubspec.yaml includes: description, topics, repository URL, Flutter SDK dependency, and platform declarations
  2. `publish_to: none` is removed from pubspec.yaml
  3. `dart pub publish --dry-run` completes with zero warnings and zero errors
  4. `dart analyze` reports zero issues across the entire package
**Plans**: TBD

Plans:
- [ ] 08-01: TBD
- [ ] 08-02: TBD

### Phase 9: Documentation and Examples
**Goal**: A developer discovering the package on pub.dev can understand what it does, install it, use it, and compare it to get_it within 10 minutes
**Depends on**: Phase 8
**Requirements**: DOCS-01, DOCS-02, DOCS-03, DOCS-04
**Success Criteria** (what must be TRUE):
  1. Every public class, method, extension, and typedef has dartdoc comments (zero undocumented public API members)
  2. `example/main.dart` is a runnable Flutter app demonstrating widget-scoped DI with nested providers and scoped lifecycle
  3. README includes installation instructions, quick start guide, API overview, architecture diagram, and a get_it comparison section
  4. CHANGELOG.md has a proper v1.0.0 entry documenting all features
**Plans**: TBD

Plans:
- [ ] 09-01: TBD
- [ ] 09-02: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 -> 8 -> 9

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Core Bug Fixes | 0/2 | Planning complete | - |
| 2. Core Cleanup | 0/? | Not started | - |
| 3. API Surface | 0/? | Not started | - |
| 4. Widget Provider Foundation | 0/? | Not started | - |
| 5. BuildContext Consumer API | 0/? | Not started | - |
| 6. Scoped Lifecycle and Disposal | 0/? | Not started | - |
| 7. Widget Test Suite | 0/? | Not started | - |
| 8. Pub.dev Metadata and Analysis | 0/? | Not started | - |
| 9. Documentation and Examples | 0/? | Not started | - |
