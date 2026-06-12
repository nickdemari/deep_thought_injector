# Project Research Summary

**Project:** Deep Thought Injector (Flutter DI Package)
**Domain:** Flutter dependency injection / service locator with widget-tree scoping
**Researched:** 2026-03-07
**Confidence:** HIGH

## Executive Summary

Deep Thought Injector is a Flutter dependency injection package that already has a solid pure-Dart core (registration, resolution, hierarchical scoping, async factories, disposal via `Disposable`) and needs a thin Flutter widget integration layer to become publishable. The competitive positioning is clear: get_it (1.65M+ downloads) does DI well but has no widget-tree awareness, while Provider (2M+ downloads) does widget-tree DI but is primarily a state management tool. The gap is "proper DI container features combined with proper Flutter integration" -- and nobody has successfully filled it yet (get_it_modular at 20 downloads and widject_container at 200 downloads both tried and failed). Execution quality, not innovation, will determine success.

The recommended approach is a three-phase build: (1) fix known core bugs and build the widget integration layer, (2) prepare for pub.dev publishing with full documentation and scoring compliance, (3) add competitive-edge features like startup validation and migration guides. The Flutter integration itself is architecturally simple -- a `StatefulWidget` that owns a `DeepThought` scope, a private `InheritedWidget` that exposes it to descendants, and `BuildContext` extensions for ergonomic resolution. This is the exact pattern that Provider, Riverpod, and flutter_inject all use. No architectural invention is required.

The key risks are: (a) the async singleton race condition that already exists in the codebase and will be amplified by concurrent widget resolution, (b) themed API names (`ponder`/`question`) being a discoverability disaster if standard aliases are not provided from day one, (c) pub.dev score death-by-a-thousand-cuts from missing metadata/docs/examples, and (d) scope disposal not handling common Flutter types like `ChangeNotifier`. All four are preventable with deliberate design decisions in Phase 1.

## Key Findings

### Recommended Stack

The stack is deliberately minimal -- a DI package should have near-zero dependencies because every dependency becomes the user's dependency. The target is two runtime dependencies: Flutter SDK and `logging` (Dart team-maintained, zero-dependency itself). Dev dependencies are `flutter_test`, `mocktail` (^1.0.4), and `very_good_analysis` (^7.0.0 -- NOT ^10.x, which would force Dart >=3.11 and exclude everyone not on bleeding edge).

**Core technologies:**
- **Flutter SDK (>=3.22.0):** InheritedWidget, StatefulWidget, BuildContext -- the entire widget integration layer with zero third-party packages
- **Dart SDK (>=3.4.0 <4.0.0):** Full Dart 3 feature set (records, patterns, sealed classes) with ~20 months of Flutter release coverage
- **`logging` (^1.3.0):** Already used in the codebase but NOT declared in pubspec.yaml (critical bug to fix)
- **`flutter_test` (SDK):** Replaces `test` package -- widget tests need `testWidgets`, `pumpWidget`, `WidgetTester`
- **`very_good_analysis` (^7.0.0):** 188+ lint rules, compatible with the SDK floor; current ^5.1.0 is ancient
- **No build_runner, no codegen:** The package does not need code generation. Adding build_runner would be overengineering.

**Critical migration actions:** Tighten Dart SDK floor from >=3.0.0 to >=3.4.0, add Flutter SDK constraint >=3.22.0, declare `logging` dependency, replace `test` with `flutter_test`, remove `publish_to: none`, add pub.dev topics and repository URL.

### Expected Features

**Must have (table stakes) -- all already built except where noted:**
- Singleton, lazy singleton, and factory registration (DONE)
- Async service registration and resolution (DONE)
- Named registrations for multiple implementations of same type (DONE)
- Service override for testing (DONE)
- Dispose/cleanup on scope teardown (DONE, needs enhancement for `ChangeNotifier` and custom dispose callbacks)
- Hierarchical parent-child scoping with fallback lookup (DONE)
- Type-safe generic resolution (DONE)
- Full dartdoc coverage (NOT DONE -- required for pub.dev scoring and credibility)
- Example app at `example/main.dart` (NOT DONE -- required for pub.dev)
- Clean static analysis passing `dart pub publish --dry-run` (NOT DONE -- blocked by undeclared `logging`, `publish_to: none`)

