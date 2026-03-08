# Feature Landscape

**Domain:** Flutter dependency injection / service locator packages
**Researched:** 2026-03-07
**Primary competitor:** get_it (v9.2.1, 1.65M+ downloads, 150 pub points)
**Secondary competitors:** Provider (Google-endorsed), Riverpod, injectable, watch_it

---

## Table Stakes

Features users expect from any Flutter DI package. Missing any of these and developers won't even consider it.

| Feature | Why Expected | Complexity | Already Built? | Notes |
|---------|--------------|------------|----------------|-------|
| Singleton registration | Every DI container has this. Absolute baseline. | Low | YES | `ponder()` with `Lifecycle.singleton` |
| Lazy singleton registration | get_it has `registerLazySingleton`. Developers expect deferred instantiation to reduce startup time. | Low | YES | `lazy: true` parameter (default) |
| Factory (transient) registration | New instance per resolution. Required for stateful short-lived objects. | Low | YES | `Lifecycle.transient` |
| Async service registration | Real services talk to databases, SharedPreferences, APIs. Async init is non-negotiable. | Medium | YES | `ponderAsync()` / `questionAsync()` |
| Named registrations | Multiple implementations of the same type (e.g., `ApiClient` for staging vs prod). get_it has `instanceName`. | Low | YES | `name` parameter on registration |
| Service override for testing | If you can't swap dependencies in tests, the package is useless for production apps. get_it has `allowReassignment` and `registerIfAbsent`. | Low | YES | `SubEthaScope.override()` |
| Dispose / cleanup on teardown | Memory leaks are the #1 complaint about DI packages. Services must be disposed when scopes die. | Medium | YES | `Disposable` interface + `reset()` |
| Hierarchical scoping | Parent-child scope chains with fallback lookup. get_it has `pushNewScope`/`popScope`. Provider has widget-tree scoping. | Medium | YES | `createChildScope()` with parent lookup |
| Type-safe resolution | Generics-based resolution (`question<MyService>()`). Runtime type errors are unacceptable. | Low | YES | Generic `T` on all methods |
| Comprehensive error messages | When resolution fails, developers need to know WHY. "Service not found" is table stakes; get_it shows the type and scope. | Low | PARTIAL | `VogonPoetryException` exists but messages could be richer (include type name, scope chain) |
| Full dartdoc coverage | pub.dev scores penalize missing docs. Users expect to read API docs inline. | Medium | NO | Needs comprehensive dartdoc on all public APIs |
| Example app | pub.dev shows example tab. Developers judge packages by example quality. get_it has excellent examples. | Medium | NO | Required for pub.dev credibility |
| Clean static analysis | Zero warnings, full pub points. `very_good_analysis` already in use; must pass `dart pub publish --dry-run`. | Low | NO | `logging` dependency undeclared; `publish_to: none` |

## Differentiators

Features that set deep_thought_injector apart from get_it. These are the reasons someone would switch.

| Feature | Value Proposition | Complexity | Already Built? | Notes |
|---------|-------------------|------------|----------------|-------|
| **Widget-scoped DI via InheritedWidget** | get_it's biggest weakness: scopes are global stacks, not tied to the widget tree. Provider does this but isn't a DI container. This is THE differentiator -- services that live and die with widget subtrees, resolved via `BuildContext`. | High | NO | Core value prop per PROJECT.md. `Lifecycle.scoped` enum exists but is not differentiated from singleton. |
| **BuildContext extensions for resolution** | `context.question<MyService>()` instead of `GetIt.I.get<MyService>()`. Widget-native API. Respects Flutter idioms. Provider uses `context.read<T>()` / `context.watch<T>()`. | Medium | NO | Must feel natural to Flutter developers used to Provider's `context.read()` pattern. |
| **Automatic disposal tied to widget lifecycle** | When a scope widget unmounts, all its `Disposable` services get cleaned up. No manual `popScope()`. No memory leaks from forgotten cleanup. get_it requires manual scope management; this is automatic. | Medium | NO | Provider does this natively. get_it does not. Major selling point. |
| **Scoped lifecycle that ACTUALLY means something** | `Lifecycle.scoped` should mean "one instance per widget scope, disposed when scope unmounts." get_it's scoping is a global stack; this ties to widget tree position. | Medium | NO | Enum value exists, behavior doesn't. Must wire to InheritedWidget scope. |
| **Fun, memorable API naming** | `ponder()` / `question()` / `VogonPoetryException` / `SubEthaScope`. Developers remember packages that make them smile. get_it is purely functional naming. | Low | YES | Already the brand. Preserve it, but provide conventional aliases for discoverability. |
| **Zero external dependencies** | get_it depends on `async`, `collection`, `meta`. Provider depends on `nested`, `collection`. A package with zero deps (beyond Flutter SDK) is a trust signal and reduces version conflict risk. | Low | ALMOST | Currently has undeclared `logging` dependency. Remove it; use Dart's built-in `developer.log()` or make logging optional. |
| **Migration guide from get_it** | Actively help developers switch. "Here's your get_it code, here's the deep_thought_injector equivalent." Reduces switching cost to near-zero. | Medium | NO | README content, not code. High-value documentation. |
| **Compile-time safety hints** | get_it fails at runtime when services aren't registered. Providing a `verify()` method that checks all registrations at app startup (similar to get_it issue #333 requesting this) catches misconfigurations early. | Medium | NO | get_it users actively request this (open issue #333). |
| **Nullable resolution (maybeQuestion)** | `context.maybeQuestion<T>()` returns `null` instead of throwing. get_it added `maybeGet<T>()` -- this is expected but combined with widget-tree lookup it becomes more powerful (check ancestors). Provider supports `context.read<T?>()`. | Low | NO | Small but important API completeness feature. |

