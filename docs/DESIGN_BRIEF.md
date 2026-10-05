# Design brief — EstudiCards

> Document for Claude Design. It describes the visual design of a flashcard app for mobile and desktop. The full functional specification is in `SPEC.md`; this brief contains everything needed to design without reading it.
>
> **Status (30/09/2026):** approved: the design system (tokens and components), the card variant sheet, every mobile screen, dialogs and empty states, the desktop screens, the dark theme of every screen, and the app icon (main proposal: two cards with a ✓) and logo; their files are in `assets/branding/`. **The v1 visual design is complete.** Everything is on the design canvas "EstudiCards — Sistema de diseño" and exported as screenshots in [`design/`](design/). The values in this brief reflect what was approved.
>
> **Language:** the app UI is in Spanish, so every piece of UI copy in the designs (and quoted in this brief) is in Spanish. The meaning of the main labels is listed in `SPEC.md` §2.1.

---

## 1. The product in one sentence

**EstudiCards** is a flashcard app for Windows, macOS, Android and iOS. It organises content into **projects → decks → cards**, lets the user study with random sessions (with an optional timer) and records correct and wrong answers so mistakes can be reviewed.

- **User:** someone studying syllabi (public exams, school subjects, certifications) or languages, switching between computer and phone.
- **Technical platform:** Flutter. The design must be **identical on every platform** (no imitation of native iOS or Android controls) and buildable with customised Material 3 components.
- **UI language:** Spanish.

## 2. Personality and principles

**Personality:** focused, warm and motivating, without being childish.

1. **Minimal and modern.** Neutral backgrounds, plenty of white space, clear hierarchy. No busy illustrations or over-the-top gamification.
2. **The card is the star.** In a study session only the card and the answer buttons matter.
3. **Colour carries meaning.** Orange is the brand and the main action. Each project has its own accent colour, shown on its icon, on its cards' top band and on its decks.
4. **Never colour alone.** Correct and wrong always carry an icon (✓ / ✗) as well as green or red.
5. **Calm while studying.** Short, gentle animations. The final celebration is subtle.

Mood references (do not copy): the cleanliness of Things 3 or Linear, the clarity of Apple Wallet cards, and Duolingo's light motivation without its childish look.

## 3. Visual system

### 3.1 Colour

| Token | Light | Dark | Use |
|---|---|---|---|
| `primary` | `#F97316` | `#FB923C` | Accents, active icons, streak, daily goal ring |
| `primary-strong` | `#C2410C` | `#FDBA74` | Primary button fill (white text in light, `#1C1917` text in dark) to meet AA contrast |
| `primary-soft` | `#FFF1E6` | `#3A2314` | Selected chip and highlight backgrounds |
| `background` | `#FAFAF9` | `#0F0E0D` | App background |
| `surface` | `#FFFFFF` | `#1C1A18` | Cards, sheets, dialogs |
| `surface-variant` | `#F2F1EF` | `#282522` | Text fields, alternate rows |
| `border` | `#E7E5E4` | `#35312D` | Borders and dividers |
| `text` | `#1C1917` | `#F5F5F4` | Main text |
| `text-muted` | `#736C67` | `#A8A29E` | Secondary text (light value darkened from `#78716C` in T0.6: it gave 4.25:1 on `surface-variant`, below AA) |
| `success` | `#15803D` | `#4ADE80` | Correct (always with ✓) |
| `error` | `#BE123C` | `#FB7185` | Wrong (always with ✗). Raspberry red so it is not confused with the orange brand colour |
| `warning` | `#B45309` | `#FBBF24` | Timer about to run out |

The greys are warm (*stone* family) to go with the orange. Values can be adjusted as long as WCAG AA contrast is kept.

**Project palette** (12 colours the user picks for each project; light / dark theme value):

| Colour | Light | Dark |
|---|---|---|
| Orange | `#EA580C` | `#FB923C` |
| Amber | `#D97706` | `#FBBF24` |
| Lime | `#65A30D` | `#A3E635` |
| Green | `#16A34A` | `#4ADE80` |
| Teal | `#0D9488` | `#2DD4BF` |
| Cyan | `#0891B2` | `#22D3EE` |
| **Blue** | `#2563EB` | `#60A5FA` |
| Indigo | `#4F46E5` | `#818CF8` |
| Violet | `#7C3AED` | `#A78BFA` |
| Pink | `#DB2777` | `#F472B6` |
| Fuchsia | `#C026D3` | `#E879F9` |
| Slate | `#475569` | `#94A3B8` |

