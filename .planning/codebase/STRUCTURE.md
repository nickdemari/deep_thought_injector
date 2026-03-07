# Codebase Structure

**Analysis Date:** 2026-03-07

## Directory Layout

```
deep_thought_injector/
├── .github/                    # CI workflows, issue templates, spell check config
│   ├── ISSUE_TEMPLATE/         # GitHub issue templates (bug, feature, chore, etc.)
│   ├── workflows/
│   │   └── main.yaml           # CI pipeline (VeryGoodOpenSource reusable workflows)
│   ├── PULL_REQUEST_TEMPLATE.md
│   ├── cspell.json             # Spell check dictionary
│   └── dependabot.yaml         # Dependency update automation
├── .planning/                  # GSD planning documents
│   └── codebase/               # Architecture analysis documents
├── example/
│   └── example.md              # Usage documentation with code samples
├── lib/                        # Library source code
│   ├── deep_thought_injector.dart  # Barrel export (public API surface)
│   └── src/                    # Internal implementation
│       ├── auto_wiring.dart        # Auto-wiring stub
│       ├── deep_thought_config.dart # Configuration class
│       ├── deep_thought_injector.dart # DeepThought facade class
│       ├── sub_etha_scope.dart     # Core registry/scope implementation
│       └── vogon_poetry_exception.dart # Custom exception type
├── test/                       # Test files
│   └── src/
│       ├── async_factory_test.dart       # Async registration/resolution tests
│       └── deep_thought_injector_test.dart # Core DI container tests
├── analysis_options.yaml       # Dart linting config (very_good_analysis)
├── coverage_badge.svg          # Test coverage badge image
├── pubspec.yaml                # Dart package manifest
├── README.md                   # Package documentation
├── AGENTS.md                   # AI agent instructions
└── CLAUDE.md                   # Claude-specific project instructions
```

## Directory Purposes

**`lib/`:**
- Purpose: All library source code
- Contains: Barrel export file and `src/` subdirectory
- Key files: `lib/deep_thought_injector.dart` (barrel export)

**`lib/src/`:**
- Purpose: Internal implementation details
- Contains: All classes that make up the DI container
- Key files: `lib/src/deep_thought_injector.dart` (main facade), `lib/src/sub_etha_scope.dart` (core engine)

**`test/`:**
- Purpose: All test files
- Contains: `src/` subdirectory mirroring the lib structure

**`test/src/`:**
- Purpose: Unit tests for lib/src classes
- Contains: Test files corresponding to library source files
- Key files: `test/src/deep_thought_injector_test.dart`, `test/src/async_factory_test.dart`

**`example/`:**
- Purpose: Usage examples and documentation for package consumers
- Contains: Markdown file with code samples
- Key files: `example/example.md`

**`.github/`:**
- Purpose: GitHub-specific configuration (CI, templates, spell check)
- Contains: Workflows, issue templates, PR template, dependabot config
- Key files: `.github/workflows/main.yaml`

## Key File Locations

**Entry Points:**
- `lib/deep_thought_injector.dart`: Barrel export defining the public API. This is what consumers import.
- `lib/src/deep_thought_injector.dart`: The `DeepThought` class -- primary facade for all DI operations.

**Configuration:**
- `pubspec.yaml`: Package manifest (name, version, dependencies, SDK constraints)
- `analysis_options.yaml`: Dart static analysis configuration (uses `very_good_analysis` ruleset)
- `.github/workflows/main.yaml`: CI pipeline definition
- `.github/cspell.json`: Spell check dictionary for CI

**Core Logic:**
- `lib/src/sub_etha_scope.dart`: Registry engine -- `SubEthaScope`, `_ServiceFactory`, `_ServiceIdentifier`, `Lifecycle` enum, `Disposable` interface
- `lib/src/deep_thought_injector.dart`: Public facade class `DeepThought`
- `lib/src/vogon_poetry_exception.dart`: Custom exception type `VogonPoetryException`
- `lib/src/deep_thought_config.dart`: Configuration class `DeepThoughtConfig`
- `lib/src/auto_wiring.dart`: Auto-wiring stub `AutoWiring`

**Testing:**
- `test/src/deep_thought_injector_test.dart`: Core unit tests (registration, resolution, lazy/eager, transient, duplicate, not-found)
- `test/src/async_factory_test.dart`: Async factory registration and resolution test

## Naming Conventions

**Files:**
- `snake_case.dart` for all Dart source files
- Test files mirror source file names with `_test.dart` suffix: `deep_thought_injector.dart` -> `deep_thought_injector_test.dart`
- Exception: `async_factory_test.dart` tests functionality from `sub_etha_scope.dart` (async path) rather than having a direct name match

**Directories:**
- `lib/src/` for private implementation (standard Dart package convention)
- `test/src/` mirrors `lib/src/` structure
- Lowercase, no nesting beyond `src/`

**Classes:**
- `PascalCase`: `DeepThought`, `SubEthaScope`, `VogonPoetryException`, `DeepThoughtConfig`, `AutoWiring`
- Private classes prefixed with underscore: `_ServiceFactory`, `_ServiceIdentifier`

**Methods:**
- `camelCase` with thematic naming: `ponder()` (register), `question()` (resolve), `ponderAsync()`, `questionAsync()`
- Standard Dart naming for non-themed methods: `register()`, `locate()`, `reset()`, `override()`, `createChildScope()`

**Enums:**
- `PascalCase` for enum name, `camelCase` for values: `Lifecycle.singleton`, `Lifecycle.transient`, `Lifecycle.scoped`

## Where to Add New Code

**New Feature (e.g., new DI capability like decorators, interceptors):**
- Primary code: `lib/src/` -- create a new `.dart` file in `snake_case`
- If it should be public: add an `export` line to `lib/deep_thought_injector.dart`
- If it's internal only: import directly from `lib/src/` within implementation files
- Tests: `test/src/` -- create a corresponding `_test.dart` file

**New Registration/Resolution Strategy:**
- Modify `lib/src/sub_etha_scope.dart` for core behavior changes
- Add new `Lifecycle` enum value if needed
- Update `lib/src/deep_thought_injector.dart` to expose via `DeepThought` facade
- Tests: add test cases to `test/src/deep_thought_injector_test.dart` or create a new test file in `test/src/`

**New Exception / Error Code:**
- Add to `lib/src/vogon_poetry_exception.dart` or create a new exception class in `lib/src/`
- Export from `lib/deep_thought_injector.dart` if public

**New Configuration Option:**
- Add fields to `lib/src/deep_thought_config.dart`
- Update `DeepThoughtConfig.fromEnvironment()` factory

**Utilities / Helpers:**
- Place in `lib/src/` as a new file
- Keep private (no barrel export) unless explicitly needed by consumers

## Special Directories

**`.github/`:**
- Purpose: GitHub platform configuration (CI, templates, automation)
- Generated: Partially (scaffolded by Very Good CLI)
- Committed: Yes

**`.planning/`:**
- Purpose: GSD planning and analysis documents
- Generated: Yes (by GSD tooling)
- Committed: Yes

**`example/`:**
- Purpose: Package usage examples (required by pub.dev conventions for published packages)
- Generated: No
- Committed: Yes

**`.dart_tool/` (gitignored):**
- Purpose: Dart SDK tooling cache
- Generated: Yes (by `dart pub get`)
- Committed: No

**`build/` (gitignored):**
- Purpose: Build artifacts
- Generated: Yes
- Committed: No

---

*Structure analysis: 2026-03-07*
