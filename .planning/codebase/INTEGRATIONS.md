# External Integrations

**Analysis Date:** 2026-03-07

## APIs & External Services

**None.** This is a self-contained dependency injection library. It does not call any external APIs, HTTP endpoints, or third-party services.

## Data Storage

**Databases:**
- None. All state is held in-memory via Dart `Map` instances within `SubEthaScope` (`lib/src/sub_etha_scope.dart`).

**File Storage:**
- None. No filesystem I/O.

**Caching:**
- None (beyond the singleton instance caching built into the DI container itself).

## Authentication & Identity

**Auth Provider:**
- Not applicable. This is a library, not an application.

## Monitoring & Observability

**Error Tracking:**
- `DeepThought.errorNotifier` (`lib/src/deep_thought_injector.dart`, line 16) is an optional callback `void Function(Exception e, StackTrace s)?` that consumers can wire to external error tracking (e.g., Sentry, Crashlytics). The library itself does not ship with any error tracking integration.

**Logs:**
- Uses `package:logging` (`Logger` class) in `lib/src/deep_thought_injector.dart` and `lib/src/auto_wiring.dart`.
- Default logger name: `'DeepThought'` (can be overridden via `DeepThought.logger` static setter).
- Logs at `severe` level when service resolution fails.
- Consumers are responsible for attaching log handlers (e.g., print to console, send to log aggregator).

## CI/CD & Deployment

**Hosting:**
- Not applicable (library package, `publish_to: none`).

**CI Pipeline:**
- GitHub Actions (`.github/workflows/main.yaml`)
- Uses [Very Good Workflows](https://github.com/VeryGoodOpenSource/very_good_workflows) reusable workflows (v1):
  - `semantic_pull_request.yml` -- Enforces conventional commit-style PR titles
  - `spell_check.yml` -- Spell checks all `**/*.md` files using cspell (config at `.github/cspell.json`)
  - `dart_package.yml` -- Standard Dart package CI: format, analyze, test with coverage
- Triggers: push to `main`, pull requests targeting `main`
- Concurrency: grouped by workflow + ref, cancels in-progress runs

**Dependabot:**
- `.github/dependabot.yaml` configured for daily updates of both `github-actions` and `pub` ecosystems.

## Environment Configuration

**Required env vars:**
- None. This is a library with no runtime environment variable dependencies.

**Secrets location:**
- No secrets files exist. The `DeepThoughtConfig.secrets` field (`lib/src/deep_thought_config.dart`) is a programmatic `Map<String, String>?` that consumers populate at their discretion -- it does not read from the filesystem or environment automatically.

## Webhooks & Callbacks

**Incoming:**
- None.

**Outgoing:**
- None.

## Third-Party Package Integrations

The only external (non-self) package imported at runtime is:

| Package | Used In | Purpose |
|---------|---------|---------|
| `logging` | `lib/src/deep_thought_injector.dart`, `lib/src/auto_wiring.dart` | Structured logging via `Logger` class |

All other imports are self-referential (`package:deep_thought_injector/...`) or from `dart:async` (SDK core).

**Note:** `logging` is NOT declared in `pubspec.yaml` -- it resolves only as a transitive dependency. This must be fixed by adding it to `dependencies` in `pubspec.yaml`.

---

*Integration audit: 2026-03-07*
