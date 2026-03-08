# Architecture Research

**Domain:** Flutter widget-tree dependency injection integration
**Researched:** 2026-03-07
**Confidence:** HIGH

## Standard Architecture

### System Overview

```
+---------------------------------------------------------------+
|                    Consumer Widget Layer                       |
|                                                               |
|  Widget calls context.question<T>() or context.ponder<T>()   |
|                          |                                    |
+---------------------------------------------------------------+
                           |
             dependOnInheritedWidgetOfExactType /
             getInheritedWidgetOfExactType
                           |
+---------------------------------------------------------------+
|                  Widget Integration Layer                      |
|                                                               |
|  +---------------------+  +-------------------------------+  |
|  | DeepThoughtProvider  |  | BuildContext Extensions        | |
|  | (StatefulWidget)     |  | context.question<T>()         | |
|  |                      |  | context.questionAsync<T>()    | |
|  | Creates/owns a       |  | context.ponder<T>(...)        | |
|  | DeepThought scope    |  | context.deepThought           | |
|  +----------+-----------+  +-------------------------------+  |
|             |                                                 |
|  +----------v-----------+                                     |
|  | _InheritedDeepThought|  (private InheritedWidget)          |
|  | Holds DeepThought ref|  updateShouldNotify => false        |
|  +----------+-----------+                                     |
|             |                                                 |
+---------------------------------------------------------------+
              |
+---------------------------------------------------------------+
|                    Core DI Layer (existing)                    |
|                                                               |
|  +---------------------+  +-------------------------------+  |
|  | DeepThought          |  | SubEthaScope                  | |
|  | (Facade)             |->| (Registry + Hierarchical      | |
|  | ponder / question    |  |  Scope)                       | |
|  +---------------------+  +-------------------------------+  |
|                                                               |
|  +---------------------+  +-------------------------------+  |
|  | VogonPoetryException |  | Lifecycle / Disposable        | |
|  +---------------------+  +-------------------------------+  |
+---------------------------------------------------------------+
```

### How Other Packages Do This

**Provider (the gold standard for InheritedWidget-based DI):**

Provider uses a three-layer architecture. `Provider<T>` (a `SingleChildStatelessWidget`) delegates to `InheritedProvider<T>`, which internally creates `_InheritedProviderScope<T>` -- the actual `InheritedWidget`. The real work happens in `_InheritedProviderScopeElement`, a custom `InheritedElement` that manages lifecycle (create, dispose) and handles selective rebuild via dependency tracking. The `updateShouldNotify` on the InheritedWidget itself always returns `false` -- notification is driven by the Element layer instead.

Key insight: Provider separates the **configuration widget** (what the user writes) from the **InheritedWidget** (the framework mechanism) from the **Element** (where lifecycle logic lives). This is intentionally over-engineered for Provider's needs (change notification, selectors, proxy providers). Deep Thought does not need this complexity because it is a service locator, not a state management solution. No change notification means no custom Element needed.

**Riverpod:**

Riverpod uses `ProviderScope` (a `StatefulWidget`) whose `State.initState()` creates a `ProviderContainer`. That container is then exposed to descendants via `UncontrolledProviderScope`, which is itself an `InheritedWidget`. Scoping works by nesting `ProviderScope` widgets, each creating a child container whose `parent` is the container from the nearest ancestor scope. `ProviderScope.containerOf(context)` retrieves the container.

Key insight: Riverpod's `ProviderContainer` is conceptually identical to `DeepThought` wrapping `SubEthaScope`. The pattern of StatefulWidget owning the container + InheritedWidget exposing it maps directly to what Deep Thought needs.

**get_it / watch_it:**

get_it itself has zero widget-tree integration -- it is a pure service locator with a global singleton (`GetIt.I`). The `watch_it` companion package adds widget-tree reactivity via mixins (`WatchingWidget`, `WatchingStatefulWidget`) that hook into get_it's `ValueListenable`/`Stream` observation. Critically, get_it has no InheritedWidget-based scoping at all -- its `pushNewScope()`/`popScope()` is imperative and global, not tied to the widget tree. This is Deep Thought's competitive advantage.