There is no "raspberry" in the palette: it was too close to the error red.

**Chart colours (correct / wrong):** correct `#15803D` and wrong `#FB7185` in light theme; correct `#16A34A` and wrong `#FB7185` in dark theme. The wrong-answer red is lightened in charts so it also differs from the green in lightness: with `#BE123C` next to `#15803D`, a person with red-green colour blindness cannot tell them apart. Charts always have a legend with ✓/✗ and values, and a 2 px gap between stacked segments.

### 3.2 Typography

- **Plus Jakarta Sans** (Google Fonts), weights 400, 500, 600, 700 and 800. Good legibility and full support for Spanish accents.
- Indicative scale: Display 32 · Title 22 · Subtitle 17 · Body 15 · Label 13 · Caption 12.
- **Study card text:** large (24–28 pt on mobile, 32–36 pt on desktop), centred. The user can scale it from 80% to 160%, so the card must handle long text (up to ~300 characters) with internal scrolling.

### 3.3 Shape and spacing

- 4 px grid (spacing of 4, 8, 12, 16, 24, 32, 48).
- Radii: study card 24 · list cards 16 · buttons and fields 12 · chips 999.
- Very soft shadows in light mode; in dark mode, elevation through lighter surfaces instead of shadows.
- Minimum touch targets of 48 px.

### 3.4 Iconography

Rounded, consistent line icons (Lucide style, 2 px stroke). Projects are represented by an icon from a curated set inside a square filled with the project colour at 12% opacity. The designs do not use emoji; the app may allow picking an emoji as an alternative.

## 4. Structure and navigation

- **Mobile (390 × 844):** stack navigation Dashboard → Project → Deck. The general menu (Archivados, Papelera, Estadísticas, Importar, Exportar todo, Ajustes) is in a side drawer or a menu on the dashboard. Floating button to create.
- **Desktop (1440 × 900):** fixed left sidebar (~280 px) with logo, search, project list (favourites on top) and, at the bottom, Archivados, Papelera, Estadísticas and Ajustes. The selected project or deck on the right.
- **No keyboard shortcuts:** on desktop every action is a visible button.

## 5. Sample content

Use realistic Spanish data on every screen:

| Project | Colour / icon | Type | Decks |
|---|---|---|---|
| Inglés B2 | Blue · globe icon | Language (English → Spanish) | Verbos irregulares (84), Phrasal verbs (52), Vocabulario viajes (120) |
| Oposiciones · Tema 3 | Orange · scales icon | General | Constitución (65), Ley 39/2015 (40) |
| Biología 2º Bach. | Green · flask icon | General | Célula (38), Genética (45) |
| Alemán A1 | Amber · globe icon | Language (German → Spanish) | Saludos (20) — **archived** |

Sample cards:
- **Simple (language):** "to bring" → "traer (brought, brought)". Example: "Can you **bring** me some water?". Notes: "Verbo irregular".
- **Test, one correct:** "¿Cuál es la capital de Australia?" → Sídney / **Canberra** / Melbourne / Perth. Explanation: "Canberra es la capital desde 1913".
- **Test, several correct:** "¿Qué números son primos?" → **2** / 4 / **7** / 9.
- **Simple (general, long):** "¿Qué establece el artículo 14 de la Constitución?" → "Los españoles son iguales ante la ley, sin que pueda prevalecer discriminación alguna…".

Sample statistics: 12-day streak, daily goal 14/20, 78% correct, 9 pending errors.

## 6. Screens to design

All on **mobile and desktop**, in **light and dark theme**.

### 6.1 Dashboard
- Header: short greeting, **streak** (flame icon + "12 días") and **daily goal ring** (14/20).
- Search by title.
- Project list: favourites first (with a star), then by last use. Each project card shows the icon in its colour, name, "3 barajas · 256 tarjetas", % correct, "Estudiado hace 2 días" and, if it has errors, a small **"Repasar errores (9)"** button. ⋮ menu: Editar, Compartir, Favorito, Archivar, Eliminar.
- Floating "Nuevo proyecto" button.
- **Empty state:** minimal illustration + "Crea tu primer proyecto" + button + "o importa uno" link.

