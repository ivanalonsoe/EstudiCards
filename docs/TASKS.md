# EstudiCards — Task plan (v1)

Breakdown of the phases in [`SPEC.md` §11](SPEC.md#11-phased-implementation-plan) into small tasks, in execution order. Related tasks can be grouped into one branch and one PR.

## How to use this document

- **Order:** top to bottom. A task only starts when the tasks listed under *Depends on* are finished.
- **TDD:** in every task, first write the tests under **Tests first**, run them and see them fail. Then implement until they pass (SPEC §10.1). In a PR with several tasks, finish red → green → refactor for one task before starting the next.
- **PRs:** a PR may group several related tasks. Each task is one commit inside the PR. The agent stops for review when the PR is finished, not after each task.
- **Finishing:** tick the box `[x]` when the definition of done (SPEC §10.6) is met and the PR is merged.
- **Branch:** one per PR, `feature/<IDs>-<short-name>`, e.g. `feature/T2.3-card-editor` for one task or `feature/T1.1-T1.4-repositories` for several.
- **References:** US = user story (SPEC §6); R = business rule (SPEC §7); P = screen (SPEC §5.2).
- **Language:** code, tests and commit messages in English; UI strings in Spanish in `app_es.arb` (SPEC §2.1).

Test legend: 🧪 unit · 🧩 widget · 🔗 integration · 🤖 E2E (Patrol).

## Summary

| Phase | Tasks | Status |
|---|---|---|
| 0. Foundation | T0.1 – T0.10 | ✅ 10 / 10 |
| 1. Projects and decks | T1.1 – T1.9 | ⏳ 4 / 9 |
| 2. Cards | T2.1 – T2.9 | ⏳ 0 / 9 |
| 3. Study session | T3.1 – T3.10 | ⏳ 0 / 10 |
| 4. Statistics and errors | T4.1 – T4.7 | ⏳ 0 / 7 |
| 5. Import and export | T5.1 – T5.9 | ⏳ 0 / 9 |
| 6. Polish and release | T6.1 – T6.8 | ⏳ 0 / 8 |

---

## Phase 0 — Foundation

Goal: a project that starts, with automated quality from day one.

- [x] **T0.1 Create the Flutter project**
  - Create the `estudicards` project for Android, iOS, Windows and macOS inside the repository, without deleting `docs/`, `assets/` or the `.md` files.
  - Folder structure from SPEC §3.2 (`app/`, `core/`, `features/<feature>/{data,domain,presentation}`), even if empty (with `.gitkeep`).
  - Strict analysis rules in `analysis_options.yaml` (`flutter_lints` or `very_good_analysis`; pick one and justify it).
  - Flutter `.gitignore`.
  - **Tests first:** 🧪 a trivial test `test/smoke_test.dart` that fails (`expect(1, 2)`) and is then fixed, to check that the test setup works.
  - **Done when:** `flutter run -d windows` and `-d android` show the sample app; `flutter analyze` and `flutter test` pass.

- [x] **T0.2 Git hooks with Lefthook** · Depends on: T0.1
  - Install Lefthook on the machine, create `lefthook.yml` (SPEC §10.4) and run `lefthook install`.
  - Document the installation in the README.
  - **Tests first:** try to commit a badly formatted `.dart` file and check the hook blocks it; try to push with a failing test and check it is blocked.
  - **Done when:** both hooks block and, with everything correct, let the change through.

- [x] **T0.3 CI on GitHub Actions: quality** · Depends on: T0.1
  - > **Note:** `main` could not be protected (private repository on the free plan). The owner decided to keep it private and unprotected for now and to make it public once the app is roughly half built; protect `main` then. See SPEC §13.1.
  - `.github/workflows/ci.yml` with the `quality` job (SPEC §10.5): Flutter stable with cache, `pub get`, format check, analysis, `flutter test --coverage`.
  - Script that checks the coverage thresholds (90% `domain/`, 70% overall) and fails if they are not met. Until there is code in `domain/`, the `domain/` threshold is skipped.
  - Protect `main` on GitHub: require a PR and a green `quality` job.
  - **Tests first:** open a PR with a failing test and check CI turns red.
  - **Done when:** a correct PR passes and one with failures cannot be merged.

- [x] **T0.4 Drift database with all tables** · Depends on: T0.1
  - > **Note:** generated code (`*.g.dart`) is not committed; it is generated locally and in CI. See SPEC §13.2 (assumption 8).
  - Tables from SPEC §4.2 with their indexes (§4.3), `schemaVersion = 1`, connection via `drift_flutter`.
  - Constructor that accepts an in-memory connection for tests.
  - **Tests first:**
    - 🧪 the database opens in memory and every table is empty.
    - 🧪 insert a project, a deck and a card and read them back.
    - 🧪 deleting a card cascades to its options, statistics and attempts.
  - **Done when:** the tests pass and generated code is either ignored or committed according to the chosen convention (document it).

- [x] **T0.5 Core utilities: IDs, clock and randomness** · Depends on: T0.1
  - > **Note:** the "Done when" check is automated by `test/core/no_direct_time_or_random_test.dart`. The Riverpod providers that hand out the clock and the `Random` are added with Riverpod itself. See SPEC §13.2 (assumption 9).
  - `core/ids.dart` (UUID v4), `core/clock.dart` (injectable clock with real and fake implementations) and an injectable `Random` provider.
  - **Tests first:**
    - 🧪 two generated IDs are different and have UUID v4 format.
    - 🧪 the fake clock returns the time it was set to and can be advanced.
    - 🧪 two `Random` instances with the same seed produce the same sequence.
  - **Done when:** no file in `lib/` uses `DateTime.now()` or `Random()` directly (check with a search).

- [x] **T0.6 Light and dark theme** · Depends on: T0.1
  - > **Note:** light `text-muted` adjusted to `#736C67` for AA contrast. The test screen was `ThemePreviewScreen`, removed in T0.8. See SPEC §13.2 (assumption 10).
  - Colour tokens from `DESIGN_BRIEF.md` §3.1 as a `ThemeExtension`, project palette, Plus Jakarta Sans bundled in `assets/fonts/` (not downloaded at runtime), radii and spacing.
  - `ThemeMode.system` by default.
  - **Tests first:**
    - 🧪 the light and dark tokens have the values from the brief.
    - 🧪 text contrast on `primary-strong` is ≥ 4.5:1 in both themes.
    - 🧩 a test widget changes colours when the theme changes.
  - **Done when:** the tests pass and a test screen shows the design's colours and typeface.

- [x] **T0.7 Localisation and UI strings** · Depends on: T0.1
  - > **Note:** the generated classes (`lib/app/l10n/generated/`) are not committed; `flutter pub get` creates them and CI runs `flutter gen-l10n`. See SPEC §13.2 (assumption 11).
  - `flutter_localizations`, `l10n.yaml`, `lib/app/l10n/app_es.arb` with the first strings, locale `es`.
  - **Tests first:** 🧩 a test screen shows a string read from the ARB file.
  - **Done when:** `flutter gen-l10n` generates the classes and the test passes.

- [x] **T0.8 Navigation and responsive shell** · Depends on: T0.6, T0.7
  - > **Note:** route table and shell decisions in SPEC §13.2 (assumption 12). The sidebar's project list, search and daily goal card are filled in by phases 1 and 4.
  - `go_router` with the routes from SPEC §5.1 (empty screens with their title).
  - Responsive shell (SPEC §3.3): stack navigation on mobile and a fixed sidebar on desktop (≥ 840 dp), with the elements from the design (`design/escritorio-claro/`).
  - **Tests first:**
    - 🧩 at 390 px wide there is no sidebar; at 1440 px there is.
    - 🧩 navigating to `/project/:id` shows the project screen.
  - **Done when:** you can navigate between the empty screens on mobile and desktop.

- [x] **T0.9 Integration and E2E tests: setup** · Depends on: T0.3, T0.8
  - > **Note:** Patrol's iOS/macOS native setup is pending (it needs a Mac). See SPEC §13.2 (assumption 13).
  - Set up `integration_test` and Patrol following their documentation (test folder, native Android/iOS configuration).
  - Add the `integration-windows` and `e2e-android` (emulator) jobs to `ci.yml`.
  - **Tests first:**
    - 🔗 the app starts and shows the home screen.
    - 🤖 the app starts on the emulator and shows the home screen.
  - **Done when:** the three CI jobs are green.

- [x] **T0.10 App icons** · Depends on: T0.1
  - > **Note:** configured in `flutter_launcher_icons.yaml`; Windows and macOS use two images derived from the approved ones. The iOS dark/tinted icons and the macOS app name wait for a Mac. See SPEC §13.2 (assumption 14).
  - Generate the icons for each platform from `assets/branding/` (e.g. with `flutter_launcher_icons`): iOS, Android adaptive + monochrome, macOS and Windows.
  - **Done when:** the installed app shows the right icon on Windows and Android.

---

## Phase 1 — Projects and decks

- [x] **T1.1 Projects repository** · US-01, US-02 · Depends on: T0.4, T0.5
  - Create, edit, list, favourite and archive projects; update `last_used_at` (R 7.7).
  - **Tests first:**
    - 🧪 creating a project with no name fails; with 61 characters it fails.
    - 🧪 a language project without a source or target language fails.
    - 🧪 the list returns favourites first, then by last use; it excludes archived and deleted projects.
    - 🧪 switching from language to general does not delete the stored languages.

- [x] **T1.2 Dashboard** · P01 · US-05 · Depends on: T1.1, T0.8
  - > **Note:** adds Riverpod. Until phase 4 the header shows the greeting and the streak at 0 (no goal ring), and buttons of later tasks are hidden. The desktop sidebar lists and searches the projects. See SPEC §13.2 (assumption 16).
  - Project list with the design's project card, search by title, "Nuevo proyecto" button, empty state. Header with streak and goal (placeholder values until phase 4).
  - **Tests first:**
    - 🧩 with no projects, the empty state is shown.
    - 🧩 with 3 projects, 3 cards are shown, the favourite first.
    - 🧩 searching "ingles" finds "Inglés B2" (case- and accent-insensitive).

- [x] **T1.3 Create and edit project** · P02 · US-01, US-02 · Depends on: T1.2
  - > **Note:** the confirmation only appears when editing a stored language project. Language list chosen with the owner. See SPEC §13.2 (assumption 17).
  - Bottom sheet on mobile and dialog on desktop, with colour, icon, type and languages.
  - **Tests first:**
    - 🧩 the Save button is disabled without a name.
    - 🧩 choosing "Idioma" shows the language selectors.
    - 🧩 switching from "Idioma" to "General" asks for confirmation.

- [x] **T1.4 Decks repository** · US-06 · Depends on: T1.1
  - Create, edit and list a project's decks; colour inherited from the project when null.
  - **Tests first:**
    - 🧪 a deck without a colour returns the project's colour.
    - 🧪 the list excludes deleted decks.

- [ ] **T1.5 Project screen** · P03 · Depends on: T1.4
  - Header, metrics (placeholders until phase 4), buttons, tabs and deck list; on desktop, decks and summary side by side.
  - **Tests first:**
    - 🧩 shows the project's decks with their number of cards.
    - 🧩 with no decks, the empty state is shown.

- [ ] **T1.6 Create and edit deck** · P04 · US-06 · Depends on: T1.5
  - **Tests first:** 🧩 cannot save without a name; 🧩 the new deck appears in the list.

- [ ] **T1.7 Trash: logic** · R 7.1 · US-03, US-04 · Depends on: T1.1, T1.4
  - Move to trash, restore, delete permanently, empty, and purge expired items (called on app start and when the Trash screen opens, see T1.8).
  - **Tests first:**
    - 🧪 deleting a project hides it from the list and shows it in the trash.
    - 🧪 with the fake clock at 14 days it is still in the trash; at 15 days the purge permanently deletes it with its decks, cards, attempts and images.
    - 🧪 restoring a deck whose project is in the trash also restores the project.
    - 🧪 the remaining days are calculated correctly (15 − days elapsed).

- [ ] **T1.8 Delete with undo and Trash screen** · P15 · US-03, US-04 · Depends on: T1.7
  - Confirmation dialog with counts, 5-second "Deshacer" snackbar and trash screen.
  - **Tests first:**
    - 🧩 the dialog states how many decks and cards will be moved.
    - 🧩 tapping "Deshacer" within 5 s leaves the project where it was.
    - 🧩 in the trash, an item with 2 days left is flagged as urgent.
    - 🧩 opening the trash purges the items that expired while the app was open (fake clock moved past 15 days), so they are not listed.

- [ ] **T1.9 Archived** · P14 · US-05 · Depends on: T1.1
  - **Tests first:** 🧩 archiving a project removes it from the dashboard and it appears under Archived; 🧩 unarchiving brings it back.
  - **Phase wrap-up:** 🔗 create project → deck → archive → unarchive → delete → restore from the trash. 🤖 E2E-06.

---

## Phase 2 — Cards

- [ ] **T2.1 Card model and validation** · US-08, US-09 · Depends on: T0.4
  - Domain model for simple and test cards, with validation.
  - **Tests first:**
    - 🧪 a simple card with no answer is invalid.
    - 🧪 a test card with fewer than 2 or more than 6 options is invalid.
    - 🧪 a test card with no correct option is invalid.
    - 🧪 a test card without "allow multiple" and with 2 correct options is invalid; with "allow multiple" it is valid.
    - 🧪 empty options do not count.

- [ ] **T2.2 Cards repository** · US-11, US-12 · Depends on: T2.1
  - CRUD with options in a transaction, search and sorting.
  - **Tests first:**
    - 🧪 saving a test card saves its options with their position.
    - 🧪 editing a card keeps its statistics.
    - 🧪 search finds text in the question, answer and options.
    - 🧪 the three sort orders (newest, A–Z, most missed) return the right order.

- [ ] **T2.3 Card editor: simple** · P06 · US-08, US-10 · Depends on: T2.2, T1.6
  - Fields, bold and italic, "Guardar" and "Guardar y añadir otra"; language fields only in language projects. Two columns on desktop.
  - **Tests first:**
    - 🧩 Save is disabled without a question or without an answer.
    - 🧩 in a general project, "Frase de ejemplo" and "Notas" are not shown.
    - 🧩 "Guardar y añadir otra" clears the form, keeps the type and focuses the question.

- [ ] **T2.4 Card editor: test type** · US-09 · Depends on: T2.3
  - "Tipo test" toggle, list of 2 to 6 options, "Permitir varias correctas", explanation.
  - **Tests first:**
    - 🧩 turning on "Tipo test" replaces the answer with options and explanation.
    - 🧩 you cannot add more than 6 options or remove below 2.
    - 🧩 with "allow multiple" off, ticking an option unticks the previous one.
    - 🧩 turning off "allow multiple" with 2 ticked asks which one to keep.

- [ ] **T2.5 Preview and card component** · Depends on: T2.3
  - Reusable card component with every variant from `design/tarjetas/` and the 3D flip; used in the preview.
  - **Tests first:**
    - 🧩 tapping the preview shows the back.
    - 🧩 a test card shows its options with the right marker (radio or checkbox).

- [ ] **T2.6 Images on cards** · Depends on: T2.3
  - Pick an image (gallery on mobile, file on desktop), resize to 1600 px and JPEG 80, store the relative path, delete the image when the card is deleted.
  - **Tests first:**
    - 🧪 a 4000 px image is stored with its long side at 1600 px.
    - 🧪 deleting the card deletes the image file.

- [ ] **T2.7 Voice (TTS)** · US-13 · Depends on: T2.5
  - Voice service behind an interface (so it can be faked in tests), speaker button and notice when the voice is missing.
  - **Tests first:**
    - 🧪 the question is read in the source language and the answer in the target language.
    - 🧩 with no voice installed, the button is disabled and the notice is shown.

- [ ] **T2.8 Deck screen** · P05 · US-12 · Depends on: T2.2
  - List (table on desktop), search, sorting, actions and empty state.
  - **Tests first:** 🧩 the list shows type and % correct; 🧩 search filters as you type; 🧩 with no cards, the empty state with import and template is shown.

- [ ] **T2.9 Multi-select, copy, move and delete** · US-07, US-11 · Depends on: T2.8
  - **Tests first:**
    - 🧪 moving keeps the ID and statistics.
    - 🧪 copying creates cards with a new ID, copied options and no history.
    - 🧩 "Mover a…" only offers decks from the same project.
    - 🧩 deleting a card and tapping "Deshacer" recovers it; without undo, it is gone for good.
  - **Phase wrap-up:** 🔗 create cards of both types, edit, move and delete them.

---

## Phase 3 — Study session

- [ ] **T3.1 Card selection and shuffling** · R 7.2 · Depends on: T2.2, T0.5
  - Pure domain service.
  - **Tests first:**
    - 🧪 with a fixed seed, the result is always the same.
    - 🧪 never returns duplicates or cards from deleted decks.
    - 🧪 if more cards are requested than exist, it returns all of them.
    - 🧪 "errors only" returns only cards in errors for the chosen direction.
    - 🧪 with "prioritise", over 10,000 selections, weight-3 cards come up about 3 times as often as weight-1 cards.
    - 🧪 the output order does not match the creation order.
    - 🧪 test options are shuffled.

- [ ] **T3.2 Session engine** · R 7.3 · US-15 to US-17 · Depends on: T3.1
  - Session state machine, with no UI: queue, answer, "show answer", "leave for later", repeat missed cards, end of session.
  - **Tests first:**
    - 🧪 answering correctly or wrongly moves to the next card and updates the counters.
    - 🧪 "show answer" records a wrong answer with source `revealed`.
    - 🧪 "leave for later" moves the card to the end without recording anything and can be repeated.
    - 🧪 with "repeat missed", a missed card comes back at the end until answered correctly, and the repeat has `is_first_attempt = false`.
    - 🧪 on exit, pending cards are recorded as `unanswered`.
    - 🧪 in reverse direction, test cards are recorded as `normal`.

- [ ] **T3.3 Grading test cards** · US-16 · Depends on: T2.1
  - **Tests first:**
    - 🧪 one correct option ticked = correct.
    - 🧪 multiple answer: ticking exactly the correct ones = correct; one missing or one extra = wrong (no partial credit).

- [ ] **T3.4 Timers** · R 7.5 · US-18 · Depends on: T3.2
  - Per-question and global timers, mutually exclusive, frozen while paused and in the background.
  - **Tests first** (with `fake_async`):
    - 🧪 per question: reaching 0 records a wrong answer with source `timeout`.
    - 🧪 per question: "leave for later" restarts its time when the card comes back.
    - 🧪 global: reaching 0 ends the session with status `time_up` and pending cards as `unanswered`.
    - 🧪 time does not advance while paused.
    - 🧪 the warning turns on in the last 5 s or the last minute.

- [ ] **T3.5 Saving attempts and sessions** · Depends on: T3.2
  - Each answer is saved immediately, in a transaction.
  - **Tests first:**
    - 🧪 answering saves an attempt with the response time, excluding pauses.
    - 🧪 if the app "closes" midway (the engine is discarded), the answered attempts are in the database.
    - 🧪 session totals only count first attempts.

- [ ] **T3.6 Session setup** · P08 · US-14 · Depends on: T3.1, T1.5
  - **Tests first:**
    - 🧩 loads the project's last configuration.
    - 🧩 the number of available cards changes when the decks or mode change.
    - 🧩 "Sentido" (direction) only appears in language projects.
    - 🧩 with no cards available, "Empezar" is disabled.

- [ ] **T3.7 Session screen** · P09 · US-15, US-16 · Depends on: T3.2, T3.3, T3.4, T2.5
  - Top bar, card with flip, buttons per state, swipe gestures with haptics on mobile. Full screen on desktop.
  - **Tests first:**
    - 🧩 unflipped shows "Girar", "Ver respuesta" and "Dejar para el final"; flipped shows "Acerté" and "Fallé".
    - 🧩 in a test card, "Comprobar" is disabled with no selection; after checking, ✓ and ✗ and "Siguiente" are shown.
    - 🧩 swiping right records a correct answer and left a wrong one.
    - 🧩 the "n / total" progress and "+N repasos" update.

- [ ] **T3.8 Pause and exit** · P10 · US-19 · Depends on: T3.7
  - **Tests first:**
    - 🧩 while paused, the card is not visible.
    - 🧩 sending the app to the background pauses it.
    - 🧩 "Salir" asks for confirmation and goes to results.

- [ ] **T3.9 Results** · P11 · US-20 · Depends on: T3.5
  - **Tests first:**
    - 🧩 shows %, correct, wrong, unanswered, total and average time.
    - 🧩 at ≥ 80% the celebration is shown; at 79% it is not.
    - 🧩 "Repasar falladas ahora" starts a session with only the missed cards.

- [ ] **T3.10 Phase 3 wrap-up**
  - 🔗 Full session with simple and test cards, with and without timers.
  - 🤖 E2E-01 and E2E-03.

---

## Phase 4 — Statistics and errors

- [ ] **T4.1 Per-card statistics and error list** · R 7.4 · US-21 · Depends on: T3.5
  - Update `card_stats` when attempts are recorded, plus a full recalculation from `attempts`.
  - **Tests first:**
    - 🧪 a wrong answer puts the card in errors; two correct in a row take it out; correct-wrong-correct does not.
    - 🧪 repeats (`is_first_attempt = false`) and unanswered cards change nothing.
    - 🧪 normal and reverse directions keep separate statistics.
    - 🧪 recalculating from `attempts` gives the same result as the incremental update.

- [ ] **T4.2 Metrics and streak** · R 7.6 · US-23 · Depends on: T4.1
  - **Tests first:**
    - 🧪 % correct with and without data ("—").
    - 🧪 streak: consecutive days in local time; if there is no activity yet today, yesterday's streak still stands; a day with no activity breaks it.
    - 🧪 a day with only unanswered cards does not count towards the streak.
    - 🧪 daily goal progress.

- [ ] **T4.3 Real data on the dashboard, project and deck** · Depends on: T4.2, T1.2, T1.5, T2.8
  - Replace the placeholder values; "Repasar errores (N)" button only if N > 0 and never mixing projects.
  - **Tests first:** 🧩 with no errors, "Repasar errores" is not shown; 🧩 with 3 errors, it shows "(3)".

- [ ] **T4.4 "Errors only" mode and review** · US-21 · Depends on: T4.1, T3.6
  - **Tests first:** 🧪 a project's error session never includes cards from another project.

- [ ] **T4.5 Project statistics** · P12 · Depends on: T4.2
  - 30-day chart (chart colours from the brief), % per deck, most missed, session history.
  - **Tests first:**
    - 🧪 the 30-day series has 30 points, with zeros on days with no activity.
    - 🧩 the legend shows the totals with ✓ and ✗.

- [ ] **T4.6 Global statistics** · P13 · Depends on: T4.2
  - **Tests first:** 🧩 shows streak, best streak, today / 7 / 30 days and a summary per project, with no review buttons.

- [ ] **T4.7 Reset statistics** · Depends on: T4.1
  - Per card, deck and project, with confirmation.
  - **Tests first:** 🧪 resetting a deck deletes its attempts and statistics but not those of other decks; past session totals are kept.
  - **Phase wrap-up:** 🤖 E2E-02.

---

## Phase 5 — Import and export

- [ ] **T5.1 JSON schema and serialisation** · SPEC §8.2 · Depends on: T2.2
  - **Tests first:**
    - 🧪 exporting and re-importing a deck gives the same content (round trip).
    - 🧪 images travel as base64 and are restored as files.
    - 🧪 a JSON without `format` or with an unknown `version` is rejected with a clear error.

- [ ] **T5.2 CSV parser** · SPEC §8.3 · Depends on: T2.1
  - Fixtures in `test/fixtures/`.
  - **Tests first:**
    - 🧪 detects `;` and `,` as the separator.
    - 🧪 reads accents and "ñ" in UTF-8 with and without BOM.
    - 🧪 quoted fields containing `;` and line breaks.
    - 🧪 `correct = 1|3` creates a test card with "allow multiple".
    - 🧪 a row with no answer is reported as an error with its row number.
    - 🧪 missing `question` column → file rejected.

- [ ] **T5.3 Import engine** · SPEC §8.4 · Depends on: T5.1, T5.2
  - Preview, duplicates, new IDs and transaction.
  - **Tests first:**
    - 🧪 as a new project or deck, every ID is new.
    - 🧪 when adding to a deck, duplicates by ID or by normalised question and answer are skipped.
    - 🧪 if it fails midway, nothing is imported.
    - 🧪 the summary counts added, duplicates and errors.

- [ ] **T5.4 Import screen** · P07 · US-27 · Depends on: T5.3
  - 3-step wizard.
  - **Tests first:** 🧩 the preview shows "42 nuevas · 3 duplicadas · 1 con errores" for the matching fixture.

- [ ] **T5.5 Share project or deck** · US-26 · Depends on: T5.1, T5.2
  - JSON or CSV, without statistics; native share sheet on mobile and "Save as…" on desktop.
  - **Tests first:** 🧪 the shared JSON contains no attempts or statistics; 🧪 the exported CSV uses `;` and a BOM.

- [ ] **T5.6 Template and AI prompt** · US-28 · Depends on: T5.2
  - **Tests first:**
    - 🧪 the downloaded template imports with no errors.
    - 🧪 the prompt contains the template's exact header row.

- [ ] **T5.7 Backup: export all** · US-24 · Depends on: T5.1
  - **Tests first:** 🧪 the backup includes archived projects and projects in the trash, sessions, attempts and settings.

- [ ] **T5.8 Restore backup** · US-25 · Depends on: T5.7
  - **Tests first:**
    - 🧪 with an empty database, restoring leaves the data identical to the export.
    - 🧪 "replace all" deletes the current data.
    - 🧪 "merge" keeps the item with the most recent `updated_at` and recalculates `card_stats`.

- [ ] **T5.9 Phase 5 wrap-up**
  - 🔗 Export all → new database → restore → compare.
  - 🤖 E2E-04, E2E-05 and E2E-07.

---

## Phase 6 — Polish and release

- [ ] **T6.1 Animations** · DESIGN_BRIEF §8
  - 3D flip, correct and wrong flashes, card-to-card transition, timer pulse, celebration; fades if the system asks for reduced motion.
  - **Tests first:** 🧩 with "reduce motion" on, the flip animation is not used.

- [ ] **T6.2 Settings** · P16
  - Theme, card text size, daily goal, voice status.
  - **Tests first:** 🧩 the text size applies to the study card; 🧩 settings persist after restarting. 🤖 E2E-08.

- [ ] **T6.3 Accessibility** · SPEC §9
  - Semantic labels, touch targets ≥ 48 dp, system text at 200%.
  - **Tests first:** 🧩 the `flutter_test` accessibility guidelines (`meetsGuideline`) pass on the main screens.

- [ ] **T6.4 Empty and error states** · SPEC §5.3
  - **Tests first:** 🧩 each empty state in the list is shown with its text and action.

- [ ] **T6.5 Performance** · SPEC §9
  - **Tests first:** 🔗 a deck with 5,000 cards loads and scrolls without errors; starting a session takes less than 300 ms.

- [ ] **T6.6 Full visual review**
  - Compare each screen with `docs/design/` on mobile and desktop, light and dark. Note and fix differences.

- [ ] **T6.7 CD: `release.yml`**
  - Android signing with repository secrets; Android, Windows and macOS builds when a `v*` tag is created; attach them to a *Release*.
  - **Done when:** the `v1.0.0-rc.1` tag produces the three installers and they install.

- [ ] **T6.8 Version 1.0.0**
  - All tests and E2E green, coverage within thresholds, README updated and tag `v1.0.0`.
