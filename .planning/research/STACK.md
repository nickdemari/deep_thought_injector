# Technology Stack

**Project:** Deep Thought Injector (Flutter DI Package)
**Researched:** 2026-03-07

## Executive Summary

This package is transitioning from a pure Dart library to a Flutter-focused dependency injection package. The stack changes are surgical: add Flutter SDK dependency, upgrade linting and test dependencies to current versions, fix the undeclared `logging` dependency, and keep everything else minimal. A DI package should have near-zero dependencies -- every dependency you add is a dependency your *users* inherit.

The Flutter integration layer requires exactly zero third-party packages. Flutter's built-in `InheritedWidget`, `StatefulWidget`, and `BuildContext` APIs are all you need. This is the same foundation that `provider` (the most successful Flutter DI package at 6.1.5) is built on, and it is how `flutter_inject` (1.1.0) works. You do NOT need `provider`, `riverpod`, or any other package to build widget-tree-scoped DI.

## Recommended Stack

### Core Framework

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| Flutter SDK | `>=3.22.0` | Widget integration, InheritedWidget, BuildContext | Required for widget-tree DI. Minimum 3.22.0 gives Dart >=3.4.0 which is mature Dart 3.x with records, patterns, and sealed classes. Wide enough to not exclude users on slightly older Flutter. | HIGH |
| Dart SDK | `>=3.4.0 <4.0.0` | Language runtime | Implied by Flutter SDK constraint. Dart 3.4+ gives us the full Dart 3 feature set without requiring bleeding edge. The existing `>=3.0.0` constraint is too loose -- 3.0-3.3 are essentially dead in the wild. | HIGH |

**Rationale for SDK floors:**
- Current stable is Flutter 3.41.2 / Dart 3.11.0 (as of Feb 2026).
- `get_it` 9.2.1 uses Dart `>=3.0.0`. We can afford to be slightly tighter because our user base is Flutter-only (Flutter users update more frequently than pure-Dart users).
- `provider` 6.1.5 requires Flutter SDK. `flutter_riverpod` 3.2.1 requires Flutter SDK. Neither pins to an old Flutter version.
- Setting `>=3.22.0` for Flutter means roughly June 2024+, giving ~20 months of coverage. This is generous.
- The `very_good_analysis` package we want (^7.0.0 minimum) requires Dart >=3.5.0, but using ^7.0.0 keeps the floor reasonable.

### Runtime Dependencies

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| `flutter` | (SDK) | InheritedWidget, StatefulWidget, BuildContext | The ENTIRE Flutter integration layer is built on these three classes. No external package needed. `provider` wraps InheritedWidget. We do the same, directly. Zero extra dependencies for users. | HIGH |
| `logging` | `^1.3.0` | Structured logging (existing usage in DeepThought) | Already used in the codebase but NOT declared in pubspec.yaml (critical bug). Must be added as explicit dependency. The `logging` package is Dart team-maintained, stable (1.3.0, 16 months unchanged), and zero-dependency. | HIGH |

**That's it. Two dependencies: Flutter SDK and `logging`.** This is intentional. Look at the competition:
- `get_it` 9.2.1 has 3 dependencies: `async`, `collection`, `meta`
- `provider` 6.1.5 has 2 dependencies: `collection`, `nested`
- `flutter_inject` 1.1.0 has 0 non-SDK dependencies

Fewer dependencies = fewer version conflicts for users = higher pub.dev score = easier adoption.

### Dev Dependencies

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| `flutter_test` | (SDK) | Widget testing | Replaces `test` package. Since we're Flutter-only, `flutter_test` gives us `testWidgets`, `WidgetTester`, `pumpWidget`, `pumpAndSettle` -- essential for testing InheritedWidget integration. Bundled with Flutter SDK, no version to pin. | HIGH |
| `mocktail` | `^1.0.4` | Mock generation for tests | Already in pubspec (^1.0.0) but unused. Latest is 1.0.4. No codegen needed (unlike mockito). Felix Angelov's package, well-maintained, null-safety-first. Pin to ^1.0.4. | HIGH |
| `very_good_analysis` | `^7.0.0` | Strict lint rules | Current ^5.1.0 is ancient (requires Dart 3.0). Version 7.0.0 requires Dart >=3.5, which aligns with our Flutter >=3.22.0 floor. NOT jumping to 10.x because that requires Dart >=3.9 and would force our SDK floor too high. ^7.0.0 gives us 188+ lint rules and stays compatible. | MEDIUM |

