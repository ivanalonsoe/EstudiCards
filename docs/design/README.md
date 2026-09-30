# EstudiCards design — screenshots

Screenshots of every screen in the approved design (30/09/2026). They are the **visual reference** for building the UI: each screen must match its screenshot, in light and dark.

- The original, editable design is on the **"EstudiCards — Sistema de diseño"** canvas in the owner's Claude account. There, the study session is a working prototype.
- Exact values (colours, sizes, radii) are in [`../DESIGN_BRIEF.md`](../DESIGN_BRIEF.md). If a screenshot and the brief disagree, **the brief wins**.
- **UI language:** all UI copy is in Spanish, as in the app.
- **Typeface:** the screenshots were rendered with **Poppins** as a substitute, because Plus Jakarta Sans was not available at export time. The app uses **Plus Jakarta Sans** (slightly narrower), so text may take up a little less space than in the screenshots.
- Mobile at 390 × 844 (exported at 2× resolution); desktop at 1440 × 900.
- Folder and file names are in Spanish (`movil` = mobile, `escritorio` = desktop, `claro` = light, `oscuro` = dark).

## Contents

| Folder | Screens |
|---|---|
| [`sistema/`](sistema/) | `tokens.png` (colours, project palette, typography, spacing, radii, elevation) · `componentes.png` (buttons, fields, controls, progress, lists, snackbars, dialog, empty state) |
| [`tarjetas/`](tarjetas/) | `tarjetas-claro.png` and `tarjetas-oscuro.png`: the 12 study card variants |
| [`movil-claro/`](movil-claro/) · [`movil-oscuro/`](movil-oscuro/) | `dashboard`, `dashboard-vacio` (empty), `nuevo-proyecto` (new project), `proyecto` (project), `baraja` (deck), `editor`, `configurar` (session setup), `estudio` (study), `resultados` (results), `estadisticas` (project statistics), `estadisticas-globales` (global statistics), `importar` (import), `papelera` (trash), `archivados` (archived), `ajustes` (settings), `dialogos` (dialogs); dark also has `estudio-test-fallado` (missed test card) |
| [`escritorio-claro/`](escritorio-claro/) · [`escritorio-oscuro/`](escritorio-oscuro/) | `dashboard`, `proyecto`, `baraja` (with multi-select), `editor`, `configurar`, `sesion` (study session), `resultados`, `estadisticas` |
| [`marca/`](marca/) | `icono-logotipo.png`: icon per platform, small sizes and logo. The icon files are in [`../../assets/branding/`](../../assets/branding/) |

The desktop screens not shown here (trash, archived, settings, dialogs) follow the same design as on mobile, inside the content area or as a centred window.