## Anti-Features

Things to deliberately NOT build. These add complexity, blur positioning, or drag the package into competitor territory.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **Code generation / annotations** | injectable already does this for get_it. It adds build_runner dependency, increases complexity massively, and is explicitly out of scope per PROJECT.md. Code-gen is a bolt-on, not a core feature. | Keep registration manual and explicit. The API should be simple enough that code-gen isn't needed. |
| **Reactive state management / streams** | This is Riverpod's territory. watch_it exists specifically because get_it needed reactivity bolted on. Mixing DI with state management creates a confused package. | Be a DI container, not a state manager. If users want reactivity, they can use `ValueNotifier` / `ChangeNotifier` with their DI-provided services and Flutter's built-in `ListenableBuilder`. |
| **Global singleton access pattern** | `GetIt.I.get<T>()` works from anywhere, no context needed. That's the service locator anti-pattern. It hides dependencies, hurts testability, and the Flutter team officially recommends against it. | Require `BuildContext` for resolution. This is the differentiator, not a limitation. Provide a `DeepThought` instance for non-widget code (tests, services) but push widget code toward `context.question<T>()`. |
| **Pure Dart support (no Flutter)** | Widget-tree scoping IS the value prop. Supporting pure Dart means maintaining two code paths and diluting the Flutter-first message. | Flutter-only. If someone needs pure Dart DI, they should use get_it. |
| **Factory with parameters (`registerFactoryParam`)** | get_it supports this but it's contentious (limited to 2 params, type-unsafe with `dynamic`). It encourages passing runtime data through DI instead of constructors. | Let factories close over their dependencies. If you need runtime params, use a factory class registered as a singleton. |
| **Automatic wiring / reflection** | The `AutoWiring` stub in the codebase. Dart doesn't have runtime reflection (dart:mirrors is banned in Flutter). Auto-wiring without code-gen is impossible. | Remove the `AutoWiring` and `DeepThoughtConfig` stubs. They're dead weight. |
| **DevTools extension (for v1)** | get_it has one; it's nice. But it's a massive investment for a v1 launch. Zero users are choosing a DI package based on DevTools support. | Defer to v2. Focus on core DI + widget integration for v1. Add good `toString()` on registrations for debuggability instead. |
| **Multi-platform declarations** | pub.dev awards points for Android/iOS/Web/macOS/Linux/Windows support. DI doesn't need platform-specific code, but declaring support requires testing on each platform. | Declare Flutter-compatible platforms in pubspec but don't add platform-specific implementations. This is a pure Dart-on-Flutter package. |

## Feature Dependencies

```
                    +----------------------------+
                    | InheritedWidget Scope       |
                    | Provider Widget             |
                    +----------------------------+
                          |              |
                          v              v
               +------------------+  +------------------------+
               | BuildContext      |  | Automatic disposal     |
               | extensions        |  | on widget unmount      |
               +------------------+  +------------------------+
                          |              |
                          v              v
               +------------------+  +------------------------+
               | Lifecycle.scoped  |  | Nullable resolution    |
               | differentiation   |  | (maybeQuestion)        |
               +------------------+  +------------------------+
                          |
                          v
               +------------------+
               | verify() method   |
               | (checks all       |
               | registrations)    |
               +------------------+

Key dependency chains:

InheritedWidget scope widget --> BuildContext extensions (extensions need the scope in the tree)
InheritedWidget scope widget --> Automatic disposal (disposal hooks into widget lifecycle)
BuildContext extensions --> Lifecycle.scoped (scoped lifecycle only makes sense with widget scope)
BuildContext extensions --> Nullable resolution (maybeQuestion is a BuildContext extension variant)

Independent of widget integration:
- Migration guide (documentation only)
- verify() method (can work on DeepThought directly)
- Fun API naming (already exists)
- Zero dependencies (refactoring task)
- Example app (after widget integration exists)
- Dartdoc coverage (after API is stable)
```

