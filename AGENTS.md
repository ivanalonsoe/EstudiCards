# AGENTS.md — EstudiCards

Instructions for coding agents (Claude Code, Codex, Cursor…) working in this repository.

## Project

EstudiCards is a flashcard app built with **Flutter** for **Windows, macOS, Android and iOS**. It is 100% offline, with no login, and uses a local SQLite database.

Reference documentation (source of truth):

- `docs/SPEC.md` — functional and technical specification: data model, screens, user stories, business rules, import/export formats, quality strategy and phased plan.
- `docs/DESIGN_BRIEF.md` — visual system, screens and components.
- `docs/design/` — PNG screenshots of every screen (mobile and desktop, light and dark). This is the visual reference: the UI must match them.
- `docs/TASKS.md` — task plan. Always work on a task from this file.

If the code contradicts the spec, **ask before changing the spec or the behaviour**. If the spec does not cover a case, propose a solution, implement it in the simplest way and record it in the spec's "Decision log".

## Languages

| What | Language |
|---|---|
| **Talking to the owner** (explanations, questions, summaries, PR descriptions addressed to them) | **Spanish** |
| Code, identifiers, comments, tests (including test descriptions), commit messages, branch names and documentation | **English** |
| UI strings shown to the user | **Spanish**, always in `lib/app/l10n/app_es.arb` (see `docs/SPEC.md` §2.1) |
| CSV column names and the AI prompt | **English** (part of the file format, SPEC §8.3 and §8.5) |

## About the owner

The project owner is **learning Flutter**. Therefore:

- Talk to them in **Spanish**.
- When you finish each task, briefly explain what you did and why, without unnecessary jargon.
- Prefer simple, readable code over clever abstractions.
- When you introduce a new concept (a provider, a migration, a DAO…), add a short comment explaining it the first time it appears.
- Do not add new dependencies without justifying it and telling the owner.

## Stack

| Piece | Package |
|---|---|
| Database | `drift` + `drift_flutter` (SQLite) |
| State | `flutter_riverpod` |
| Navigation | `go_router` |
| IDs | `uuid` (v4) |
| Voice | `flutter_tts` |
| Files | `file_picker`, `share_plus`, `path_provider`, `image_picker`, `image` |
| CSV | `csv` |
| Charts | `fl_chart` |
| UI strings | `flutter_localizations`, `intl` (ARB) |
| Tests | `flutter_test`, `mocktail`, `fake_async`, `integration_test`, `patrol` |
| Git hooks | Lefthook (`lefthook.yml`) |
| CI/CD | GitHub Actions (`.github/workflows/ci.yml`, `release.yml`) |

## Commands

```bash
flutter pub get                                              # install dependencies
dart run build_runner build --delete-conflicting-outputs     # generate code (Drift, Riverpod)
flutter gen-l10n                                             # generate UI strings from ARB
flutter analyze                                              # static analysis (must have no warnings)
flutter test                                                 # unit and widget tests
flutter test --coverage                                      # with coverage report (coverage/lcov.info)
flutter test integration_test -d windows                     # integration tests on desktop
patrol test                                                  # E2E tests (emulator or connected device)
flutter run -d windows | macos | android | ios              # run
lefthook install                                             # enable git hooks (once per machine)
```

## Structure

```
lib/
├── app/          # MaterialApp, router, theme (brief tokens), l10n
├── core/         # db (Drift + migrations), ids, clock, files, shared widgets
└── features/     # projects, decks, cards, study, stats, import_export, settings
    └── <feature>/
        ├── data/          # tables, DAOs, repositories
        ├── domain/        # models and pure business rules (no Flutter)
        └── presentation/  # screens, widgets, providers
test/             # unit and widget tests (mirrors lib/), fixtures in test/fixtures/
integration_test/ # integration tests per epic
docs/             # SPEC.md, DESIGN_BRIEF.md, TASKS.md, design/ (screenshots)
assets/branding/  # app icons
.github/workflows/ # CI (ci.yml) and CD (release.yml)
lefthook.yml      # git hooks
```

## Code rules

- **Code in English** (classes, variables, tables, comments). **UI strings in Spanish**, always in `lib/app/l10n/app_es.arb`, never hard-coded in widgets.
- **IDs:** UUID v4 generated in `core/ids.dart`. Never auto-increment IDs.
- **Dates:** store in UTC; display in local time.
- **Time:** use the injectable clock in `core/clock.dart`, never `DateTime.now()` directly. This makes timers, streaks and the trash testable.
- **Business rules in `domain/`**, pure and unit-tested: card selection and shuffling, session engine, timers, error list, streak, trash, JSON/CSV parsers and validation.
- **Transactions** for any write that touches several tables (answering, importing, deleting, moving).
- **Database schema:** any change bumps `schemaVersion` and adds its migration. Never edit a released migration.
- **Deletion:** projects and decks are marked with `deleted_at` (15-day trash). Cards are permanently deleted after the undo window. See SPEC §7.1.
- **Statistics:** only first attempts count (`is_first_attempt = true`). `card_stats` is derived and must be recomputable from `attempts`.
- **Theme:** use theme tokens (`Theme.of(context)` / extensions), never literal colours in widgets. Correct and wrong always with an icon as well as colour.
- **Responsive layout:** < 600 mobile, 600–839 tablet, ≥ 840 desktop with sidebar. Test both.
- **No keyboard shortcuts** in v1: every action is a button.
- **No network:** the app makes no HTTP requests.

## Mandatory TDD

Every behaviour change follows the **red → green → refactor** cycle (SPEC §10.1):

1. **Red:** first write the tests listed in the task in `docs/TASKS.md`. Run them and **show the owner the output where they fail**, explaining (in Spanish) why they fail.
2. **Green:** write the minimum code for them to pass. Run the tests and show that they pass.
3. **Refactor:** clean up the code while keeping the tests green.

- Do not write business logic without a test that failed first. If the owner asks for a shortcut, remind them of this rule and ask.
- A bug is fixed by first writing a test that reproduces it.
- Test descriptions and code in English.
- Use the injectable clock, a seeded `Random` and in-memory Drift so tests are deterministic (SPEC §10.3).
- Give stable English `Key`s to the elements tests interact with (`Key('study.flip')`).
- Minimum coverage: 90% in `domain/`, 70% overall.

## Way of working

1. Follow the **phased plan** in `docs/SPEC.md` §11 and the tasks in `docs/TASKS.md`, in order. Do not start a phase until the previous one meets its "Done when".
2. Before implementing a user story, read it together with its acceptance criteria and the related business rules.
3. Small, verifiable changes. After each change: `flutter analyze` with no warnings and `flutter test` green. Work on one branch per task (`feature/T2.3-card-editor`) and open a PR to `main`; CI must pass.
4. Add or update tests for every business rule you touch.
5. Commit messages in English, imperative and descriptive (e.g. `Add trash with 15-day purge`). Do not use `--no-verify` to skip the hooks.
6. Do not mark a task as done if tests are failing or functionality is incomplete; explain what is missing. When finished, tick the box in `docs/TASKS.md` and check the definition of done (SPEC §10.6).
