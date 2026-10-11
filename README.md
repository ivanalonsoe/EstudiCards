# EstudiCards

Flashcard app for **Windows, macOS, Android and iOS**, built with **Flutter**. Organise what you study into projects and decks, practise with random, optionally timed sessions, and review your mistakes.

> **Status:** phase 0 (foundation) complete. Next: phase 1, projects and decks, in [`docs/TASKS.md`](docs/TASKS.md).
>
> **Languages:** the app UI is in Spanish. Documentation, code and tests are in English.

---

## Features (v1)

- **Projects → decks → cards.** For example, the project "Inglés B2" with the decks "Verbos irregulares" and "Phrasal verbs".
- **Two card types:**
  - **Simple:** a question, word or sentence, and its answer or translation. Tap to flip.
  - **Test:** 2 to 6 options, with one or several correct. The app grades it automatically.
- **Language projects:** text-to-speech (system TTS, free and offline), example sentence, notes and **reverse mode**.
- Configurable **study sessions**:
  - number of cards, decks, normal mode or **errors only**;
  - **per-question timer** or **global timer**;
  - cards and options always shuffled;
  - pause (hides the question), "show answer" and "leave for later".
- **Correct and wrong tracking** per card. A card enters the error list when answered wrong and leaves it after two correct answers in a row.
- Per-project and global **statistics**, **daily streak** and an optional daily goal.
- **Import and export:**
  - full backup as JSON;
  - share a project or deck as JSON or CSV (via WhatsApp, email…);
  - import cards from CSV, with a downloadable template and an **AI prompt to generate them**.
- 15-day **trash** for projects and decks.
- **Light and dark theme.** 100% offline, no accounts or login.

## Documentation

| Document | Contents |
|---|---|
| [`docs/SPEC.md`](docs/SPEC.md) | Functional and technical specification: data model, screens, user stories, business rules, import and export formats, quality strategy and phased plan. |
| [`docs/DESIGN_BRIEF.md`](docs/DESIGN_BRIEF.md) | Visual brief: colours, typography, screens, card variants and animations. |
| [`docs/design/`](docs/design/) | Screenshots of every screen in the design (mobile and desktop, light and dark) and the icon. |
| [`docs/TASKS.md`](docs/TASKS.md) | Phased task plan, with the tests to write first in each task. |
| [`AGENTS.md`](AGENTS.md) | Instructions for coding agents (Claude Code, Codex, Cursor…). |
| [`CLAUDE.md`](CLAUDE.md) | Entry point for Claude Code; imports `AGENTS.md`. |

## Technology

| Piece | Package |
|---|---|
| Framework | Flutter (stable) + Dart 3 |
| Local database | `drift` (SQLite) |
| State | `flutter_riverpod` |
| Navigation | `go_router` |
| Voice | `flutter_tts` |
| Files and sharing | `file_picker`, `share_plus`, `path_provider`, `image_picker`, `image` |
| CSV and charts | `csv`, `fl_chart` |
| UI strings (Spanish) | `flutter_localizations`, `intl` |
| Tests | `flutter_test`, `mocktail`, `fake_async`, `integration_test`, `patrol` (E2E) |
| Git hooks | Lefthook |
| CI/CD | GitHub Actions |

## Development requirements

