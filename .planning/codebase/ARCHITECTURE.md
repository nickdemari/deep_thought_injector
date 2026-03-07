# Architecture

**Analysis Date:** 2026-03-07

## Pattern Overview

**Overall:** Service Locator / Dependency Injection Container

**Key Characteristics:**
- Single container class (`DeepThought`) wraps a scoping mechanism (`SubEthaScope`) that holds all registrations
- Factory-based registration: services are registered via factory functions, not direct instances
- Supports synchronous and asynchronous service resolution
- Hierarchical scoping via parent-child `SubEthaScope` chains
- Three lifecycle modes: singleton (default), transient, and scoped
- Named registrations allow multiple services of the same type
- Hitchhiker's Guide to the Galaxy theming throughout the API surface (`ponder`, `question`, `VogonPoetryException`, `SubEthaScope`)

## Layers

**Public API Layer (DeepThought):**
- Purpose: User-facing facade for registering and resolving dependencies
- Location: `lib/src/deep_thought_injector.dart`
- Contains: `DeepThought` class with `ponder()`, `ponderAsync()`, `question()`, `questionAsync()`, `createChildScope()`
- Depends on: `SubEthaScope`, `VogonPoetryException`, `logging` package
- Used by: Application code that consumes this library

**Scope/Registry Layer (SubEthaScope):**
- Purpose: Core service registry that stores factories and resolved instances, supports hierarchical lookup
- Location: `lib/src/sub_etha_scope.dart`
- Contains: `SubEthaScope` class, `_ServiceFactory<T>` (private), `_ServiceIdentifier` (private), `Lifecycle` enum, `Disposable` abstract class
- Depends on: `VogonPoetryException`, `dart:async`
- Used by: `DeepThought`

**Configuration Layer:**
- Purpose: Environment-aware configuration for the injector
- Location: `lib/src/deep_thought_config.dart`
- Contains: `DeepThoughtConfig` class with environment, overrides, and secrets fields
- Depends on: Nothing
- Used by: `AutoWiring`

**Auto-Wiring Layer (Stub):**
- Purpose: Automatic dependency registration based on configuration. Currently a partial implementation/stub.
- Location: `lib/src/auto_wiring.dart`
- Contains: `AutoWiring` class with static `autoWire()` method
- Depends on: `DeepThought`, `DeepThoughtConfig`, `logging` package
- Used by: Not exported publicly; intended for future use

**Exception Layer:**
- Purpose: Custom exception type for all injector errors
- Location: `lib/src/vogon_poetry_exception.dart`
- Contains: `VogonPoetryException` class with cause, errorCode, and stackTrace
- Depends on: Nothing
- Used by: `DeepThought`, `SubEthaScope`

**Barrel Export:**
- Purpose: Public API surface definition
- Location: `lib/deep_thought_injector.dart`
- Exports: `DeepThought`, `SubEthaScope` (including `Lifecycle`, `Disposable`), `VogonPoetryException`
- Does NOT export: `DeepThoughtConfig`, `AutoWiring` (these are internal/incomplete)

## Data Flow

**Service Registration (Sync):**

1. Consumer calls `deepThought.ponder<T>(factory, lazy: true/false, lifecycle: ..., name: ...)`
2. `DeepThought.ponder()` delegates to `SubEthaScope.register<T>()`
3. `SubEthaScope` creates a `_ServiceIdentifier(T, name)` key
4. Checks for duplicate registration; throws `VogonPoetryException` if key exists
5. Creates `_ServiceFactory<T>` wrapping the factory function
6. If `lazy: false` and `lifecycle: singleton`, invokes factory immediately to create and cache the instance
7. Stores the `_ServiceFactory` in `_factories` map

**Service Resolution (Sync):**

1. Consumer calls `deepThought.question<T>(name: ...)`
2. `DeepThought.question()` delegates to `SubEthaScope.locate<T>()`
3. `SubEthaScope` builds `_ServiceIdentifier(T, name)` and looks up in `_factories`
4. If not found in current scope, delegates to `parent.locate<T>()` (hierarchical lookup)
5. If not found anywhere, throws `VogonPoetryException`
6. If found with async factory, throws `VogonPoetryException` (must use `locateAsync`)
7. If `lifecycle == transient`, invokes factory and returns new instance every time
8. If `lifecycle == singleton`, returns cached instance or creates-and-caches on first access
9. On any error in `DeepThought.question()`, logs via `Logger`, optionally calls `errorNotifier`, and wraps in `VogonPoetryException`

**Service Resolution (Async):**

