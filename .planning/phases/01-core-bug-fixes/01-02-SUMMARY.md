---
phase: 01-core-bug-fixes
plan: 02
subsystem: di-container
tags: [dart, circular-dependency, cycle-detection, zone, tdd, set]

# Dependency graph
requires:
  - phase: 01-core-bug-fixes-plan-01
    provides: "Completer-guarded async singleton resolution, _ServiceFactory with _asyncCompleter field"
provides:
  - "Set-based circular dependency detection in locate() via _currentResolutionStack"
  - "Zone-based circular dependency detection in locateAsync() via zone values"
  - "Descriptive VogonPoetryException with full dependency chain string"
  - "6 unit tests covering direct, transitive, cross-scope, named, async, and non-circular cases"
affects: [04-widget-layer, 02-dead-code-cleanup]

# Tech tracking
tech-stack:
  added: []
  patterns: ["Zone-based resolution stack for async cycle detection", "Instance field resolution stack for sync cycle detection"]

key-files:
  created: []
  modified:
    - "lib/src/sub_etha_scope.dart"
    - "test/src/sub_etha_scope_test.dart"

key-decisions:
  - "Used Zone values (not instance field) for async cycle detection to avoid false positives with concurrent callers"
  - "Used instance field _currentResolutionStack for sync cycle detection (no async yield issues)"
  - "Silenced Completer error futures with unawaited(.then(onError:)) to prevent unhandled error reports during cycle errors"
  - "Moved Completer/cached-instance fast paths before cycle check in locateAsync to avoid false positives from concurrent singleton resolution"

patterns-established:
  - "Zone-based context threading: use runZoned with zone values to pass context through async factory closures without instance field leakage"
  - "Dual-strategy cycle detection: instance field for sync, zone value for async"

requirements-completed: [CORE-02, TEST-02]

# Metrics
duration: 9min
completed: 2026-03-08
---

# Phase 01 Plan 02: Circular Dependency Detection Summary

**Set-based circular dependency detection using instance field for sync and Zone values for async, with descriptive chain error messages**

## Performance

- **Duration:** 9 min
- **Started:** 2026-03-08T02:19:05Z
- **Completed:** 2026-03-08T02:28:51Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Added circular dependency detection to both `locate()` and `locateAsync()` in SubEthaScope
- Error messages include full dependency chain (e.g., "Circular dependency detected: ServiceA -> ServiceB -> ServiceA")
- Used Zone values for async path to avoid false positives with concurrent callers (instance fields leak across async yields)
- Named services tracked as distinct identifiers -- same type with different names are separate in cycle detection
- Resolution stack forwarded through parent-child scope chain for cross-scope cycle detection
- 6 new tests: direct cycle, transitive cycle, non-circular control, cross-scope, named services, async cycle

## Task Commits

Each task was committed atomically:

1. **Task 1: Write failing tests for circular dependency detection** - `2fcf811` (test)
2. **Task 2: Implement Set-based circular dependency detection** - `8188202` (fix)

_TDD flow: RED (failing tests with stack overflow) then GREEN (detection implementation)_

## Files Created/Modified
- `lib/src/sub_etha_scope.dart` - Added `_resolutionStackZoneKey` zone key, `_currentResolutionStack` instance field, `resolutionStack` parameter on `locate()` and `locateAsync()`, cycle detection logic with `_ServiceIdentifier` Set, Zone-based factory invocation in `locateAsync()`, Completer error silencing
- `test/src/sub_etha_scope_test.dart` - Added 3 helper classes (ServiceA, ServiceB, ServiceC) and 'circular dependency detection' group with 6 tests

## Decisions Made
- **Zone values for async cycle detection:** The plan specified using `_currentResolutionStack` instance field for both sync and async. This caused false positives with concurrent `locateAsync` calls (field leaks across `await` boundaries). Switched to Dart Zone values (`runZoned` with `zoneValues`) for the async path, which flow correctly through async closures without leaking to independent callers.
- **Completer error silencing:** When a circular dependency throws inside an async factory, the Completer's error future has no listeners (the caller gets the error via `rethrow`). Added `unawaited(completer.future.then((_) {}, onError: (_) {}))` to prevent unhandled error reports.
- **Fast path ordering:** Moved Completer/cached-instance checks before cycle detection in `locateAsync` so concurrent singleton callers waiting on an in-progress resolution don't trigger false cycle detection.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed async cycle detection using Zone values instead of instance field**
- **Found during:** Task 2 (running tests after initial implementation)
- **Issue:** `_currentResolutionStack` instance field leaked across `await` boundaries, causing false positive cycle detection for concurrent `locateAsync` calls to the same service type
- **Fix:** Used Dart Zone values (`runZoned` with `_resolutionStackZoneKey`) for async factory invocations. Zone values flow through the async closure's execution context without leaking to independent concurrent callers on the same scope.
- **Files modified:** lib/src/sub_etha_scope.dart
- **Verification:** All 5 async singleton race condition tests from Plan 01 pass, plus all 6 new circular dependency tests pass
- **Committed in:** 8188202 (Task 2 commit)

**2. [Rule 1 - Bug] Silenced unhandled Completer error future during cycle errors**
- **Found during:** Task 2 (async circular dependency test threw unhandled error)
- **Issue:** When circular dependency throws inside an async factory, the Completer completed with error but had no listeners, causing unhandled error report in test
- **Fix:** Added `unawaited(completer.future.then((_) {}, onError: (_) {}))` after `completeError` to silence the orphaned error future
- **Files modified:** lib/src/sub_etha_scope.dart
- **Verification:** Async circular dependency test passes without unhandled error warnings
- **Committed in:** 8188202 (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (2 bugs)
**Impact on plan:** Both fixes were necessary for correctness. The Zone-based approach is architecturally cleaner than the plan's instance field approach for async. No scope creep.

## Issues Encountered
- Pre-existing `dart analyze --fatal-infos` has 55 info/warning-level violations across the codebase (same class as Plan 01 noted). A few new `library_private_types_in_public_api` info items from the `Set<_ServiceIdentifier>?` parameter on public API -- intentional by design, external callers cannot construct `_ServiceIdentifier`. Zero issues introduced beyond info-level.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Both Phase 1 bugs are now fixed: async singleton race condition (Plan 01) and circular dependency detection (Plan 02)
- Phase 2 (dead code cleanup) can proceed -- `_lock` field and other dead code remain as noted
- Phase 4 (widget layer) is safe for concurrent widget tree access with both race protection and cycle detection in place

## Self-Check: PASSED

- [x] lib/src/sub_etha_scope.dart exists
- [x] test/src/sub_etha_scope_test.dart exists
- [x] 01-02-SUMMARY.md exists
- [x] Commit 2fcf811 exists
- [x] Commit 8188202 exists

---
*Phase: 01-core-bug-fixes*
*Completed: 2026-03-08*
