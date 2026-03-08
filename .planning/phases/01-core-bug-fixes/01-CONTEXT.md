# Phase 1: Core Bug Fixes - Context

**Gathered:** 2026-03-07
**Status:** Ready for planning

<domain>
## Phase Boundary

Fix the async singleton race condition in `SubEthaScope.locateAsync()` and add circular dependency detection during resolution. Both fixes must have unit tests proving correctness. This phase does NOT add new features — it hardens the existing core before widget integration amplifies concurrency.

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
User delegated all implementation decisions for this phase. Standard patterns apply:

- **Async race condition fix:** Use Completer pattern — first caller creates a Completer and starts the factory, subsequent concurrent callers await the same Completer's future. This ensures the factory is invoked exactly once for lazy singletons.
- **Circular dependency detection:** Use a Set-based resolution stack — track types currently being resolved, throw descriptive `VogonPoetryException` if a type is encountered while already in the resolution stack. Show full dependency chain in error message (e.g., "Circular dependency detected: A → B → C → A").
- **Error messaging:** Include the full type chain in circular dependency errors and the type name in async race condition scenarios. Errors should be developer-friendly and actionable.
- **Test strategy:** Test concurrent access with multiple Future.wait calls for async race condition. Test direct circular (A → B → A) and transitive circular (A → B → C → A) dependencies.

</decisions>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches. The Completer pattern for async singletons and Set-based circular detection are well-documented, battle-tested patterns.

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `SubEthaScope.locateAsync()` at `lib/src/sub_etha_scope.dart:108` — the method to fix for async race condition
- `SubEthaScope.locate()` at `lib/src/sub_etha_scope.dart:87` — needs circular dependency guard added
- `_ServiceFactory<T>` — may need a `Completer<T>?` field added for async resolution tracking
- `VogonPoetryException` — existing exception type for all error reporting

### Established Patterns
- All DI errors throw `VogonPoetryException` with descriptive cause string
- `_ServiceFactory` stores sync/async factories and cached instances
- `_ServiceIdentifier` is the composite key (Type + optional name)

### Integration Points
- `DeepThought.question()` / `questionAsync()` catch errors from SubEthaScope and add logging — circular dep errors will flow through this existing error handling
- Existing test structure in `test/src/` with `deep_thought_injector_test.dart` and `async_factory_test.dart` — new tests follow same patterns

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-core-bug-fixes*
*Context gathered: 2026-03-07*