**flutter_inject (small package, clean reference):**

Uses the simplest possible pattern: a generic `_Injected<T>` extending `InheritedWidget` with `updateShouldNotify => false`, and a static `get<T>(context)` that calls `dependOnInheritedWidgetOfExactType`. Disposal is handled by the enclosing `StatefulWidget.State.dispose()`. This is the minimal viable pattern and the right starting point for Deep Thought.

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| **DeepThoughtProvider** (new) | Widget that creates/owns a `DeepThought` scope and exposes it to descendants | `StatefulWidget` whose `State` creates `DeepThought` in `initState`, disposes via `SubEthaScope.reset()` in `dispose` |
| **_InheritedDeepThought** (new, private) | InheritedWidget that holds the `DeepThought` reference for descendant lookup | Extends `InheritedWidget`, holds `DeepThought` field, `updateShouldNotify => false` |
| **BuildContext extensions** (new) | Ergonomic API for resolving/registering services from widget code | Extension on `BuildContext` providing `question<T>()`, `ponder<T>()`, `deepThought` getter |
| **DeepThought** (existing) | Facade for registration/resolution, logging, error notification | No changes needed to core class |
| **SubEthaScope** (existing) | Core registry with hierarchical parent-child lookup | Minor: `Lifecycle.scoped` needs to be differentiated from `singleton` |

## Recommended Project Structure

```
lib/
+-- deep_thought_injector.dart          # Barrel export (public API surface)
+-- src/
    +-- deep_thought_injector.dart       # DeepThought facade (existing)
    +-- sub_etha_scope.dart              # Core registry (existing)
    +-- vogon_poetry_exception.dart      # Exception type (existing)
    +-- widgets/                         # NEW: Flutter widget integration
    |   +-- deep_thought_provider.dart   # DeepThoughtProvider StatefulWidget
    |   +-- inherited_deep_thought.dart  # _InheritedDeepThought (private)
    +-- extensions/                      # NEW: BuildContext extensions
    |   +-- build_context_extensions.dart # context.question<T>(), etc.
    +-- deep_thought_config.dart         # Config (existing, decide keep/remove)
    +-- auto_wiring.dart                 # Stub (existing, recommend remove)

test/
+-- src/
    +-- deep_thought_injector_test.dart  # Existing unit tests
    +-- async_factory_test.dart          # Existing async tests
    +-- widgets/                         # NEW: Widget tests
    |   +-- deep_thought_provider_test.dart
    +-- extensions/                      # NEW: Extension tests
        +-- build_context_extensions_test.dart
```

### Structure Rationale

- **`widgets/`:** Isolates all Flutter-dependent widget code. Clear boundary between pure Dart DI logic and Flutter integration. Makes it obvious what depends on `flutter/widgets.dart`.
- **`extensions/`:** Keeps BuildContext extensions separate from widget implementations. Extensions are the primary consumer-facing API; widgets are the plumbing. Separating them makes the extension file easy to scan for API surface.
- **Private InheritedWidget:** The `_InheritedDeepThought` class should be private (prefixed `_`) and live in the same file as `DeepThoughtProvider`, OR in its own file imported only by the provider widget. The consumer never interacts with the InheritedWidget directly -- they use the extension or the `DeepThoughtProvider.of(context)` static method.
- **No subdirectory for existing code:** Existing files stay flat under `src/` to avoid a disruptive reorganization.

### Alternative: Flat Structure

Given there are only 2-3 new files, keeping everything flat under `src/` is also reasonable:

```
lib/src/
+-- deep_thought_provider.dart       # Widget + private InheritedWidget
+-- build_context_extensions.dart    # Extensions
+-- deep_thought_injector.dart       # Existing
+-- sub_etha_scope.dart              # Existing
+-- vogon_poetry_exception.dart      # Existing
```

**Recommendation:** Go flat. The package is small. Subdirectories add navigational overhead for minimal organizational benefit at this scale. If the package grows beyond 10 source files, reconsider.

## Architectural Patterns

### Pattern 1: StatefulWidget + Private InheritedWidget (The Provider Widget)

