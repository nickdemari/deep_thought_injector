# Phase 3: API Surface - Context

**Gathered:** 2026-03-09
**Status:** Ready for planning

<domain>
## Phase Boundary

Add standard DI naming conventions (`register`/`get`) as aliases alongside the Hitchhiker's Guide themed names (`ponder`/`question`), plus `verify()` for startup validation and `isRegistered<T>()` for registration queries. No new DI capabilities — only new ways to access existing functionality.

</domain>

<decisions>
## Implementation Decisions

### Alias Naming & Placement
- `register<T>()` / `registerAsync<T>()` alias `ponder<T>()` / `ponderAsync<T>()` — simple delegates, identical signatures
- `get<T>()` / `getAsync<T>()` alias `question<T>()` / `questionAsync<T>()` — `get` is clean in Dart with generics, no shadowing concerns
- Aliases live on `DeepThought` only — `SubEthaScope` keeps its own naming (`register`/`locate`) and is not aliased further
- Themed names remain the "primary" API per PROJECT.md; aliases are convenience, not replacements

### verify() Behavior
- Collects ALL sync registration errors, then throws a single `VogonPoetryException` listing every failure (type name + cause) — more useful than fail-fast
- Returns `void` on success, throws on any failure — no result object, keep it simple
- Only checks sync registrations — async factories can't be verified synchronously without blocking; `verifyAsync()` is out of scope for v1
- Resolves each factory once to confirm it doesn't throw — same as calling `question<T>()` for each registration
- Transient factories are included (they can fail too)
- Lives on `DeepThought` (wraps scope iteration + logging + error notification)

### isRegistered() Scope Chain
- Walks the parent chain, consistent with `locate()` / `question()` — if you can resolve it, it's "registered" from your perspective
- Accepts optional `name` parameter for named registrations
- Returns `bool`, never throws
- Lives on `DeepThought` — delegates to scope chain lookup without instantiation
- Does NOT distinguish sync vs async registrations — just answers "is something registered for this type?"

### Export Surface
- `SubEthaScope` stays public — useful for advanced usage and testing (`override()` lives there)
- `Lifecycle` and `Disposable` stay exported — they're part of the registration contract
- Primary API surface is `DeepThought`; `SubEthaScope` is the "power user" escape hatch
- No changes to barrel file exports beyond what new methods require

### Claude's Discretion
- Whether `verify()` skips already-resolved singletons (optimization) or re-checks everything (thoroughness)
- Error message formatting in the aggregate `VogonPoetryException` from `verify()`
- Whether `isRegistered()` is also added to `SubEthaScope` for symmetry (likely yes — it's a query, not a mutation)
- Test structure: whether alias tests are exhaustive (every parameter combo) or representative (proves delegation works)

</decisions>

<specifics>
## Specific Ideas

User preference: "cleanest, easy to humanly read approach" — prioritize readability and simplicity over cleverness. Simple delegates, clear error messages, no unnecessary abstraction.

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `DeepThought` at `lib/src/deep_thought_injector.dart` — all aliases and new methods go here
- `SubEthaScope._factories` map — `verify()` needs to iterate this; may need a public accessor or method on SubEthaScope
- `SubEthaScope.locate<T>()` / `locateAsync<T>()` — `verify()` can leverage these for resolution checks
- `VogonPoetryException` — used for all error reporting, including aggregate verify failures

### Established Patterns
- `DeepThought` wraps `SubEthaScope` and adds logging + error notification on top
- All DI errors throw `VogonPoetryException` with descriptive cause string
- `_ServiceIdentifier` is the composite key (Type + optional name) — `isRegistered` needs to query this
- `_ServiceFactory` distinguishes sync/async via null checks on factory fields

### Integration Points
- `DeepThought.ponder()` / `question()` — aliases delegate to these (or directly to scope methods)
- `SubEthaScope._factories` — private map; `verify()` and `isRegistered()` may need new SubEthaScope methods to avoid exposing internals
- Barrel file `lib/deep_thought_injector.dart` — no new exports needed (methods go on existing classes)
- Test file `test/src/deep_thought_injector_test.dart` — new test groups for aliases, verify, isRegistered

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 03-api-surface*
*Context gathered: 2026-03-09*
