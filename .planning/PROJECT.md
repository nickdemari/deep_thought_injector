# Deep Thought Injector

## What This Is

A Flutter-focused dependency injection and service locator package themed after "The Hitchhiker's Guide to the Galaxy." It aims to be a production-quality alternative to `get_it`, differentiating through first-class widget-scoped dependency injection via InheritedWidget integration and BuildContext extensions. Published on pub.dev for the Flutter community.

## Core Value

Widget-scoped dependency injection that "just works" with Flutter's widget tree — something `get_it` doesn't do well.

## Requirements

### Validated

<!-- Shipped and confirmed valuable. Inferred from existing codebase. -->

- ✓ Synchronous service registration and resolution (`ponder`/`question`) — existing
- ✓ Asynchronous service registration and resolution (`ponderAsync`/`questionAsync`) — existing
- ✓ Singleton and transient lifecycle support — existing
- ✓ Named registrations (multiple services of the same type) — existing
- ✓ Hierarchical parent-child scoping with fallback lookup — existing
- ✓ Lazy and eager instantiation — existing
- ✓ Service override for testing (`SubEthaScope.override`) — existing
- ✓ Scope reset with Disposable cleanup — existing
- ✓ Custom exception type with error codes and stack traces (`VogonPoetryException`) — existing
- ✓ Structured logging with pluggable Logger — existing
- ✓ Error notification callback for crash reporting integration — existing

### Active

<!-- Current scope. Building toward these. -->

- [ ] Flutter widget integration (InheritedWidget-based scope provider)
- [ ] BuildContext extensions for resolving services from the widget tree
- [ ] Scoped lifecycle that ties service lifetime to widget scope
- [ ] Fix undeclared `logging` dependency in pubspec.yaml
- [ ] Remove `publish_to: none` and prepare pub.dev metadata (description, homepage, topics, screenshots)
- [ ] Add Flutter SDK dependency and platform declarations
- [ ] Comprehensive dartdoc comments on all public APIs
- [ ] Full test coverage (unit tests for all features, widget tests for Flutter integration)
- [ ] Production-quality README with usage examples, migration guide from get_it, and API overview
- [ ] Example app demonstrating real-world usage
- [ ] Clean static analysis (zero warnings, 100% pub.dev analysis score)
- [ ] Proper semantic versioning and CHANGELOG.md

### Out of Scope

- Code generation / annotation-driven registration (injectable-style) — adds complexity, not needed for v1
- Reactive/stream-based dependency watching (riverpod territory) — different paradigm, not our differentiator
- Pure Dart support without Flutter — Flutter-only is the focus; widget-tree scoping is the value prop
- State management features — this is DI, not state management

## Context

- Existing codebase was scaffolded with Very Good CLI, uses `very_good_analysis` for linting
- Current code is pure Dart with no Flutter dependency — Flutter integration is the major new work
- `get_it` is the dominant Flutter DI package; its scoping (`pushNewScope`/`popScope`) is global and manual, not widget-tree-aware
- The Hitchhiker's Guide theme (ponder, question, SubEthaScope, VogonPoetryException) is the brand and should be preserved
- `AutoWiring` module is a stub and `DeepThoughtConfig` is internal — both need decisions on whether to complete or remove
- `Lifecycle.scoped` enum value exists but is not differentiated from singleton in current implementation — needs to be wired to widget scope

## Constraints

- **Flutter SDK**: Must depend on Flutter SDK for widget integration
- **Package structure**: Single package (not split into core + flutter) since we're Flutter-only
- **Dart SDK**: >=3.0.0 <4.0.0 (existing constraint, keep it)
- **Pub.dev compliance**: Must pass `dart pub publish --dry-run`, achieve high pub points score
- **API naming**: Keep Hitchhiker's Guide themed names as primary API

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Flutter-only (no pure Dart) | Widget-tree scoping is the differentiator; pure Dart dilutes focus | — Pending |
| Compete with get_it specifically | Closest competitor in scope; clear positioning | — Pending |
| Keep Hitchhiker's Guide naming | Memorable brand, fun developer experience | — Pending |
| InheritedWidget for scoping | Flutter's native mechanism; no extra dependencies needed | — Pending |

---
*Last updated: 2026-03-07 after initialization*