**What:** A `StatefulWidget` that creates and owns a `DeepThought` instance. Its `State.build()` returns a private `InheritedWidget` wrapping the child tree. `State.dispose()` calls `SubEthaScope.reset()` to clean up scoped services.

**When to use:** This is THE pattern for exposing a DI scope to a widget subtree. Every major Flutter DI package uses some variant of it.

**Trade-offs:**
- Pro: Lifecycle is automatic -- scope lives and dies with the widget
- Pro: No ceremony -- just wrap a subtree with `DeepThoughtProvider`
- Pro: Nesting creates parent-child scopes naturally
- Con: `updateShouldNotify => false` means no reactive rebuilds (fine for DI; bad for state management)

**Example:**

```dart
class DeepThoughtProvider extends StatefulWidget {
  const DeepThoughtProvider({
    super.key,
    required this.child,
    this.registrations,
    this.parent,
  });

  final Widget child;
  final void Function(DeepThought dt)? registrations;
  final DeepThought? parent; // explicit parent for non-tree scoping

  // The "of" pattern -- convention for all InheritedWidget-backed widgets
  static DeepThought of(BuildContext context) {
    final inherited = context
        .dependOnInheritedWidgetOfExactType<_InheritedDeepThought>();
    assert(inherited != null, 'No DeepThoughtProvider found in widget tree');
    return inherited!.deepThought;
  }

  static DeepThought? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_InheritedDeepThought>()
        ?.deepThought;
  }

  @override
  State<DeepThoughtProvider> createState() => _DeepThoughtProviderState();
}

class _DeepThoughtProviderState extends State<DeepThoughtProvider> {
  late final DeepThought _deepThought;

  @override
  void initState() {
    super.initState();
    // Create child scope from parent if available, otherwise new root
    final parent = widget.parent ??
        _findAncestorDeepThought(context);
    _deepThought = parent?.createChildScope() ?? DeepThought();

    // Run user-provided registrations
    widget.registrations?.call(_deepThought);
  }

  DeepThought? _findAncestorDeepThought(BuildContext context) {
    // Use getInheritedWidgetOfExactType (no rebuild dependency)
    return context
        .getInheritedWidgetOfExactType<_InheritedDeepThought>()
        ?.deepThought;
  }

  @override
  void dispose() {
    _deepThought._scope.reset(); // disposes Disposable services
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _InheritedDeepThought(
      deepThought: _deepThought,
      child: widget.child,
    );
  }
}

class _InheritedDeepThought extends InheritedWidget {
  const _InheritedDeepThought({
    required this.deepThought,
    required super.child,
  });

  final DeepThought deepThought;

  @override
  bool updateShouldNotify(_InheritedDeepThought oldWidget) => false;
}
```

### Pattern 2: BuildContext Extensions (The Ergonomic API)

**What:** Extension methods on `BuildContext` that look up the nearest `DeepThought` and delegate to its methods. This is how consumers interact with DI in widget code.

**When to use:** Always. This is the primary public API for widget-tree DI. Consumers should rarely need to interact with `DeepThoughtProvider` directly beyond wrapping their subtree.

**Trade-offs:**
- Pro: Terse, discoverable API (`context.question<MyService>()`)
- Pro: Follows established Flutter conventions (`context.read<T>()`, `Theme.of(context)`)
- Con: Requires a `DeepThoughtProvider` ancestor -- will throw if missing (but that is correct behavior)

**Example:**

```dart
extension DeepThoughtContext on BuildContext {
  /// Get the nearest DeepThought scope.
  DeepThought get deepThought => DeepThoughtProvider.of(this);

  /// Resolve a service from the nearest scope.
  T question<T>({String? name}) => deepThought.question<T>(name: name);

  /// Resolve a service asynchronously.
  Future<T> questionAsync<T>({String? name}) =>
      deepThought.questionAsync<T>(name: name);

  /// Register a service in the nearest scope.
  void ponder<T>(
    T Function() factory, {
    bool lazy = true,
    Lifecycle lifecycle = Lifecycle.singleton,
    String? name,
  }) => deepThought.ponder<T>(factory, lazy: lazy, lifecycle: lifecycle, name: name);
}
```