1. Consumer calls `await deepThought.questionAsync<T>(name: ...)`
2. Delegates to `SubEthaScope.locateAsync<T>()`
3. Same lookup logic as sync, but awaits async factories
4. Falls back to sync factory if no async factory is registered

**Child Scope Creation:**

1. Consumer calls `deepThought.createChildScope()`
2. Creates new `DeepThought` wrapping a new `SubEthaScope(parent: currentScope)`
3. Child scope lookups cascade to parent if service not found locally

**State Management:**
- All state lives in `SubEthaScope._factories` map (keyed by type + optional name)
- Singleton instances are cached on the `_ServiceFactory.instance` field
- `SubEthaScope.reset()` disposes `Disposable` instances and clears the map
- `SubEthaScope.override<T>()` replaces a registration with a pre-built instance (useful for testing)

## Key Abstractions

**DeepThought (Service Locator Facade):**
- Purpose: Single entry point for all DI operations
- Location: `lib/src/deep_thought_injector.dart`
- Pattern: Facade over `SubEthaScope`; adds logging and error notification

**SubEthaScope (Registry + Hierarchical Scope):**
- Purpose: Stores registrations, resolves services, supports parent-child scoping
- Location: `lib/src/sub_etha_scope.dart`
- Pattern: Map-based registry with composite key (`_ServiceIdentifier`) and chain-of-responsibility parent lookup

**_ServiceFactory<T> (Registration Metadata):**
- Purpose: Wraps a factory function (sync or async), its lifecycle, laziness flag, and cached instance
- Location: `lib/src/sub_etha_scope.dart` (private)
- Pattern: Value object holding both the creation strategy and the cached result

**Lifecycle (Registration Strategy):**
- Purpose: Determines instance creation behavior
- Location: `lib/src/sub_etha_scope.dart`
- Values: `singleton` (one instance, cached), `transient` (new instance per resolution), `scoped` (defined but not yet differentiated from singleton in current implementation)

**VogonPoetryException (Error Type):**
- Purpose: Single exception type for all DI errors with optional error code and stack trace
- Location: `lib/src/vogon_poetry_exception.dart`
- Pattern: Custom exception implementing `Exception`

**Disposable (Cleanup Interface):**
- Purpose: Interface for services that need cleanup when scope is reset
- Location: `lib/src/sub_etha_scope.dart`
- Pattern: Abstract class with `dispose()` method; checked during `SubEthaScope.reset()`

## Entry Points

**Library Entry Point:**
- Location: `lib/deep_thought_injector.dart`
- Triggers: `import 'package:deep_thought_injector/deep_thought_injector.dart'`
- Responsibilities: Barrel export defining the public API surface. Exports `DeepThought`, `SubEthaScope`, `Lifecycle`, `Disposable`, `VogonPoetryException`

**Primary Usage Entry:**
- Location: `lib/src/deep_thought_injector.dart` (the `DeepThought` class)
- Triggers: Consumer instantiates `DeepThought()` and calls `ponder()`/`question()`
- Responsibilities: All registration and resolution operations

## Error Handling

**Strategy:** Single custom exception type (`VogonPoetryException`) for all error conditions, with logging and optional external notification.

**Patterns:**
- `SubEthaScope` throws `VogonPoetryException` for: duplicate registration, service not found, wrong resolution method (sync vs async)
- `DeepThought` catches errors from `SubEthaScope`, logs via `Logger.severe()`, optionally forwards to `errorNotifier` callback, then re-throws as `VogonPoetryException` with stack trace
- `AutoWiring` silently swallows all exceptions (catch-and-ignore pattern for duplicate registrations and missing configs)
- `VogonPoetryException` supports optional `errorCode` (static const `serviceNotFoundError = 1001` defined but not used in code) and optional `stackTrace`

## Cross-Cutting Concerns

**Logging:**
- Uses Dart `logging` package (`Logger` class)
- Default logger name: `'DeepThought'`
- Custom logger injectable via static setter `DeepThought.logger = customLogger`
- Logs at `severe` level on service resolution failures

**Validation:**
- Duplicate registration check in `SubEthaScope.register()` / `registerAsync()`
- Type check in `AutoWiring.autoWire()` for `DeepThought` instance
- Async/sync factory mismatch check in `SubEthaScope.locate()` / `locateAsync()`

**Authentication:** Not applicable (library package, not an application)

**Error Notification:**
- Optional `errorNotifier` callback on `DeepThought`: `void Function(Exception e, StackTrace s)?`
- Called on resolution failures; intended for integration with crash reporting (Sentry, Crashlytics)

---

*Architecture analysis: 2026-03-07*