### 6.2 Create / edit project (bottom sheet on mobile, dialog on desktop)
Name, description, colour picker (12 circles), icon/emoji picker and type (segmented: General / Idioma). If Idioma, source and target language appear.

### 6.3 Project
- Header in the project colour: icon, name, description and metrics (cards, % correct, errors).
- Main actions: **Estudiar** (primary button) and **Repasar errores (9)**. Secondary: Editar, Compartir, Importar.
- **Barajas** | **Estadísticas** tabs.
- Deck list: colour band, name, number of cards, % correct and errors. ⋮ menu per deck. "Nueva baraja" button.
- Empty state with no decks.

### 6.4 Project statistics (tab)
Stacked bar chart of correct/wrong per day (30 days), % correct per deck (horizontal bars), top 10 most missed cards and session history (date, decks, result, duration).

### 6.5 Deck
- Header with name, number of cards and actions: **Añadir tarjeta** (primary), **Estudiar**, **Repasar errores**, **Importar tarjetas**, **Descargar plantilla**, **Copiar prompt para IA**, **Compartir**.
- Search and sort selector (Recientes / A–Z / Más falladas).
- Card rows: question (1–2 lines), type icon (simple / test) and % correct with a small bar.
- **Multi-select mode:** checkboxes and an action bar (Copiar a…, Mover a…, Eliminar).
- "Mover a…" / "Copiar a…" dialog with the project's decks.
- Empty state: "Añade tu primera tarjeta", with "Importar desde CSV" and "Descargar plantilla".

### 6.6 Card editor
- **Pregunta** (question) field with a mini formatting bar (bold, italic) and a button to add an image.
- **Tipo test** toggle.
  - Off: **Respuesta** (answer) field (+ image).
  - On: list of **options** (2–6) with an "Añadir opción" button, remove option and correct-answer selector. **"Permitir varias correctas"** check: switches the radio selectors to checkboxes. **Explicación** field (optional, + image).
- In language projects: **Frase de ejemplo** and **Notas**.
- **Live preview** of the card, which flips when tapped: below the form on mobile and in a right-hand column on desktop.
- Buttons: **Guardar** and **Guardar y añadir otra**.
- Show validation states: empty question, fewer than 2 options, no correct option ticked.

### 6.7 Import (3-step wizard)
1. Choose file (JSON or CSV).
2. Choose destination, depending on where it was opened from: new project / new deck / add to this deck.
3. **Preview:** summary "42 nuevas · 3 duplicadas · 1 con errores", list of rows with errors ("Fila 7: falta la respuesta") and an Import button.

Final summary as a snackbar: "42 añadidas, 3 omitidas".

### 6.8 Session setup
Sheet or screen with:
- Decks: multi-select chips + "Todo el proyecto".
- Number of cards: segmented 10 / 20 / 50 / Todas / Otro.
- Mode: Normal / Solo errores.
- Direction: Normal / Inverso (languages only).
- Switches: "Priorizar las más falladas", "Repetir falladas al final".
- Timer: Sin timer / Por pregunta (5–120 s) / General (1–120 min), with a value control.
- Dynamic text: "84 tarjetas disponibles".
- **Empezar** button.

### 6.9 Study session
- Top bar: Exit button, progress "7 / 20" with a bar, ✓ 5 ✗ 2 counter, timer and Pause button.
- Large centred card.
- Bottom buttons depending on the state:
  - **Simple, not flipped:** Girar (primary) · Ver respuesta · Dejar para el final.
  - **Simple, flipped:** ✗ Fallé · ✓ Acerté (two large buttons, red and green).
  - **Test, unanswered:** Comprobar (primary) · Ver respuesta · Dejar para el final.
  - **Test, answered:** Siguiente.
- On mobile, dragging the flipped card hints at the result: green tint with ✓ to the right and red with ✗ to the left.
- If repeats are pending: "+3 repasos" next to the progress.
- On desktop, the card has a maximum width (~720 px), centred, with the buttons below.

### 6.10 Pause
Overlay that **completely hides the card** (opaque or heavily blurred background), with "En pausa", the elapsed time, and the Continuar and Salir buttons.

### 6.11 Results
- Large % correct in a ring, with correct, wrong and unanswered.
- Total time and average time per card.
- Collapsible **Falladas** (question + correct answer) and **No respondidas** sections.
- Buttons: **Repasar falladas ahora** (primary), Repetir sesión and Volver.
- Variant with a **subtle celebration** (≥ 80%): light confetti or an orange flash, no sound.
- Variant with the global timer run out: "Se acabó el tiempo" and the unanswered list highlighted.