### Pattern 3: Automatic Parent-Child Scoping via Widget Nesting

**What:** When `DeepThoughtProvider` widgets are nested, each inner provider automatically creates a child `SubEthaScope` whose parent is the scope from the nearest ancestor provider. Service lookup cascades up the scope chain, mirroring the widget tree hierarchy.

**When to use:** Feature-level or route-level scoping. A login feature registers auth services in a nested scope; when the user logs out and the widget is removed, those services are cleaned up.

**Trade-offs:**
- Pro: Scoping follows widget tree naturally -- no manual scope management
- Pro: Child scopes inherit parent registrations via fallback lookup
- Pro: Cleanup is automatic on widget disposal
- Con: Scope hierarchy is implicit -- debugging "which scope provided this service?" requires understanding the widget tree

**Critical implementation detail:** In `initState`, the provider must find its ancestor using `getInheritedWidgetOfExactType` (not `dependOnInheritedWidgetOfExactType`). The `get` variant does NOT create a rebuild dependency, which is correct because the provider should not rebuild when an ancestor provider changes. The `dependOn` variant would create a spurious rebuild dependency.

## Data Flow

### Service Registration Flow

```
App startup / Widget mount
    |
    v
DeepThoughtProvider.initState()
    |
    +--> Find ancestor _InheritedDeepThought (getInheritedWidgetOfExactType)
    |        |
    |        +--> Found: create child scope (DeepThought with parent SubEthaScope)
    |        +--> Not found: create root scope (new DeepThought)
    |
    +--> Call widget.registrations(deepThought)
    |        |
    |        +--> User calls deepThought.ponder<ServiceA>(...)
    |        +--> User calls deepThought.ponder<ServiceB>(...)
    |
    +--> Build: return _InheritedDeepThought(deepThought: ..., child: ...)
```

### Service Resolution Flow

```
Widget.build(context)
    |
    v
context.question<T>()
    |
    v
DeepThoughtProvider.of(context)
    |  (dependOnInheritedWidgetOfExactType<_InheritedDeepThought>)
    v
_InheritedDeepThought.deepThought
    |
    v
DeepThought.question<T>()
    |
    v
SubEthaScope.locate<T>()
    |
    +--> Found locally: return instance
    +--> Not found locally, has parent: parent.locate<T>()
    +--> Not found anywhere: throw VogonPoetryException
```

### Scope Disposal Flow

```
Widget removed from tree
    |
    v
_DeepThoughtProviderState.dispose()
    |
    v
SubEthaScope.reset()
    |
    +--> Iterate _factories
    |       |
    |       +--> instance is Disposable? -> call dispose()
    |
    +--> Clear _factories map
    |
    v
super.dispose()
```

### Key Data Flows

1. **Registration at mount:** Services are registered during `DeepThoughtProvider.initState()` via the `registrations` callback. This happens once and is not re-executed on rebuilds.
2. **Resolution during build:** Widgets resolve services during `build()` via `context.question<T>()`. This uses `dependOnInheritedWidgetOfExactType`, but since `updateShouldNotify => false`, it never triggers rebuilds from the DI layer itself.
3. **Hierarchical fallback:** When a service is not found in the current scope, `SubEthaScope.locate()` delegates to `parent.locate()`, walking up the scope chain until found or throwing.
4. **Disposal cascade:** When a `DeepThoughtProvider` is removed from the tree, its `State.dispose()` resets the scope, disposing all `Disposable` services registered in that scope (but NOT parent scopes).

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| Simple app (1-2 scopes) | Single root `DeepThoughtProvider` at `MaterialApp` level. All services registered there. No nesting needed. |
| Medium app (feature scoping) | Root provider for global services (HTTP client, auth). Nested providers per feature route for feature-specific services. |
| Large app (complex routing) | Root + route-level + component-level scoping. Consider a `DeepThoughtProvider.overrides()` constructor for testing individual widget subtrees. |

### Scaling Priorities