**Should have (differentiators):**
- Widget-scoped DI via InheritedWidget (THE core value proposition, NOT BUILT)
- BuildContext extensions: `context.question<T>()`, `context.maybeQuestion<T>()` (NOT BUILT)
- Automatic disposal tied to widget lifecycle -- no manual `popScope()` (NOT BUILT)
- `Lifecycle.scoped` actually meaning "one instance per widget scope, disposed on unmount" (enum exists, behavior does not)
- Standard API aliases alongside themed names (`register`/`get` alongside `ponder`/`question`)
- `verify()` method for startup validation (checks all registrations are satisfiable)
- Nullable resolution (`maybeQuestion<T>()` returning null instead of throwing)
- `isRegistered<T>()` convenience method
- Migration guide from get_it

**Defer to post-v1:**
- DevTools extension (massive investment, zero adoption impact for v1)
- Reactive state watching (watch_it/riverpod territory -- stay in DI lane)
- Code generation / annotations (injectable territory, explicitly out of scope)
- Factory with runtime parameters (`registerFactoryParam` -- contentious, type-unsafe)
- Auto-wiring / reflection (impossible without dart:mirrors in Flutter)

### Architecture Approach

The architecture is a three-layer cake: the existing Core DI Layer (`DeepThought` facade over `SubEthaScope` registry), a new Widget Integration Layer (`DeepThoughtProvider` StatefulWidget + private `_InheritedDeepThought` InheritedWidget), and a new Consumer API Layer (`BuildContext` extensions). The widget layer is thin -- it creates a `DeepThought` in `initState`, exposes it via InheritedWidget, and calls `reset()` in `dispose()`. Nested `DeepThoughtProvider` widgets automatically create parent-child scope chains by finding the ancestor scope via `getInheritedWidgetOfExactType` (not `dependOn` -- the latter would create unwanted rebuild dependencies). This is the same pattern Provider, Riverpod, and flutter_inject use.

**Major components:**
1. **DeepThoughtProvider** (new, StatefulWidget) -- Creates/owns a `DeepThought` scope, runs user-provided registrations in `initState`, disposes scope in `dispose()`, builds private InheritedWidget
2. **_InheritedDeepThought** (new, private InheritedWidget) -- Holds `DeepThought` reference, `updateShouldNotify => false`, never exposed publicly
3. **BuildContext extensions** (new) -- `context.question<T>()`, `context.deepThought`, `context.ponder<T>(...)` -- syntactic sugar over `DeepThoughtProvider.of(context)`
4. **DeepThought** (existing, facade) -- Needs `reset()` method added to delegate to `SubEthaScope.reset()` for provider disposal
5. **SubEthaScope** (existing, registry) -- Needs `Lifecycle.scoped` differentiation from `singleton`, needs circular dependency detection, needs async race condition fix via Completer pattern

**Recommended structure:** Flat under `lib/src/` (only 2-3 new files). Subdirectories are unnecessary at this package size.

### Critical Pitfalls

1. **Async singleton race condition (EXISTING BUG)** -- Two concurrent `locateAsync<T>()` calls for the same lazy singleton invoke the factory twice. Fix with Completer pattern: first caller creates Completer and starts factory, subsequent callers await the same Completer's future. Must be fixed before Flutter integration amplifies concurrent access.

2. **Widget lifecycle vs scope lifetime mismatch** -- get_it's #1 reported issue. During `Navigator.popAndPushNamed()`, the new screen's `initState` fires before the old screen's `dispose`, causing wrong-scope destruction. Prevention: the InheritedWidget approach IS the solution -- scope lifetime is managed by Flutter's element lifecycle, not manual push/pop.

3. **Themed API names killing discoverability** -- `ponder`/`question` are memorable but invisible to autocomplete and code review. Provide standard aliases (`register`/`get`) as primary documented API from day one. Retrofitting later is a documentation rewrite.

4. **Pub.dev score death by a thousand cuts** -- Undeclared `logging` dep, `publish_to: none`, no example app, no dartdoc, no topics, no repository URL. Each costs 10-30 points. A package at 80/160 looks abandoned. Run `pana` locally from Phase 1.

5. **Scope disposal missing common Flutter types** -- Current `Disposable` interface won't catch `ChangeNotifier.dispose()` or stream subscriptions. Accept `disposeFunction` callback during registration for arbitrary cleanup. Only dispose what the scope owns -- never parent scope services.

## Implications for Roadmap

### Phase 1: Core Fixes and Widget Integration

**Rationale:** The core DI layer has known bugs (async race condition, no circular dependency detection) that will be amplified once widgets concurrently resolve services. Fix the foundation before building on it. Then build the widget integration layer -- this is the entire value proposition and everything else depends on it existing.

**Delivers:** A working Flutter DI package with widget-scoped services, automatic lifecycle management, and a clean consumer API.