**Why NOT `very_good_analysis` ^10.x:**
The latest is 10.2.0 (Dart >=3.11). If we used it, we'd need to set our Dart SDK floor to >=3.11.0, which means Flutter >=3.41.0 (February 2026). That excludes everyone not on the absolute latest stable. For a new package trying to build an audience, that's suicidal. ^7.0.0 is the sweet spot: modern rules, broad compatibility.

**Why `flutter_test` replaces `test`:**
The `test` package (^1.19.2 currently) is for pure Dart. Once we depend on Flutter SDK, widget tests need `flutter_test` which re-exports `test` functionality plus adds widget testing APIs. You cannot use both -- `flutter_test` supersedes `test`.

### Build/Dev Tooling

| Tool | Purpose | Why | Confidence |
|------|---------|-----|------------|
| `flutter` CLI | Test, analyze, format, publish | Replaces `dart` CLI for Flutter packages. `flutter test`, `flutter analyze`, `flutter pub publish`. | HIGH |
| `dart format` | Code formatting | Still works and is identical to `flutter format` (which just calls `dart format`). Either works. | HIGH |
| No build_runner | No codegen needed | This package does NOT need code generation. No annotations, no generated mocks (mocktail is runtime). Adding build_runner would be overengineering. | HIGH |

## What NOT to Use (and Why)

### Dependencies to Explicitly Avoid

| Package | Why Not |
|---------|---------|
| `provider` | We are *competing* with provider's DI capabilities. Depending on it would be absurd. We implement the same InheritedWidget pattern directly. |
| `get_it` | We are *replacing* get_it. Obviously don't depend on it. |
| `riverpod` / `flutter_riverpod` | Different paradigm (reactive providers, code generation). Out of scope per PROJECT.md. |
| `injectable` / `auto_injector` | Code generation DI. Explicitly out of scope for v1. |
| `collection` | get_it depends on this. We don't need it -- our internal maps use standard Dart collections. |
| `meta` | get_it depends on this for annotations like `@protected`. If we need `@visibleForTesting`, import from `package:flutter/foundation.dart` instead (already available via Flutter SDK). |
| `async` | get_it depends on this. Standard `dart:async` is sufficient for our async factories. |
| `nested` | provider depends on this for widget nesting. We don't need multi-provider nesting in v1. |

### Patterns to Explicitly Avoid

| Pattern | Why Not |
|---------|---------|
| Global singleton pattern (a la get_it) | Our differentiator is widget-scoped DI. A global `GetIt.I` singleton is exactly what we're improving upon. |
| Mixin-based widget integration (a la get_it_mixin) | Mixins are fragile, require specific call ordering in `build()`, and can't be used conditionally. InheritedWidget + BuildContext extensions is the Flutter-native approach. |
| Code generation for registration | Adds build_runner dependency, increases setup complexity, and is explicitly out of scope. |
| Stream-based reactivity | We're DI, not state management. Leave reactive patterns to riverpod/bloc. |

## How Competitor Packages Are Structured (for Reference)

### provider 6.1.5 -- The Gold Standard for InheritedWidget DI

**Architecture:**
- `InheritedProvider<T>` wraps a `StatefulWidget` that holds the value
- Two delegate patterns: `_CreateInheritedProvider` (owns lifecycle, calls create/dispose) and `_ValueInheritedProvider` (does not own lifecycle)
- `_InheritedProviderScope` is the actual `InheritedWidget` inserted into the tree
- `BuildContext` extensions (`context.read<T>()`, `context.watch<T>()`) for resolution
- `updateShouldNotify` controls rebuild behavior