1. **First concern -- scope granularity:** Most apps only need 1-2 scopes. Do not over-scope. A root scope + one level of feature scoping covers 95% of use cases.
2. **Second concern -- registration phase cost:** If a scope has many registrations and the widget mounts/unmounts frequently (e.g., in a `TabBarView`), eager instantiation (`lazy: false`) will cause performance issues. Default to `lazy: true` and document this.

## Anti-Patterns

### Anti-Pattern 1: Exposing the InheritedWidget Publicly

**What people do:** Make the `InheritedWidget` subclass public so consumers can extend or access it directly.
**Why it is wrong:** Couples consumers to an implementation detail. If the internal mechanism changes (e.g., switching to `InheritedModel` for selective rebuilds in the future), every consumer breaks.
**Do this instead:** Keep `_InheritedDeepThought` private. Expose only `DeepThoughtProvider` (the StatefulWidget) and the BuildContext extensions. Follow the Flutter convention where `Theme` is public but `_InheritedTheme` is private.

### Anti-Pattern 2: Using dependOn in initState

**What people do:** Call `context.dependOnInheritedWidgetOfExactType()` inside `initState()` to find the parent scope.
**Why it is wrong:** `dependOnInheritedWidgetOfExactType` cannot be called during `initState` -- the framework throws an assertion error. Even if it worked, it would create an unwanted rebuild dependency.
**Do this instead:** Use `context.getInheritedWidgetOfExactType()` for parent lookup during initialization. This does not create a dependency and is safe to call from `initState` (though technically should be done in `didChangeDependencies` -- but since the InheritedWidget never notifies, `initState` is fine in practice using a post-frame callback or the `get` variant).

### Anti-Pattern 3: Re-creating the Scope on Widget Rebuild

**What people do:** Create a new `DeepThought` in `build()` or in response to widget configuration changes.
**Why it is wrong:** Every rebuild creates a fresh scope, losing all singleton instances and breaking service identity. Services that hold state (database connections, caches) would be re-created constantly.
**Do this instead:** Create the `DeepThought` instance exactly once in `initState()`. Store it in a `late final` field. Never recreate it. The scope's lifetime is the widget's lifetime, period.

### Anti-Pattern 4: Registering Services During build()

**What people do:** Call `context.ponder<T>(...)` inside a widget's `build()` method.
**Why it is wrong:** `build()` can be called multiple times. Duplicate registrations will throw `VogonPoetryException`. Even if you add duplicate-checking, it is semantically wrong -- registration is a setup concern, not a render concern.
**Do this instead:** Register services in the `registrations` callback of `DeepThoughtProvider`, which runs once in `initState()`.

### Anti-Pattern 5: Global Scope as Escape Hatch

**What people do:** Expose a `DeepThought.instance` global singleton for use outside the widget tree.
**Why it is wrong:** Defeats the entire purpose of widget-scoped DI. Mixes two paradigms (global service locator and scoped DI), making testing and lifecycle management unpredictable.
**Do this instead:** If code outside the widget tree needs services, pass the `DeepThought` instance explicitly. The package's value proposition is widget-tree scoping -- do not undermine it with a global backdoor.

## Integration Points

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| DeepThoughtProvider --> DeepThought | Direct method calls | Provider owns and delegates to DeepThought. Provider is the lifecycle owner; DeepThought is the logic engine. |
| BuildContext extensions --> DeepThoughtProvider | Static `of(context)` method | Extensions are syntactic sugar over `DeepThoughtProvider.of(context).method()`. |
| DeepThought --> SubEthaScope | Direct method calls | Existing pattern, unchanged. DeepThought is a facade over SubEthaScope. |
| Nested DeepThoughtProvider --> Parent scope | `SubEthaScope(parent:)` constructor | Parent-child relationship established at `initState` time. Scope hierarchy mirrors widget tree nesting. |

### Barrel Export Updates

The barrel file (`lib/deep_thought_injector.dart`) needs to export the new public API:

```dart
// Existing exports
export 'src/deep_thought_injector.dart';
export 'src/sub_etha_scope.dart';
export 'src/vogon_poetry_exception.dart';

// New exports
export 'src/deep_thought_provider.dart';         // DeepThoughtProvider widget
export 'src/build_context_extensions.dart';       // BuildContext extensions
```