## MVP Recommendation

**Phase 1 -- Core widget integration (HIGH priority, HIGH complexity):**
1. InheritedWidget-based scope provider widget
2. BuildContext extensions (`context.question<T>()`, `context.maybeQuestion<T>()`)
3. Wire `Lifecycle.scoped` to widget scope (instance per scope, disposed on unmount)
4. Automatic disposal when scope widget unmounts

**Phase 2 -- pub.dev readiness (MEDIUM priority, MEDIUM complexity):**
5. Fix `logging` dependency (remove or internalize)
6. Remove `AutoWiring` and `DeepThoughtConfig` stubs
7. Full dartdoc coverage on all public APIs
8. Example app demonstrating real-world usage
9. Pub.dev metadata (description, homepage, topics, screenshots)
10. Clean `dart pub publish --dry-run`

**Phase 3 -- Competitive edge (MEDIUM priority, LOW complexity):**
11. `verify()` method for startup validation
12. Migration guide from get_it in README
13. Richer error messages (include type name, scope chain in exceptions)

**Defer to post-v1:**
- DevTools extension
- Reactive watching (watch_it territory)
- Code generation (injectable territory)
- Factory with parameters

## Competitive Landscape Summary

| Package | Downloads | Approach | Widget-Tree Aware? | Scoped Lifecycle? | Auto-Dispose? |
|---------|-----------|----------|--------------------|--------------------|---------------|
| get_it | 1.65M+ | Global service locator | NO (global stack) | Manual pushNewScope/popScope | Manual |
| Provider | 2M+ | InheritedWidget wrapper | YES | YES | YES |
| Riverpod | 500K+ | Provider rewrite, reactive | YES (ref-based) | YES | YES |
| injectable | 293K | Code-gen for get_it | NO (wraps get_it) | NO | NO |
| watch_it | 8K | Reactive layer for get_it | Partial (mixin) | NO | Auto-unsubscribe |
| get_it_modular | ~20 | Widget scope for get_it | YES (ModuleScope) | YES | YES |
| widject_container | ~200 | Widget scope DI | YES (ScopeWidget) | YES | YES |
| **deep_thought_injector** | 0 | Widget-scoped DI | **TARGET: YES** | **TARGET: YES** | **TARGET: YES** |

**Key insight:** get_it_modular (20 downloads) and widject_container (200 downloads) attempted exactly what deep_thought_injector wants to do, but failed to gain traction. The opportunity is real -- get_it users genuinely want widget-scoped DI -- but execution quality and marketing (README, examples, migration guide) will determine success. Being "widget-scoped get_it alternative" is necessary but not sufficient; the package must also be polished, well-documented, and easy to adopt.

**The gap in the market:** Provider does widget-scoped DI but is primarily a state management tool. get_it does DI well but ignores the widget tree. Nobody has successfully combined "proper DI container features" (async, named, hierarchical, lifecycle) with "proper Flutter integration" (InheritedWidget, BuildContext, auto-dispose) in a package that people actually use. That's the target.

## Sources

- [get_it on pub.dev](https://pub.dev/packages/get_it) - v9.2.1, 1.65M+ downloads, 150 pub points (HIGH confidence)
- [get_it GitHub issues](https://github.com/flutter-it/get_it/issues) - 9 open issues including scope independence (#342), config verification (#333), dependsOn for async (#340) (HIGH confidence)
- [get_it advanced docs](https://flutter-it.dev/documentation/get_it/advanced) - Disposable, findAll, reference counting, maybeGet (HIGH confidence)
- [watch_it on pub.dev](https://pub.dev/packages/watch_it) - v2.4.2, 8K downloads, reactive layer for get_it (HIGH confidence)
- [injectable on pub.dev](https://pub.dev/packages/injectable) - v2.7.1, 293K downloads, code-gen for get_it (HIGH confidence)
- [Provider on pub.dev](https://pub.dev/packages/provider) - Google-endorsed DI/state management (HIGH confidence)
- [Flutter official DI docs](https://docs.flutter.dev/app-architecture/case-study/dependency-injection) - Recommends Provider + constructor injection (HIGH confidence)
- [Global vs Scoped Access](https://codewithandrea.com/articles/global-access-vs-scoped-access/) - Andrea Bizzotto's analysis of service locator vs widget-tree DI (MEDIUM confidence)
- [get_it_modular on pub.dev](https://pub.dev/packages/get_it_modular) - v1.0.0, ~20 downloads, ModuleScope widget for get_it (HIGH confidence)
- [widject_container on pub.dev](https://pub.dev/packages/widject_container) - v2.0.0, ~200 downloads, ScopeWidget-based DI (HIGH confidence)
- [pub.dev scoring](https://pub.dev/help/scoring) - Max 110 points, requires docs, analysis, platform support (HIGH confidence)