### 6.12 Global statistics
Current and best streak, cards today / 7 days / 30 days, 30-day chart across all projects and a summary per project. No review buttons.

### 6.13 Archived, Trash and Settings
- **Archivados:** list with Desarchivar and Eliminar.
- **Papelera:** projects and decks labelled "Se elimina en 12 días", Restaurar, Eliminar definitivamente and Vaciar papelera.
- **Ajustes:** Tema (Sistema / Claro / Oscuro), card text size (slider with preview), daily goal, TTS voice status, Exportar todo, Restaurar copia and Acerca de.

### 6.14 Dialogs and snackbars
- Delete project: "Se moverán a la papelera 3 barajas y 256 tarjetas. Podrás recuperarlo durante 15 días."
- Delete card: simple confirmation.
- Bottom snackbar with **Deshacer** (5 s).
- Restore backup when data exists: **Reemplazar todo** / **Fusionar**.
- Share: choose **JSON** (for the app) or **CSV** (for Excel).
- Exit session: "Se guardarán tus respuestas".
- Voice not installed: notice with instructions.

## 7. Card style sheet

Besides the screens, one sheet with **every variant of the study card**, in light and dark:

1. Simple — front.
2. Simple — back.
3. Test — before checking (one option selected).
4. Test — after, correct (the correct one in green with ✓).
5. Test — after, wrong (the ticked one in red with ✗, the correct one in green with ✓, explanation visible).
6. Multiple-answer test — with checkboxes and the label "Varias respuestas correctas".
7. Language — front with a speaker button; back with translation, example sentence and notes.
8. With an image in the question and in the answer.
9. With the per-question timer running and in its last 5 s (ring or bar in `warning`).
10. Pause screen.
11. Long text with internal scrolling.
12. Mobile drag moment (correct and wrong tint).

**Card anatomy:** `surface` background, radius 24, top band or border in the project colour, small label at the top (deck name and type), centred content and a subtle "Toca para girar" (tap to flip) hint.

## 8. Motion

| Interaction | Animation |
|---|---|
| Flip card | 3D flip on the vertical axis, ~350 ms, smooth curve |
| Correct / wrong | Brief border flash in green or red with an icon, and light haptics on mobile |
| Next card | The card leaves towards the answer side and the next one comes in |
| Timer warning | Gentle pulse in the `warning` colour |
| Results | Ring fills up; light confetti if ≥ 80% |

Respect the system's reduce-motion setting (replace with fades).

## 9. Accessibility

- Minimum WCAG AA contrast in light and dark.
- Correct and wrong with an icon and text, never colour alone.
- The design must work with system text at 200% and card text at 160%.
- Touch targets of at least 48 px.
- Visible focus on desktop.

## 10. Expected deliverables

1. **Design tokens:** colours (light/dark), typography, spacing, radii, shadows and project palette.
2. **Components:** buttons (primary, secondary, text, danger), fields, toggles, chips, segmented controls, project card, deck row, card row, study card, progress bar, timer, goal ring, charts, snackbars with undo, dialogs and empty states.
3. **Every screen in section 6** on mobile (390 × 844) and desktop (1440 × 900), in light and dark, including empty states and dialogs.
4. **Card style sheet** (section 7).
5. **App icon and logo proposal** for "EstudiCards", simple, recognisable at 48 px and based on the brand orange. **Approved:** `#C2410C` plate, back card `#FDBA74` rotated and a white front card with a ✓ in `#C2410C` (dark variant: `#1C1917` plate, cards `#9A3412` and `#FB923C`). Logo: the mark without a plate + "Estudi**Cards**" in Plus Jakarta Sans 800, with "Cards" in orange. Exported files in `assets/branding/`: 1024 px SVG and PNG icons for iOS, Android (adaptive foreground and monochrome), macOS and Windows.

## 11. What to avoid

- Childish look, mascots or excessive gamification.
- Emoji as UI icons.
- Strong gradients, heavy glass effects or hard shadows.
- Using orange to signal errors (errors are raspberry red).
- Study screens with elements that distract from the card.
- iOS- or Android-specific controls that do not exist on the other platform.
- Keyboard shortcuts or key hints in the UI.
