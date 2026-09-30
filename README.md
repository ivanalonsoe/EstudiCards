# EstudiCards

App de tarjetas de estudio (flashcards) para **Windows, macOS, Android e iOS**, hecha con **Flutter**. Organiza lo que estudias en proyectos y barajas, practica con sesiones aleatorias con temporizador y repasa tus errores.

> **Estado:** en diseño. La especificación está cerrada y el desarrollo empieza por la fase 0 (ver [Hoja de ruta](#hoja-de-ruta)).

---

## Características (v1)

- **Proyectos → barajas → tarjetas.** Por ejemplo, el proyecto "Inglés B2" con las barajas "Verbos irregulares" y "Phrasal verbs".
- **Dos tipos de tarjeta:**
  - **Simple:** pregunta, palabra o frase, y su respuesta o traducción. Se gira al pulsarla.
  - **Test:** de 2 a 6 opciones, con una o varias correctas. La app corrige automáticamente.
- **Proyectos de idioma:** voz (TTS del sistema, gratis y sin conexión), frase de ejemplo, notas y **modo inverso**.
- **Sesiones de estudio** configurables:
  - número de tarjetas, barajas, modo normal o **solo errores**;
  - **timer por pregunta** o **timer general**;
  - tarjetas y opciones siempre desordenadas;
  - pausa (oculta la pregunta), "Ver respuesta" y "Dejar para el final".
- **Seguimiento de aciertos y fallos** por tarjeta. Una tarjeta entra en la lista de errores al fallarla y sale al acertarla dos veces seguidas.
- **Estadísticas** por proyecto y globales, **racha diaria** y objetivo diario opcional.
- **Importar y exportar:**
  - copia de seguridad completa en JSON;
  - compartir un proyecto o una baraja en JSON o CSV (por WhatsApp, email…);
  - importar tarjetas desde CSV, con plantilla descargable y un **prompt para generarlas con IA**.
- **Papelera** de 15 días para proyectos y barajas.
- **Tema claro y oscuro.** 100% offline, sin cuentas ni login.

## Documentación

| Documento | Contenido |
|---|---|
| [`docs/SPEC.md`](docs/SPEC.md) | Especificación funcional y técnica: modelo de datos, pantallas, historias de usuario, reglas de negocio, formatos de importación y exportación y plan por fases. |
| [`docs/DESIGN_BRIEF.md`](docs/DESIGN_BRIEF.md) | Brief visual para Claude Design: colores, tipografía, pantallas, variantes de tarjeta y animaciones. |
| [`AGENTS.md`](AGENTS.md) | Instrucciones para agentes de código (Claude Code, Codex, Cursor…). |
| [`CLAUDE.md`](CLAUDE.md) | Punto de entrada para Claude Code; importa `AGENTS.md`. |

## Tecnología

| Pieza | Paquete |
|---|---|
| Framework | Flutter (stable) + Dart 3 |
| Base de datos local | `drift` (SQLite) |
| Estado | `flutter_riverpod` |
| Navegación | `go_router` |
| Voz | `flutter_tts` |
| Ficheros y compartir | `file_picker`, `share_plus`, `path_provider`, `image_picker`, `image` |
| CSV y gráficas | `csv`, `fl_chart` |
| Textos (español) | `flutter_localizations`, `intl` |
| Tests | `flutter_test`, `mocktail` |

## Requisitos para desarrollar

- **Flutter SDK** (canal stable). Guía de instalación: <https://docs.flutter.dev/get-started/install>
- Un editor: **VS Code** con la extensión *Flutter*, o **Android Studio**.
- Según la plataforma que quieras compilar:

| Plataforma | Necesitas |
|---|---|
| Android | Android Studio (SDK de Android y un emulador o un móvil con depuración USB) |
| Windows | Un PC con Windows y **Visual Studio 2022** con la carga de trabajo *Desarrollo para el escritorio con C++* |
| macOS / iOS | Un **Mac** con **Xcode** (y CocoaPods). iOS y macOS solo se pueden compilar desde un Mac. |

Comprueba que todo está bien instalado con:

```bash
flutter doctor
```

## Puesta en marcha

```bash
# 1. Clonar el repositorio
git clone <url-del-repositorio> estudicards
cd estudicards

# 2. Instalar dependencias
flutter pub get

# 3. Generar código (tablas de Drift, providers) y textos
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n

# 4. Ejecutar
flutter run -d windows     # o: macos, android, ios
```

> Cada vez que cambies las tablas de la base de datos o los providers, vuelve a ejecutar el paso 3.
> Durante el desarrollo puedes dejarlo en modo automático con `dart run build_runner watch`.

## Comandos útiles

| Comando | Para qué sirve |
|---|---|
| `flutter analyze` | Revisa el código en busca de errores y malas prácticas. Debe quedar sin avisos. |
| `flutter test` | Ejecuta los tests. |
| `flutter devices` | Lista los dispositivos y emuladores disponibles. |
| `flutter build apk` | Genera el instalador de Android. |
| `flutter build windows` | Genera el ejecutable de Windows. |
| `flutter build macos` / `flutter build ios` | Genera la app para Mac o iPhone (desde un Mac). |

## Estructura del proyecto

```
estudicards/
├── lib/
│   ├── main.dart
│   ├── app/            # arranque, tema, rutas, textos (app_es.arb)
│   ├── core/           # base de datos, IDs, reloj, ficheros, widgets comunes
│   └── features/       # una carpeta por funcionalidad
│       ├── projects/       # dashboard, proyectos, archivados, papelera
│       ├── decks/          # barajas y lista de tarjetas
│       ├── cards/          # editor de tarjetas y vista previa
│       ├── study/          # configuración, sesión de estudio, resultados
│       ├── stats/          # estadísticas, errores, racha
│       ├── import_export/  # JSON, CSV, plantilla, prompt IA
│       └── settings/       # ajustes
├── test/               # tests (misma estructura que lib/)
├── docs/               # SPEC.md, DESIGN_BRIEF.md
├── AGENTS.md
├── CLAUDE.md
└── README.md
```

Cada funcionalidad se divide en `data/` (base de datos), `domain/` (reglas de negocio, sin Flutter) y `presentation/` (pantallas).

## Crear tarjetas con IA

1. En una baraja, pulsa **Descargar plantilla** o **Copiar prompt para IA**.
2. Pega el prompt en Claude, ChatGPT u otra IA, sustituyendo el tema, el número de tarjetas y el nivel.
3. Guarda la respuesta como `.csv` y pulsa **Importar tarjetas**.
4. Revisa la vista previa (nuevas, duplicadas y filas con errores) y confirma.

Formato CSV (separador `;`, UTF-8):

```csv
pregunta;respuesta;opcion1;opcion2;opcion3;opcion4;opcion5;opcion6;correctas;explicacion;ejemplo;notas
to bring;traer (brought, brought);;;;;;;;;Can you bring me some water?;Verbo irregular
¿Capital de Australia?;;Sídney;Canberra;Melbourne;;;;2;Canberra es la capital desde 1913.;;
¿Qué números son primos?;;2;4;7;9;;;1|3;;;
```

Todos los detalles están en [`docs/SPEC.md` §8](docs/SPEC.md#8-importación-y-exportación).

## Hoja de ruta

| Fase | Contenido | Estado |
|---|---|---|
| 0. Base | Proyecto Flutter, tema, rutas, base de datos | ⏳ Pendiente |
| 1. Proyectos y barajas | Dashboard, favoritos, archivar, papelera | ⏳ Pendiente |
| 2. Tarjetas | Editor simple y test, vista previa, imágenes, voz | ⏳ Pendiente |
| 3. Sesión de estudio | Selección aleatoria, timers, pausa, resultados | ⏳ Pendiente |
| 4. Estadísticas y errores | Lista de errores, estadísticas, racha | ⏳ Pendiente |
| 5. Importar y exportar | JSON, CSV, plantilla, prompt IA | ⏳ Pendiente |
| 6. Pulido | Animaciones, accesibilidad, iconos, empaquetado | ⏳ Pendiente |

**Próximos objetivos (después de la v1):** login y sincronización en la nube, versión web, voces de IA, repetición espaciada, modo "escribir la respuesta", fórmulas y código en las tarjetas, atajos de teclado y más idiomas de interfaz.

## Privacidad

EstudiCards no usa cuentas, analíticas ni conexión a internet. Tus datos solo salen del dispositivo cuando tú los exportas o compartes.

## Licencia

Por definir.