**Sub-phases (dependency order):**
1. Core fixes: async race condition (Completer), circular dependency detection, add `reset()` to DeepThought, add `isRegistered<T>()`
2. Core cleanup: delete `AutoWiring` stub, delete `DeepThoughtConfig.secrets`, remove dead `_lock` field
3. API naming: add standard aliases (`register`/`get`/`resolve`) alongside themed names
4. Widget integration: `DeepThoughtProvider`, `_InheritedDeepThought`, BuildContext extensions, `Lifecycle.scoped` behavior
5. Disposal enhancement: `disposeFunction` callback parameter, auto-detect `ChangeNotifier`
6. Widget tests: scope creation, hierarchical nesting, disposal ordering, hot reload, navigation transitions

**Avoids pitfalls:** Async race condition (#4), circular dependency crash (#5), widget lifecycle mismatch (#1), stale InheritedWidget dependencies (#2), "context must be below" trap (#3), broken const constructor convention (#9), hot reload breakage (#10)

### Phase 2: Pub.dev Publishing Preparation

**Rationale:** Cannot publish without passing `pana` checks. Documentation and metadata are scored and directly impact discoverability and trust. This phase is sequential after Phase 1 because docs describe the widget API that Phase 1 builds.

**Delivers:** A pub.dev-ready package scoring 140+/160 points with comprehensive documentation, examples, and metadata.

**Addresses:**
- Fix pubspec.yaml: description, topics, repository, remove `publish_to: none`, declare `logging`
- Upgrade dependencies: `very_good_analysis` ^7.0.0, `mocktail` ^1.0.4, replace `test` with `flutter_test`
- 100% dartdoc coverage on all public APIs (classes, methods, extensions, typedefs)
- `example/main.dart` with a realistic, runnable usage example
- CHANGELOG.md with proper per-version entries
- LICENSE file validation
- README overhaul: installation, quick start, architecture overview, API reference
- Pass `dart pub publish --dry-run` and `pana .` with zero warnings

**Avoids pitfalls:** Pub.dev score death (#6), missing example (#6 sub-item), dartdoc gaps

### Phase 3: Competitive Edge and Polish

**Rationale:** With a published, functional package, add features that reduce switching cost from get_it and catch misconfigurations early. These are adoption accelerators, not core functionality.

**Delivers:** Migration path from get_it, startup validation, richer diagnostics.

**Addresses:**
- `verify()` method for startup validation (checks all registrations resolve without errors)
- Migration guide: get_it API to deep_thought_injector API mapping table
- Richer error messages: include type name, scope chain, list of registered types
- `maybeOf()` / `maybeQuestion()` for nullable resolution
- Scope isolation options (prevent parent fallback for specific types)
- README competitive positioning section

**Avoids pitfalls:** Themed API discoverability (#7 -- migration guide shows standard names), poor error messages (UX pitfall)

### Phase Ordering Rationale

- **Phase 1 before Phase 2** because you cannot document an API that does not exist. The widget integration layer IS the product. Fixing core bugs first prevents the widget layer from inheriting and amplifying existing defects.
- **Phase 2 before Phase 3** because publishing to pub.dev establishes the package's existence. A package with zero downloads and zero pub points has no audience for competitive-edge features. Get discoverable first.
- **Within Phase 1, core fixes before widget integration** because the Completer fix for async singletons and the circular dependency guard must be in place before widgets start resolving services concurrently during build cycles.
- **Standard API aliases in Phase 1** because retrofitting them later requires a documentation rewrite and risks confusing early adopters who learned only themed names.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 1 (widget integration):** The `dependOnInheritedWidgetOfExactType` vs `getInheritedWidgetOfExactType` distinction and its implications for `read<T>()` vs `watch<T>()` patterns needs careful API design. Also: how `reassemble()` should behave for hot reload support. Research the exact Provider/Riverpod patterns for these edge cases.
- **Phase 2 (pub.dev preparation):** The `pana` scoring system has undocumented requirements that change between versions. Run `pana` early and often. The `example/main.dart` path is specifically checked -- do not use `example/lib/main.dart`.

Phases with standard patterns (skip deep research):
- **Phase 1 (core fixes):** Completer pattern for async singletons and Set-based circular dependency detection are well-documented, standard patterns. No research needed -- just implement.
- **Phase 3 (competitive edge):** `verify()`, migration guides, and error message improvements are straightforward feature work with no architectural ambiguity.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All recommendations backed by pub.dev package pages, Flutter SDK docs, and Dart language evolution docs. Version constraints verified against current stable. |
| Features | HIGH | Competitive landscape mapped with download counts and feature matrices. Table stakes verified against get_it, Provider, and Riverpod feature sets. Differentiators validated against open get_it issues (users actively requesting these features). |
| Architecture | HIGH | The StatefulWidget + InheritedWidget pattern is used by Provider, Riverpod, and flutter_inject. Multiple sources confirm the same approach. Code examples are concrete and implementation-ready. |
| Pitfalls | HIGH | Critical pitfalls sourced from get_it GitHub issues (real user reports), Flutter framework bug tracker, and codebase audit. Async race condition is an existing documented bug. Prevention strategies verified against Provider/Riverpod implementations. |

**Overall confidence:** HIGH

### Gaps to Address

- **`Lifecycle.scoped` semantics:** The exact behavior of scoped services needs definition. Should a scoped service in a parent scope be visible to child scopes? Should it be a "one per scope" singleton or something else? The research suggests "one instance per scope, not shared with children via parent lookup" but this needs validation during implementation.
- **`read<T>()` vs `watch<T>()` naming:** The research shows Provider uses these names. Should deep_thought_injector use the same names (familiar to Provider users) or stick with themed names only (`question<T>()` for read, no watch equivalent since this is DI not state management)? Decision: provide both, but the exact API surface needs design.
- **`logging` dependency decision:** STACK.md says keep it (^1.3.0). FEATURES.md suggests removing it for zero-dependency bragging rights. Recommendation: keep it -- it is already used throughout the codebase, removal is more disruptive than the one extra dependency is costly, and `logging` is a Dart-team-maintained package with zero transitive dependencies.
- **`DeepThought.reset()` visibility:** Currently `SubEthaScope.reset()` is called internally. Adding a public `DeepThought.reset()` is needed for the provider's `dispose()`. But should it be public API or package-private? Recommendation: public -- users may want manual reset (e.g., on logout).
- **Test helper for consumers:** Whether to ship a `TestDeepThoughtScope` widget or just document the testing pattern. Defer to Phase 2 -- document the pattern first, extract a helper if users request it.

## Sources

### Primary (HIGH confidence)
- [Flutter InheritedWidget class API](https://api.flutter.dev/flutter/widgets/InheritedWidget-class.html)
- [Flutter StatefulWidget class API](https://api.flutter.dev/flutter/widgets/StatefulWidget-class.html)
- [Flutter dependOnInheritedWidgetOfExactType API](https://api.flutter.dev/flutter/widgets/BuildContext/dependOnInheritedWidgetOfExactType.html)
- [Flutter getInheritedWidgetOfExactType API](https://api.flutter.dev/flutter/widgets/BuildContext/getInheritedWidgetOfExactType.html)
- [Flutter official DI architecture](https://docs.flutter.dev/app-architecture/case-study/dependency-injection)
- [Flutter widget testing introduction](https://docs.flutter.dev/cookbook/testing/widget/introduction)
- [Dart pub publishing requirements](https://dart.dev/tools/pub/publishing)
- [Dart pubspec specification](https://dart.dev/tools/pub/pubspec)
- [get_it 9.2.1 on pub.dev](https://pub.dev/packages/get_it) -- 1.65M+ downloads, deps: async, collection, meta
- [Provider 6.1.5 on pub.dev](https://pub.dev/packages/provider) -- Google-endorsed, deps: collection, flutter, nested
- [flutter_riverpod 3.2.1 on pub.dev](https://pub.dev/packages/flutter_riverpod) -- deps: collection, flutter, meta, riverpod, state_notifier
- [flutter_inject 1.1.0 on pub.dev](https://pub.dev/packages/flutter_inject) -- deps: flutter only
- [pub.dev scoring system](https://pub.dev/help/scoring) -- max 160 points breakdown
- [get_it #247: Widget lifecycle scope disposal](https://github.com/fluttercommunity/get_it/issues/247)
- [get_it #158: Scope confusion](https://github.com/fluttercommunity/get_it/issues/158)
- [Flutter #62861: Stale InheritedWidget dependencies](https://github.com/flutter/flutter/issues/62861)

### Secondary (MEDIUM confidence)
- [gskinner: Comparing GetIt, Provider, and Riverpod](https://blog.gskinner.com/archives/2021/11/flutter-comparing-getit-provider-and-riverpod.html)
- [Andrea Bizzotto: Global vs Scoped Access](https://codewithandrea.com/articles/global-access-vs-scoped-access/)
- [Flutter Community: DI with InheritedWidget](https://medium.com/flutter-community/dependency-injection-in-flutter-with-inheritedwidget-b48ca63e823)
- [Reinventing Provider: InheritedWidget underhood](https://medium.com/@chooyan/reinventing-provider-understand-flutter-and-inheritedwidget-underhood-4c833e37a636)
- [Stream: Deep Dive Into pub.dev](https://getstream.io/blog/deep-dive-pub-dev/)

---
*Research completed: 2026-03-07*
*Ready for roadmap: yes*