- **Flutter SDK** (stable channel). Installation guide: <https://docs.flutter.dev/get-started/install>
- An editor: **VS Code** with the *Flutter* extension, or **Android Studio**.
- **Lefthook** for the git hooks (see [Git hooks](#git-hooks)).
- Depending on the platform you want to build:

| Platform | You need |
|---|---|
| Android | Android Studio (Android SDK and an emulator or a phone with USB debugging) |
| Windows | A Windows PC with **Visual Studio 2022** and the *Desktop development with C++* workload, and the **NuGet CLI** on the `PATH` (`winget install Microsoft.NuGet`): the voice package (`flutter_tts`) uses it to download a Microsoft build package |
| macOS / iOS | A **Mac** with **Xcode** (and CocoaPods). iOS and macOS can only be built on a Mac. |

Check that everything is installed correctly with:

```bash
flutter doctor
```

## Getting started

```bash
# 1. Clone the repository
git clone https://github.com/ivanalonsoe/EstudiCards.git
cd EstudiCards

# 2. Install dependencies
flutter pub get

# 3. Generate code (Drift tables, providers) and UI strings
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n

# 4. Enable the git hooks (once per machine; requires Lefthook to be installed)
lefthook install

# 5. Run
flutter run -d windows     # or: macos, android, ios
```

> Whenever you change the database tables or the providers, run step 3 again.
> During development you can keep it running automatically with `dart run build_runner watch`.
>
> Generated files (`*.g.dart` and `lib/app/l10n/generated/`) are **not committed** to git. After cloning or pulling, if `flutter analyze` complains about a missing generated file, run step 3.

### Adding a UI string

All UI text is in Spanish in [`lib/app/l10n/app_es.arb`](lib/app/l10n/app_es.arb), never written directly in a widget:

1. Add the key, its Spanish text and an `@key` entry with a `description` (and `placeholders` if it has variables) to `app_es.arb`.
2. Run `flutter gen-l10n` (or `flutter pub get`).
3. Use it in a widget: `AppLocalizations.of(context).myKey`.

## Git hooks

[Lefthook](https://lefthook.dev) runs quality checks automatically, configured in [`lefthook.yml`](lefthook.yml):

| When | What runs | Blocks if |
|---|---|---|
| Before each **commit** | `dart format` on the staged `.dart` files, and `flutter analyze` | a file is badly formatted or the analyzer reports any issue |
| Before each **push** | `flutter test` | any test fails |

**Install Lefthook once per machine:**

```bash
npm install -g lefthook    # any OS with Node.js (pnpm add -g lefthook also works)
brew install lefthook      # macOS with Homebrew
```

Then enable the hooks in your clone (once per clone):

```bash
lefthook install
```

**If a commit is blocked:**

- Format: run `dart format .`, stage the files again (`git add`) and commit.
- Analysis: fix the issues listed by `flutter analyze` (many can be fixed with `dart fix --apply`).

> On Windows, git runs the hooks with Git Bash, so `flutter`, `dart` and `lefthook` must be on the `PATH`. If you have just installed them, restart your editor or terminal.
>
> Do not skip the hooks with `--no-verify`. CI runs the same checks anyway.

## Useful commands

| Command | What it does |
|---|---|
| `dart run build_runner build --delete-conflicting-outputs` | Generates the database code (`*.g.dart`) from the table definitions. |
| `dart run drift_dev schema dump lib/core/db/app_database.dart drift_schemas/drift_schema_vN.json` | After a schema change (N = the new `schemaVersion`): saves the new schema, which the migration tests in `test/core/db/` use. Commit the file. |
| `flutter analyze` | Checks the code for errors and bad practices. It must report no warnings. |
| `flutter test` | Runs the unit and widget tests. |
| `flutter test --coverage` | Same, generating the coverage report in `coverage/lcov.info`. |
| `dart run tool/check_coverage.dart` | Checks the coverage report against the thresholds (≥ 70% overall, ≥ 90% in `domain/`), as CI does. |
| `flutter test integration_test -d windows` | Runs the integration tests on desktop. |
| `flutter test integration_test -d <device>` | Runs the integration tests on another device, e.g. an Android emulator (`flutter devices` lists the IDs). |
| `patrol test` | Runs the E2E tests (`patrol_test/`) on a running emulator or connected device. Install the CLI once per machine with `dart pub global activate patrol_cli`, and add `%LOCALAPPDATA%\Pub\Cache\bin` (Windows) or `~/.pub-cache/bin` to the `PATH`. |
| `flutter devices` | Lists the available devices and emulators. |
| `dart run flutter_launcher_icons` | Regenerates the app icons from `assets/branding/` (config in `flutter_launcher_icons.yaml`). Afterwards, revert its change to `ios/Runner.xcodeproj/project.pbxproj`. |
| `flutter build apk` | Builds the Android installer. |
| `flutter build windows` | Builds the Windows executable. |
| `flutter build macos` / `flutter build ios` | Builds the app for Mac or iPhone (on a Mac). |

## Project structure

```
EstudiCards/
├── lib/
│   ├── main.dart
│   ├── app/            # startup, theme, routes, UI strings (app_es.arb)
│   ├── core/           # database, IDs, clock, files, shared widgets
│   └── features/       # one folder per feature
│       ├── projects/       # dashboard, projects, archived, trash
│       ├── decks/          # decks and card list
│       ├── cards/          # card editor and preview
│       ├── study/          # setup, study session, results
│       ├── stats/          # statistics, errors, streak
│       ├── import_export/  # JSON, CSV, template, AI prompt
│       └── settings/       # settings
├── test/               # unit and widget tests (same structure as lib/)
├── integration_test/   # integration tests
├── patrol_test/        # E2E tests (Patrol)
├── assets/branding/    # app icons
├── docs/               # SPEC.md, DESIGN_BRIEF.md, TASKS.md, design/
├── AGENTS.md
├── CLAUDE.md
└── README.md
```

Each feature is split into `data/` (database), `domain/` (business rules, no Flutter) and `presentation/` (screens).

## How it is developed

- **TDD:** every feature starts with a failing test; then the code is written to make it pass and refactored (see [`docs/SPEC.md` §10](docs/SPEC.md#10-quality-tdd-tests-and-cicd)).
- **Four test levels:** unit, widget, integration and E2E.
- **Git hooks (Lefthook):** formatting and analysis are checked before each commit; tests before each push.
- **CI (GitHub Actions):** every PR runs all tests on Linux, Windows and an Android emulator. Creating a `v*` tag builds the Android, Windows and macOS installers.
- **Branches:** one per task in [`docs/TASKS.md`](docs/TASKS.md), with a PR to `main`.

## Creating cards with AI

1. In a deck, tap **Descargar plantilla** (download template) or **Copiar prompt para IA** (copy AI prompt).
2. Paste the prompt into Claude, ChatGPT or another AI, filling in the topic, number of cards, language and level.
3. Save the answer as a `.csv` file and tap **Importar tarjetas** (import cards).
4. Check the preview (new cards, duplicates and rows with errors) and confirm.

CSV format (`;` separator, UTF-8, English column names):

```csv
question;answer;option1;option2;option3;option4;option5;option6;correct;explanation;example;notes
to bring;traer (brought, brought);;;;;;;;;Can you bring me some water?;Verbo irregular
¿Capital de Australia?;;Sídney;Canberra;Melbourne;;;;2;Canberra es la capital desde 1913.;;
¿Qué números son primos?;;2;4;7;9;;;1|3;;;
```

Full details in [`docs/SPEC.md` §8](docs/SPEC.md#8-import-and-export).

## Roadmap

| Phase | Content | Status |
|---|---|---|
| 0. Foundation | Flutter project, hooks, CI, Patrol, theme, routes, database | ✅ Done |
| 1. Projects and decks | Dashboard, favourites, archive, trash | ⏳ Pending |
| 2. Cards | Simple and test editor, preview, images, voice | ⏳ Pending |
| 3. Study session | Random selection, timers, pause, results | ⏳ Pending |
| 4. Statistics and errors | Error list, statistics, streak | ⏳ Pending |
| 5. Import and export | JSON, CSV, template, AI prompt | ⏳ Pending |
| 6. Polish | Animations, accessibility, icons, packaging | ⏳ Pending |

Each phase is broken down task by task in [`docs/TASKS.md`](docs/TASKS.md).

**Future goals (after v1):** login and cloud sync, web version, AI voices, spaced repetition, "type the answer" mode, formulas and code on cards, keyboard shortcuts and more UI languages.

## Privacy

EstudiCards uses no accounts, analytics or internet connection. Your data only leaves the device when you export or share it.

## License

To be decided.