**What to steal:**
- The `create`/`dispose` delegate pattern for lifecycle management
- `BuildContext` extension methods for ergonomic resolution
- The distinction between "I own this value's lifecycle" vs "I'm just providing an existing value"

**What NOT to steal:**
- Multi-provider nesting (`MultiProvider`) -- overkill for v1
- `Selector`/`Consumer` widgets -- state management territory
- `ChangeNotifier` integration -- state management territory

### get_it 9.2.1 -- The Anti-Pattern We're Improving

**Architecture:**
- Global singleton (`GetIt.I` or `GetIt.instance`)
- `pushNewScope()` / `popScope()` for manual scope management
- No widget tree integration in core package
- `get_it_mixin` 4.2.2 bolts on widget integration via mixins

**What get_it gets wrong (our opportunity):**
- Scopes are global and manual, not tied to widget lifecycle
- Forgetting `popScope()` leaks services
- Mixin approach requires strict call ordering in `build()`
- No automatic disposal when a widget unmounts

### flutter_inject 1.1.0 -- Minimal InheritedWidget DI

**Architecture:**
- Direct InheritedWidget wrapper
- Automatic memory cleanup on widget removal
- `dispose()` called automatically on injected objects
- Override support for testing

**What to steal:**
- The simplicity. This is proof that InheritedWidget-based DI doesn't need to be complicated.
- Automatic dispose on widget unmount -- this is table stakes.

## The Integration Pattern We Should Use

Based on research across provider, flutter_inject, and Flutter's own documentation:

```
StatefulWidget (owns lifecycle)
  -> State.initState() creates/registers services in scope
  -> State.dispose() calls scope.reset() which disposes Disposable services
  -> State.build() returns InheritedWidget holding the scope
    -> InheritedWidget makes scope available to descendants
      -> BuildContext extensions resolve services from nearest scope
```

This maps directly to our existing architecture:
- `SubEthaScope` already supports hierarchical parent-child scoping
- `SubEthaScope.reset()` already disposes `Disposable` instances
- `Lifecycle.scoped` enum already exists (just needs to be wired)
- `DeepThought` already wraps `SubEthaScope` with error handling

The Flutter layer is a thin widget shell around existing functionality. No architectural revolution needed.

## SDK Constraint Strategy

```yaml
environment:
  sdk: ">=3.4.0 <4.0.0"
  flutter: ">=3.22.0"
```

**Why this range:**
- Covers ~20 months of Flutter releases (June 2024 to present)
- Gives us Dart 3.4+ features (records, patterns, sealed classes if needed)
- Broad enough for adoption, narrow enough to use modern language features
- Matches what `very_good_analysis` ^7.0.0 requires (Dart >=3.5 -- slightly above our floor, which is fine since the linter is a dev dependency)

## Pubspec.yaml Target State

```yaml
name: deep_thought_injector
description: >-
  Widget-scoped dependency injection for Flutter, themed after
  The Hitchhiker's Guide to the Galaxy. A production alternative
  to get_it with first-class widget tree integration.
version: 1.0.0
repository: https://github.com/[owner]/deep_thought_injector
issue_tracker: https://github.com/[owner]/deep_thought_injector/issues
topics:
  - dependency-injection
  - service-locator
  - flutter
  - widget

environment:
  sdk: ">=3.4.0 <4.0.0"
  flutter: ">=3.22.0"

dependencies:
  flutter:
    sdk: flutter
  logging: ^1.3.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  mocktail: ^1.0.4
  very_good_analysis: ^7.0.0
```

## Installation (for consumers)

```bash
flutter pub add deep_thought_injector
```

## Development Commands

```bash
# Install dependencies
flutter pub get

# Run all tests (unit + widget)
flutter test

# Run tests with coverage
flutter test --coverage
genhtml coverage/lcov.info -o coverage/

# Format code
dart format .

# Analyze with strict linting
flutter analyze --fatal-infos

# Dry-run publish check
dart pub publish --dry-run
```

## Migration from Current State

