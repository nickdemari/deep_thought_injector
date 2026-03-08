# Phase 2: Core Cleanup - Context

**Gathered:** 2026-03-07
**Status:** Ready for planning

<domain>
## Phase Boundary

Remove dead stub classes (`AutoWiring`, `DeepThoughtConfig`), declare the missing `logging` dependency in pubspec.yaml, and add a public `DeepThought.reset()` method that delegates to `SubEthaScope.reset()`. This phase delivers a clean codebase ready for new feature work. No new capabilities are added — only housekeeping.

</domain>

<decisions>
## Implementation Decisions

### Stub Removal
- Clean delete both `auto_wiring.dart` and `deep_thought_config.dart` — no trace left in the codebase
- Remove any imports or references to either class anywhere
- No TODO comments, no backlog entry — auto-wiring concept is explicitly out of scope (PROJECT.md) and doesn't need tracking
- Barrel file (`lib/deep_thought_injector.dart`) is already correct — neither stub was exported

### Reset Method
- `DeepThought.reset()` delegates to `_scope.reset()` — that's the core behavior
- Must be idempotent — calling reset() on an already-empty scope is a no-op, no exceptions
- Export surface review (SubEthaScope exposing internals) flagged for Phase 3 API surface work, not this phase

### Logging Dependency
- Add `logging: ^1.2.0` to pubspec.yaml `dependencies` section (runtime dep, not dev)
- Don't touch the existing logging approach (static Logger + setter pattern) — just declare the dependency
- The logging pattern itself can be revisited in Phase 3 if needed

### Testing Strategy
- TDD for `reset()` only — write failing tests first, then implement
- Tests go in existing `deep_thought_injector_test.dart` file (new test group)
- Stub removal doesn't need tests — `dart analyze` passing proves it's clean

### Claude's Discretion
- Whether `reset()` also clears `errorNotifier` and resets logger (delegate-only vs full reset — convention-based decision)
- Whether `reset()` cascades to child scopes (parent-only vs recursive — widget lifecycle context)
- Whether `reset()` logs the event (consistent with existing logging vs silent deliberate action)
- Test depth for `reset()` — basic delegation vs edge cases (idempotency, re-registration after reset)

</decisions>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches. This is a housekeeping phase with well-defined requirements (CORE-03, CORE-04, CORE-05, CORE-06).

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `SubEthaScope.reset()` at `lib/src/sub_etha_scope.dart:252` — already disposes Disposable services and clears factories. DeepThought.reset() wraps this.
- `VogonPoetryException` — existing error type for any error reporting if needed
- `deep_thought_injector_test.dart` — existing test file where reset() tests will be added

### Established Patterns
- All DI errors throw `VogonPoetryException` with descriptive cause strings
- `DeepThought` wraps `SubEthaScope` and adds logging + error notification on top
- Tests use `package:test` and `package:mocktail`, mirror `lib/src/` structure under `test/src/`

### Integration Points
- `DeepThought` class at `lib/src/deep_thought_injector.dart` — where `reset()` method will be added
- `pubspec.yaml` — where `logging` dependency will be declared
- No other files reference `AutoWiring` or `DeepThoughtConfig` outside their own files

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 02-core-cleanup*
*Context gathered: 2026-03-07*
