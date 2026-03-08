# Requirements: Deep Thought Injector

**Defined:** 2026-03-07
**Core Value:** Widget-scoped dependency injection that "just works" with Flutter's widget tree

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Core Fixes

- [ ] **CORE-01**: Async singleton race condition fixed via Completer pattern (concurrent `locateAsync` calls for same lazy singleton must not invoke factory twice)
- [ ] **CORE-02**: Circular dependency detection during resolution (detect and throw descriptive error instead of stack overflow)
- [ ] **CORE-03**: `logging` dependency properly declared in pubspec.yaml
- [ ] **CORE-04**: `AutoWiring` stub removed from codebase
- [ ] **CORE-05**: `DeepThoughtConfig` stub removed from codebase
- [ ] **CORE-06**: `DeepThought.reset()` public method added (delegates to `SubEthaScope.reset()`)

### Widget Integration

- [ ] **WIDG-01**: `DeepThoughtProvider` StatefulWidget that creates and owns a `DeepThought` scope via InheritedWidget
- [ ] **WIDG-02**: Nested `DeepThoughtProvider` widgets automatically create parent-child scope chains (child finds parent via `getInheritedWidgetOfExactType`)
- [ ] **WIDG-03**: `context.question<T>()` BuildContext extension resolves service from nearest scope ancestor
- [ ] **WIDG-04**: `context.maybeQuestion<T>()` returns null instead of throwing when service not found
- [ ] **WIDG-05**: `context.deepThought` BuildContext extension accesses the `DeepThought` instance directly
- [ ] **WIDG-06**: `Lifecycle.scoped` creates one instance per widget scope, disposed when scope unmounts
- [ ] **WIDG-07**: All `Disposable` services automatically disposed when `DeepThoughtProvider` widget unmounts

### API Surface

- [ ] **API-01**: Standard registration aliases: `register()` / `registerAsync()` alongside `ponder()` / `ponderAsync()`
- [ ] **API-02**: Standard resolution aliases: `get()` / `getAsync()` alongside `question()` / `questionAsync()`
- [ ] **API-03**: `verify()` method that checks all sync registrations resolve without errors at startup
- [ ] **API-04**: `isRegistered<T>()` convenience method to check if a type is registered in the scope chain

### Documentation & Publishing

- [ ] **DOCS-01**: Dartdoc comments on all public classes, methods, extensions, and typedefs
- [ ] **DOCS-02**: `example/main.dart` with a runnable Flutter app demonstrating widget-scoped DI
- [ ] **DOCS-03**: README with installation, quick start, API overview, architecture diagram, and get_it comparison
- [ ] **DOCS-04**: CHANGELOG.md with proper v1.0.0 entry
- [ ] **DOCS-05**: Pubspec metadata: description, topics, repository URL, Flutter SDK dependency, platform declarations
- [ ] **DOCS-06**: Pass `dart pub publish --dry-run` with zero warnings and errors

### Testing

- [ ] **TEST-01**: Unit tests for async singleton race condition fix (concurrent access returns same instance)
- [ ] **TEST-02**: Unit tests for circular dependency detection (throws descriptive error)
- [ ] **TEST-03**: Widget tests for `DeepThoughtProvider` scope creation and disposal lifecycle
- [ ] **TEST-04**: Widget tests for nested scope hierarchy and parent fallback resolution
- [ ] **TEST-05**: Widget tests for `Lifecycle.scoped` per-scope instance behavior
- [ ] **TEST-06**: Widget tests for all BuildContext extensions

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Competitive Edge

- **EDGE-01**: Migration guide from get_it with API mapping table in README
- **EDGE-02**: Richer error messages including type name, scope chain, and list of registered types
- **EDGE-03**: Scope isolation options (prevent parent fallback for specific types)
- **EDGE-04**: `disposeFunction` callback parameter during registration for arbitrary cleanup
- **EDGE-05**: Auto-detect and dispose `ChangeNotifier` instances without requiring `Disposable` interface

### Developer Experience

- **DX-01**: DevTools extension showing registered services and scope tree
- **DX-02**: `TestDeepThoughtScope` widget helper for simplified widget testing
- **DX-03**: Hot reload support via `reassemble()` in `DeepThoughtProvider`

## Out of Scope

| Feature | Reason |
|---------|--------|
| Code generation / annotations | injectable already does this; massive complexity for no differentiating value |
| Reactive state watching / streams | Riverpod / watch_it territory; this is DI, not state management |
| Pure Dart support (no Flutter) | Widget-tree scoping IS the value prop; pure Dart dilutes focus |
| Factory with runtime parameters | Contentious, type-unsafe with dynamic; encourage factory class pattern instead |
| Auto-wiring / reflection | dart:mirrors banned in Flutter; impossible without code-gen |
| Global singleton access pattern | Anti-pattern; require BuildContext for widget code |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| CORE-01 | Phase 1: Core Bug Fixes | Pending |
| CORE-02 | Phase 1: Core Bug Fixes | Pending |
| CORE-03 | Phase 2: Core Cleanup | Pending |
| CORE-04 | Phase 2: Core Cleanup | Pending |
| CORE-05 | Phase 2: Core Cleanup | Pending |
| CORE-06 | Phase 2: Core Cleanup | Pending |
| WIDG-01 | Phase 4: Widget Provider Foundation | Pending |
| WIDG-02 | Phase 4: Widget Provider Foundation | Pending |
| WIDG-03 | Phase 5: BuildContext Consumer API | Pending |
| WIDG-04 | Phase 5: BuildContext Consumer API | Pending |
| WIDG-05 | Phase 5: BuildContext Consumer API | Pending |
| WIDG-06 | Phase 6: Scoped Lifecycle and Disposal | Pending |
| WIDG-07 | Phase 6: Scoped Lifecycle and Disposal | Pending |
| API-01 | Phase 3: API Surface | Pending |
| API-02 | Phase 3: API Surface | Pending |
| API-03 | Phase 3: API Surface | Pending |
| API-04 | Phase 3: API Surface | Pending |
| DOCS-01 | Phase 9: Documentation and Examples | Pending |
| DOCS-02 | Phase 9: Documentation and Examples | Pending |
| DOCS-03 | Phase 9: Documentation and Examples | Pending |
| DOCS-04 | Phase 9: Documentation and Examples | Pending |
| DOCS-05 | Phase 8: Pub.dev Metadata and Analysis | Pending |
| DOCS-06 | Phase 8: Pub.dev Metadata and Analysis | Pending |
| TEST-01 | Phase 1: Core Bug Fixes | Pending |
| TEST-02 | Phase 1: Core Bug Fixes | Pending |
| TEST-03 | Phase 7: Widget Test Suite | Pending |
| TEST-04 | Phase 7: Widget Test Suite | Pending |
| TEST-05 | Phase 7: Widget Test Suite | Pending |
| TEST-06 | Phase 7: Widget Test Suite | Pending |

**Coverage:**
- v1 requirements: 28 total
- Mapped to phases: 28
- Unmapped: 0

---
*Requirements defined: 2026-03-07*
*Last updated: 2026-03-07 after roadmap creation*
