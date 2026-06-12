---
phase: 01-core-bug-fixes
plan: 01
subsystem: di-container
tags: [dart, async, completer, singleton, race-condition, tdd]

# Dependency graph
requires: []
provides:
  - "Race-safe async singleton resolution via Completer pattern"
  - "Unit tests covering concurrent access, error propagation, retry, cached instance, and transient behavior"
affects: [02-core-bug-fixes, 04-widget-layer]

# Tech tracking
tech-stack:
  added: []
  patterns: ["Completer-guarded async singleton resolution in _ServiceFactory"]

key-files:
  created:
    - "test/src/sub_etha_scope_test.dart"
  modified:
    - "lib/src/sub_etha_scope.dart"

key-decisions:
  - "Used Completer<T> field on _ServiceFactory rather than external Map to keep guard co-located with factory state"
  - "Clear _asyncCompleter on both success and failure to allow retry after errors and GC after success"
  - "Used expectLater for async error matchers to prevent unhandled zone exceptions in tests"

patterns-established:
  - "Completer pattern: set synchronously before first await, complete/completeError in try/catch, clear in finally"
  - "TDD for bug fixes: write failing tests that expose the race window with Future.delayed, then fix"

requirements-completed: [CORE-01, TEST-01]

# Metrics
duration: 3min
completed: 2026-03-08
---

# Phase 01 Plan 01: Async Singleton Race Condition Fix Summary

**Completer-guarded async singleton resolution preventing duplicate factory invocations during concurrent locateAsync calls**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-08T02:13:30Z
- **Completed:** 2026-03-08T02:16:29Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Fixed race condition where concurrent `locateAsync` calls each invoked the factory independently, violating the singleton contract
- Added Completer<T> guard that ensures exactly one factory invocation with all concurrent callers awaiting the same future
- Error propagation to all concurrent waiters with retry capability after failure
- 5 new unit tests covering concurrent access (2 and 3 callers), error propagation + retry, cached instance, and transient non-interference

## Task Commits

Each task was committed atomically:

1. **Task 1: Write failing tests for async singleton race condition** - `36d2660` (test)
2. **Task 2: Fix async singleton race condition with Completer pattern** - `3294849` (fix)

_TDD flow: RED (failing tests) then GREEN (implementation fix)_

## Files Created/Modified
- `test/src/sub_etha_scope_test.dart` - 5 tests in 'async singleton race condition' group covering concurrent access, error propagation, retry, cached instance, and transient behavior
- `lib/src/sub_etha_scope.dart` - Added `Completer<T>? _asyncCompleter` to `_ServiceFactory`, replaced naive singleton resolution in `locateAsync` with Completer-guarded logic

## Decisions Made
- Used `Completer<T>` field on `_ServiceFactory` rather than an external `Map<_ServiceIdentifier, Completer>` -- keeps the guard co-located with the factory state it protects, no cross-referencing needed
- Clear `_asyncCompleter` on both success and failure paths (in `finally` block) -- enables retry after factory errors and GC after successful resolution
- Did NOT remove `_lock` field as instructed (cleanup deferred to Phase 2)
- Did NOT touch `locate<T>()` as instructed (circular dependency changes in Plan 02)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed test using expect instead of expectLater for async error matchers**
- **Found during:** Task 2 (running tests after implementing fix)
- **Issue:** `expect(future, throwsA(...))` returns a Future but wasn't awaited, causing the VogonPoetryException to escape as an unhandled zone error
- **Fix:** Changed to `await expectLater(future, throwsA(...))` for proper async matcher handling
- **Files modified:** test/src/sub_etha_scope_test.dart
- **Verification:** All 12 tests pass, no unhandled errors
- **Committed in:** 3294849 (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Necessary for test correctness. No scope creep.

## Issues Encountered
- Pre-existing `dart analyze --fatal-infos` has 42 info/warning-level violations across the codebase (missing docs, trailing commas, import ordering, unused `_lock` field). Zero new issues introduced by this plan. These are out of scope per deviation rules.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Async singleton race condition is fixed and tested, safe for concurrent widget tree access in Phase 4+
- Plan 01-02 (circular dependency detection) can proceed independently -- `locate<T>()` was intentionally untouched
- The `_lock` field remains as a placeholder for Phase 2 cleanup

## Self-Check: PASSED

- [x] test/src/sub_etha_scope_test.dart exists
- [x] lib/src/sub_etha_scope.dart exists
- [x] 01-01-SUMMARY.md exists
- [x] Commit 36d2660 exists
- [x] Commit 3294849 exists

---
*Phase: 01-core-bug-fixes*
*Completed: 2026-03-08*
