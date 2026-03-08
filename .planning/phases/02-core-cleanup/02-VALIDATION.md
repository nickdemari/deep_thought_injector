---
phase: 2
slug: core-cleanup
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-07
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | package:test 1.19.2+ |
| **Config file** | none — standard Dart test runner |
| **Quick run command** | `dart test test/src/deep_thought_injector_test.dart` |
| **Full suite command** | `dart test` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `dart test test/src/deep_thought_injector_test.dart && dart analyze --fatal-infos`
- **After every plan wave:** Run `dart test && dart analyze --fatal-infos`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 10 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 02-01-01 | 01 | 1 | CORE-03 | smoke | `dart pub get && dart analyze --fatal-infos` | N/A — analyzer | ⬜ pending |
| 02-01-02 | 01 | 1 | CORE-04 | smoke | `dart analyze --fatal-infos` | N/A — file deletion | ⬜ pending |
| 02-01-03 | 01 | 1 | CORE-05 | smoke | `dart analyze --fatal-infos` | N/A — file deletion | ⬜ pending |
| 02-02-01 | 02 | 1 | CORE-06 | unit | `dart test test/src/deep_thought_injector_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/src/deep_thought_injector_test.dart` — add `group('reset', ...)` stubs for CORE-06 (TDD — tests written first)
- No new test files needed
- No framework install needed (already configured)

*Existing infrastructure covers CORE-03, CORE-04, CORE-05 via `dart analyze`.*

---

## Manual-Only Verifications

*All phase behaviors have automated verification.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
