---
phase: 1
slug: core-bug-fixes
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-07
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `package:test` ^1.19.2 |
| **Config file** | None (uses defaults, analysis_options.yaml for lints) |
| **Quick run command** | `dart test test/src/sub_etha_scope_test.dart` |
| **Full suite command** | `dart test` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `dart test test/src/sub_etha_scope_test.dart`
- **After every plan wave:** Run `dart test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 1 | CORE-01 | unit | `dart test test/src/sub_etha_scope_test.dart` | ❌ W0 | ⬜ pending |
| 01-01-02 | 01 | 1 | CORE-01 | unit | `dart test test/src/sub_etha_scope_test.dart` | ❌ W0 | ⬜ pending |
| 01-02-01 | 02 | 1 | CORE-02 | unit | `dart test test/src/sub_etha_scope_test.dart` | ❌ W0 | ⬜ pending |
| 01-02-02 | 02 | 1 | CORE-02 | unit | `dart test test/src/sub_etha_scope_test.dart` | ❌ W0 | ⬜ pending |
| 01-02-03 | 02 | 1 | CORE-02 | unit | `dart test test/src/sub_etha_scope_test.dart` | ❌ W0 | ⬜ pending |
| 01-02-04 | 02 | 1 | CORE-02 | unit | `dart test test/src/sub_etha_scope_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/src/sub_etha_scope_test.dart` — new file for direct SubEthaScope unit tests
- [ ] Helper classes for tests (simple `A`, `B`, `C` classes that accept dependencies)

*Existing infrastructure covers framework and linting requirements.*

---

## Manual-Only Verifications

*All phase behaviors have automated verification.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