The `_InheritedDeepThought` is private and NOT exported.

## Build Order (Dependencies Between Components)

The following build order respects dependencies:

1. **Lifecycle.scoped differentiation** -- Modify `SubEthaScope` so `Lifecycle.scoped` behaves differently from `singleton` (scoped services are singletons within their scope but do not propagate to child scopes via parent lookup). This is a pure Dart change with no Flutter dependency. Must come first because the provider's disposal logic depends on scoped semantics being correct.

2. **_InheritedDeepThought** -- Private InheritedWidget. Trivial implementation (holds a `DeepThought` reference, `updateShouldNotify => false`). No dependencies beyond Flutter SDK and the existing `DeepThought` class.

3. **DeepThoughtProvider** -- StatefulWidget that creates/owns a `DeepThought` and builds `_InheritedDeepThought`. Depends on `_InheritedDeepThought`, `DeepThought`, `SubEthaScope`. This is the core integration piece.

4. **BuildContext extensions** -- Extension methods on `BuildContext`. Depends on `DeepThoughtProvider.of()`. Pure syntactic sugar, but critical for developer ergonomics.

5. **Barrel export update** -- Add new exports to `lib/deep_thought_injector.dart`. Depends on all above files existing.

6. **Widget tests** -- Test `DeepThoughtProvider` and extensions using `testWidgets`. Depends on all production code being in place.

**Parallelizable:** Steps 2 and 3 can be done in one pass (they are tightly coupled). Step 4 can be done immediately after 3. Steps 1 is independent and can happen in parallel with 2-3.

## DeepThought API Exposure Consideration

Currently `DeepThought._scope` is private (no underscore in the field name, but `SubEthaScope` is the private registry). The `DeepThoughtProvider.State.dispose()` needs to call `_scope.reset()`. Two options:

1. **Add a `reset()` method to `DeepThought`** that delegates to `_scope.reset()`. This keeps `SubEthaScope` encapsulated and is the correct approach.
2. **Make `_scope` package-private** via a `@visibleForTesting`-style annotation. Less clean, but faster.

**Recommendation:** Option 1. Add `DeepThought.reset()` as a public method. It is a legitimate public API -- consumers may want to reset a scope manually (e.g., on logout). The provider's `dispose()` calls `_deepThought.reset()`.

## Sources

- [Flutter InheritedWidget class documentation](https://api.flutter.dev/flutter/widgets/InheritedWidget-class.html)
- [Provider package](https://pub.dev/packages/provider)
- [InheritedProvider class documentation](https://pub.dev/documentation/provider/latest/provider/InheritedProvider-class.html)
- [Riverpod ProviderScope class documentation](https://pub.dev/documentation/flutter_riverpod/latest/flutter_riverpod/ProviderScope-class.html)
- [Riverpod Scopes documentation](https://docs-v2.riverpod.dev/docs/concepts/scopes)
- [ProviderContainers/ProviderScopes](https://riverpod.dev/docs/concepts2/containers)
- [flutter_inject package](https://pub.dev/packages/flutter_inject)
- [watch_it package](https://pub.dev/packages/watch_it)
- [get_it package](https://pub.dev/packages/get_it)
- [dependOnInheritedWidgetOfExactType documentation](https://api.flutter.dev/flutter/widgets/BuildContext/dependOnInheritedWidgetOfExactType.html)
- [getInheritedWidgetOfExactType documentation](https://api.flutter.dev/flutter/widgets/BuildContext/getInheritedWidgetOfExactType.html)
- [Dart package layout conventions](https://dart.dev/tools/pub/package-layout)
- [Provider architecture diagrams (Medium)](https://medium.com/flutter-community/understanding-provider-in-diagrams-part-3-architecture-a145e4fbbde1)
- [Flutter Provider Best Practices (DCM)](https://dcm.dev/blog/2026/03/04/flutter-provider-best-practices-youre-probably-missing)

---
*Architecture research for: Flutter widget-tree dependency injection integration*
*Researched: 2026-03-07*