| Current | Target | Action |
|---------|--------|--------|
| `sdk: ">=3.0.0 <4.0.0"` | `sdk: ">=3.4.0 <4.0.0"` + `flutter: ">=3.22.0"` | Tighten Dart floor, add Flutter constraint |
| No `flutter` dependency | `flutter: sdk: flutter` | Add Flutter SDK dependency |
| `logging` used but undeclared | `logging: ^1.3.0` | Fix critical bug: add to dependencies |
| `test: ^1.19.2` | `flutter_test: sdk: flutter` | Replace pure Dart test with Flutter test |
| `mocktail: ^1.0.0` | `mocktail: ^1.0.4` | Bump to latest |
| `very_good_analysis: ^5.1.0` | `very_good_analysis: ^7.0.0` | Upgrade for modern lint rules |
| `publish_to: none` | (removed) | Enable pub.dev publishing |
| Generic description | Descriptive, keyword-rich | Improve pub.dev discoverability |
| No topics | `dependency-injection`, `service-locator`, `flutter`, `widget` | Add pub.dev topics (max 5) |
| No repository URL | GitHub URL | Required for pub.dev scoring |

## Sources

### Official Documentation (HIGH confidence)
- [Flutter official architecture: Dependency Injection](https://docs.flutter.dev/app-architecture/case-study/dependency-injection)
- [Dart pub publishing requirements](https://dart.dev/tools/pub/publishing)
- [Dart pubspec file specification](https://dart.dev/tools/pub/pubspec)
- [Flutter pubspec options](https://docs.flutter.dev/tools/pubspec)
- [Flutter widget testing introduction](https://docs.flutter.dev/cookbook/testing/widget/introduction)
- [InheritedWidget class API](https://api.flutter.dev/flutter/widgets/InheritedWidget-class.html)
- [StatefulWidget class API](https://api.flutter.dev/flutter/widgets/StatefulWidget-class.html)
- [BuildContext.dependOnInheritedWidgetOfExactType API](https://api.flutter.dev/flutter/widgets/BuildContext/dependOnInheritedWidgetOfExactType.html)
- [Dart language evolution (SDK versions)](https://dart.dev/resources/language/evolution)
- [Flutter SDK archive](https://docs.flutter.dev/install/archive)

### Package Pages (HIGH confidence)
- [get_it 9.2.1 on pub.dev](https://pub.dev/packages/get_it) -- Dart >=3.0.0, deps: async, collection, meta
- [provider 6.1.5 on pub.dev](https://pub.dev/packages/provider) -- deps: collection, flutter, nested
- [flutter_riverpod 3.2.1 on pub.dev](https://pub.dev/packages/flutter_riverpod) -- deps: collection, flutter, meta, riverpod, state_notifier
- [flutter_inject 1.1.0 on pub.dev](https://pub.dev/packages/flutter_inject) -- deps: flutter only
- [get_it_mixin 4.2.2 on pub.dev](https://pub.dev/packages/get_it_mixin)
- [very_good_analysis versions on pub.dev](https://pub.dev/packages/very_good_analysis/versions) -- 10.2.0 latest, 7.0.0 for Dart >=3.5
- [mocktail on pub.dev](https://pub.dev/packages/mocktail) -- 1.0.4 latest
- [logging on pub.dev](https://pub.dev/packages/logging) -- 1.3.0 latest

### Community/Analysis (MEDIUM confidence)
- [Flutter: Comparing GetIt, Provider and Riverpod (gskinner)](https://blog.gskinner.com/archives/2021/11/flutter-comparing-getit-provider-and-riverpod.html)
- [DI in Flutter with InheritedWidget (Flutter Community)](https://medium.com/flutter-community/dependency-injection-in-flutter-with-inheritedwidget-b48ca63e823)
- [Reinventing Provider: InheritedWidget underhood (chooyan)](https://medium.com/@chooyan/reinventing-provider-understand-flutter-and-inheritedwidget-underhood-4c833e37a636)
- [What's new in Flutter 3.41 (official Flutter blog)](https://blog.flutter.dev/whats-new-in-flutter-3-41-302ec140e632)
- [InheritedProvider class API docs](https://pub.dev/documentation/provider/latest/provider/InheritedProvider-class.html)

---

*Stack research: 2026-03-07*
