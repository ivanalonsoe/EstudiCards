# AGENTS.md — EstudiCards

Instrucciones para agentes de código (Claude Code, Codex, Cursor…) que trabajen en este repositorio.

## Proyecto

EstudiCards es una app de tarjetas de estudio en **Flutter** para **Windows, macOS, Android e iOS**. Es 100% offline, sin login, con base de datos local SQLite.

Documentación de referencia (fuente de verdad):

- `docs/SPEC.md` — especificación funcional y técnica: modelo de datos, pantallas, historias de usuario, reglas de negocio, formatos de importación/exportación y plan por fases.
- `docs/DESIGN_BRIEF.md` — sistema visual, pantallas y componentes.

Si algo del código contradice el spec, **pregunta antes de cambiar el spec o el comportamiento**. Si el spec no cubre un caso, propón una solución, impleméntala de la forma más simple y anótala en la sección "Registro de decisiones" del spec.

## Sobre el usuario

El propietario del proyecto **está aprendiendo Flutter**. Por eso:

- Comunícate en **español**.
- Al terminar cada tarea, explica brevemente qué has hecho y por qué, sin jerga innecesaria.
- Prefiere código simple y legible a abstracciones ingeniosas.
- Cuando introduzcas un concepto nuevo (un provider, una migración, un DAO…), añade un comentario corto que lo explique la primera vez que aparece.
- No añadas dependencias nuevas sin justificarlo y sin avisar.

## Stack

| Pieza | Paquete |
|---|---|
| Base de datos | `drift` + `drift_flutter` (SQLite) |
| Estado | `flutter_riverpod` |
| Navegación | `go_router` |
| IDs | `uuid` (v4) |
| Voz | `flutter_tts` |
| Ficheros | `file_picker`, `share_plus`, `path_provider`, `image_picker`, `image` |
| CSV | `csv` |
| Gráficas | `fl_chart` |
| Textos | `flutter_localizations`, `intl` (ARB) |
| Tests | `flutter_test`, `mocktail` |

## Comandos

```bash
flutter pub get                                              # instalar dependencias
dart run build_runner build --delete-conflicting-outputs     # generar código (Drift, Riverpod)
flutter gen-l10n                                             # generar textos desde ARB
flutter analyze                                              # análisis estático (debe quedar sin avisos)
flutter test                                                 # tests
flutter run -d windows | macos | android | ios              # ejecutar
```

## Estructura

```
lib/
├── app/          # MaterialApp, router, tema (tokens del brief), l10n
├── core/         # db (Drift + migraciones), ids, clock, files, widgets comunes
└── features/     # projects, decks, cards, study, stats, import_export, settings
    └── <feature>/
        ├── data/          # tablas, DAOs, repositorios
        ├── domain/        # modelos y reglas de negocio puras (sin Flutter)
        └── presentation/  # pantallas, widgets, providers
test/             # espejo de lib/
docs/             # SPEC.md, DESIGN_BRIEF.md
```

## Reglas de código

- **Código en inglés** (clases, variables, tablas). **Textos de interfaz en español**, siempre en `lib/app/l10n/app_es.arb`, nunca escritos directamente en los widgets.
- **IDs:** UUID v4 generados en `core/ids.dart`. Nunca IDs autoincrementales.
- **Fechas:** guardar en UTC; mostrar en hora local.
- **Tiempo:** usar el reloj inyectable de `core/clock.dart`, nunca `DateTime.now()` directamente. Así se pueden probar timers, racha y papelera.
- **Reglas de negocio en `domain/`**, puras y con tests unitarios: selección y barajado de tarjetas, motor de sesión, timers, lista de errores, racha, papelera, parsers y validación de JSON/CSV.
- **Transacciones** en toda escritura que toque varias tablas (responder, importar, borrar, mover).
- **Esquema de base de datos:** cualquier cambio incrementa `schemaVersion` y añade su migración. Nunca editar una migración ya publicada.
- **Borrado:** proyectos y barajas se marcan con `deleted_at` (papelera 15 días). Las tarjetas se borran definitivamente tras el "Deshacer". Ver SPEC §7.1.
- **Estadísticas:** solo cuentan los primeros intentos (`is_first_attempt = true`). `card_stats` es derivada y debe poder recalcularse desde `attempts`.
- **Tema:** usar los tokens del tema (`Theme.of(context)` / extensiones), nunca colores literales en los widgets. Acierto y fallo siempre con icono además del color.
- **Diseño adaptable:** < 600 móvil, 600–839 tablet, ≥ 840 escritorio con barra lateral. Probar ambos.
- **Sin atajos de teclado** en la v1: todas las acciones son botones.
- **Sin red:** la app no hace peticiones HTTP.

## Forma de trabajar

1. Sigue el **plan por fases** de `docs/SPEC.md` §10. No empieces una fase sin que la anterior cumpla su "Hecho cuando".
2. Antes de implementar una historia de usuario, léela junto con sus criterios de aceptación y las reglas de negocio relacionadas.
3. Cambios pequeños y verificables. Tras cada cambio: `flutter analyze` sin avisos y `flutter test` en verde.
4. Añade o actualiza tests para toda regla de negocio que toques.
5. Commits con mensajes en español, en imperativo y descriptivos (p. ej. `Añade papelera con purga a 15 días`).
6. No marques una tarea como terminada si hay tests fallando o funcionalidad a medias; explica qué falta.
