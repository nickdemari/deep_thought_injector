---
phase: 01-core-bug-fixes
verified: 2026-03-07T23:45:00Z
status: passed
score: 11/11 must-haves verified
---

# Phase 1: Core Bug Fixes Verification Report

**Phase Goal:** The core DI container handles concurrent async resolution and circular dependencies correctly, with tests proving both
**Verified:** 2026-03-07T23:45:00Z
**Status:** PASSED
**Re-verification:** No -- initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Two concurrent locateAsync calls for the same lazy singleton return the identical instance | VERIFIED | Test "two concurrent locateAsync calls return identical instance" passes with `same()` matcher; `Future.wait` used on lines 39-42 of test file |
| 2 | The async factory is invoked exactly once despite concurrent callers | VERIFIED | Test asserts `counter == 1` after two concurrent calls (line 45); three-caller test asserts same (line 72) |
| 3 | If the async factory throws, all waiters receive the error and subsequent calls can retry | VERIFIED | Test "async factory that throws" verifies both futures throw `VogonPoetryException`, then retry succeeds with `recovered-2` (lines 98-116) |
| 4 | Already-resolved singletons still return the cached instance immediately | VERIFIED | Test "already-resolved async singleton returns cached instance" passes with `same()` matcher and counter == 1 (lines 118-142) |
| 5 | Transient async services still create new instances per call | VERIFIED | Test "transient async services create a new instance per call" verifies `isNot(same(...))` and counter == 2 (lines 144-168) |
| 6 | Direct circular dependency (A -> B -> A) throws a descriptive VogonPoetryException | VERIFIED | Test passes; error message verified to contain "Circular dependency detected", "ServiceA", "ServiceB" (lines 172-198) |
| 7 | Transitive circular dependency (A -> B -> C -> A) throws with the full chain | VERIFIED | Test passes; error message verified to contain all three type names (lines 200-230) |
| 8 | Circular dependency across parent-child scopes is detected | VERIFIED | Test "cross-scope circular dependency" passes using `createChildScope()` parent-child relationship (lines 254-280) |
| 9 | Non-circular linear dependency chains resolve correctly without false positives | VERIFIED | Test "non-circular linear chain (A -> B -> C)" resolves successfully and verifies nested dependency structure (lines 232-252) |
| 10 | Named services are handled correctly in cycle detection | VERIFIED | Test verifies same-type different-name circular deps are detected AND non-circular named services resolve fine (lines 282-314) |
| 11 | Async resolution paths also detect circular dependencies | VERIFIED | Test "async circular dependency (A -> B -> A)" passes using `registerAsync`/`locateAsync` (lines 316-342) |

**Score:** 11/11 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/src/sub_etha_scope.dart` | Completer-guarded async singleton resolution + Set-based circular dependency detection | VERIFIED | `_asyncCompleter` field on `_ServiceFactory` (line 289); Completer created and assigned before await (lines 206-207); cycle check with `_ServiceIdentifier` Set in both `locate` (lines 103-113) and `locateAsync` (lines 153-163); Zone-based stack threading for async (lines 200-214) |
| `test/src/sub_etha_scope_test.dart` | Unit tests for both fixes | VERIFIED | 5 tests in "async singleton race condition" group + 6 tests in "circular dependency detection" group = 11 new tests, all passing |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `sub_etha_scope.dart` | `_ServiceFactory._asyncCompleter` | Completer field set synchronously before first await | WIRED | `serviceFactory._asyncCompleter = completer` on line 207, immediately after `final completer = Completer<T>()` on line 206, before `await runZoned(...)` on line 211 |
| `sub_etha_scope_test.dart` | `sub_etha_scope.dart` | `Future.wait` with multiple `locateAsync` calls | WIRED | `Future.wait([scope.locateAsync<String>(), scope.locateAsync<String>()])` on lines 39-42 and 64-68 |
| `sub_etha_scope.dart (locate)` | `parent.locate` | `resolutionStack` forwarded through parent scope chain | WIRED | `parent!.locate<T>(name: name, resolutionStack: stack)` on line 118 |
| `sub_etha_scope.dart (locateAsync)` | `parent.locateAsync` | `resolutionStack` forwarded through parent scope chain | WIRED | `parent!.locateAsync<T>(name: name, resolutionStack: stack)` on lines 171-174 |
| `sub_etha_scope.dart (locate)` | `vogon_poetry_exception.dart` | throw VogonPoetryException with chain description | WIRED | `throw VogonPoetryException('Circular dependency detected: $chain')` on lines 112 and 163 |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| CORE-01 | 01-01 | Async singleton race condition fixed via Completer pattern | SATISFIED | `_asyncCompleter` field on `_ServiceFactory`; Completer-guarded resolution in `locateAsync`; concurrent callers await same future |
| CORE-02 | 01-02 | Circular dependency detection during resolution | SATISFIED | `Set<_ServiceIdentifier>` resolution stack in `locate`; Zone-based stack in `locateAsync`; descriptive error with full chain |
| TEST-01 | 01-01 | Unit tests for async singleton race condition fix | SATISFIED | 5 tests in "async singleton race condition" group, all passing |
| TEST-02 | 01-02 | Unit tests for circular dependency detection | SATISFIED | 6 tests in "circular dependency detection" group, all passing |

No orphaned requirements -- REQUIREMENTS.md maps exactly CORE-01, CORE-02, TEST-01, TEST-02 to Phase 1, and all four are covered by plans.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `lib/src/sub_etha_scope.dart` | 35-36 | Pre-existing unused `_lock` field with "placeholder" comment | Info | Not a blocker -- explicitly deferred to Phase 2 cleanup (CORE-04 scope). Plans 01-01 and 01-02 were instructed NOT to remove it. |

### Human Verification Required

No human verification required. All success criteria are testable via automated tests, and the full test suite passes (18/18). The `dart analyze` output shows 53 info-level issues, all pre-existing (missing docs, trailing commas, line length, private types in public API) -- none introduced by this phase, none blocking.

### Gaps Summary

No gaps found. All 11 observable truths verified. All 4 requirements satisfied. All key links wired. All commits exist. Full test suite green (18/18 tests). The phase goal -- "The core DI container handles concurrent async resolution and circular dependencies correctly, with tests proving both" -- is achieved.

---

_Verified: 2026-03-07T23:45:00Z_
_Verifier: Claude (gsd-verifier)_
