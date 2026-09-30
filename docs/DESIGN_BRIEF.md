# Brief de diseño — EstudiCards

> Documento para Claude Design. Describe el diseño visual de una app de tarjetas de estudio para móvil y escritorio. La especificación funcional completa está en `SPEC.md`; este brief contiene todo lo necesario para diseñar sin leerla.
>
> **Estado (30/09/2026):** aprobados el sistema de diseño (tokens y componentes), la hoja de variantes de tarjeta y las pantallas principales de móvil en tema claro. También aprobados el resto de pantallas de móvil, los diálogos, los estados vacíos y las pantallas de escritorio. También aprobado el tema oscuro de todas las pantallas. También aprobados el icono de la app (propuesta principal: dos tarjetas con ✓) y el logotipo; sus ficheros están en `assets/branding/`. **El diseño visual de la v1 está completo.** Están en el lienzo de diseño "EstudiCards — Sistema de diseño". Los valores de este brief ya reflejan lo aprobado.

---

## 1. El producto en una frase

**EstudiCards** es una app de tarjetas de estudio para Windows, macOS, Android e iOS. Organiza el contenido en **proyectos → barajas → tarjetas**, permite estudiar con sesiones aleatorias (con temporizador opcional) y guarda aciertos y fallos para repasar los errores.

- **Usuario:** una persona que estudia temarios (oposiciones, asignaturas, certificaciones) o idiomas, y alterna entre ordenador y móvil.
- **Plataforma técnica:** Flutter. El diseño debe ser **idéntico en todas las plataformas** (no imitar los controles nativos de iOS o Android) y construible con componentes Material 3 personalizados.
- **Idioma de la interfaz:** español.

## 2. Personalidad y principios

**Personalidad:** enfocada, cálida y motivadora, sin ser infantil.

1. **Minimalista y moderna.** Fondos neutros, mucho espacio en blanco, jerarquía clara. Nada de ilustraciones recargadas ni gamificación exagerada.
2. **La tarjeta es la protagonista.** En la sesión de estudio solo importan la tarjeta y los botones de respuesta.
3. **El color tiene significado.** El naranja es la marca y la acción principal. Cada proyecto tiene su propio color de acento, que aparece en su icono, en la franja de sus tarjetas y en sus barajas.
4. **Nunca solo color.** Acierto y fallo siempre llevan icono (✓ / ✗) además del verde o rojo.
5. **Calma durante el estudio.** Animaciones cortas y suaves. La celebración final es discreta.

Referencias de sensación (no copiar): la limpieza de Things 3 o Linear, la claridad de las tarjetas de Apple Wallet y la motivación ligera de Duolingo sin su estética infantil.

## 3. Sistema visual

### 3.1 Color

| Token | Claro | Oscuro | Uso |
|---|---|---|---|
| `primary` | `#F97316` | `#FB923C` | Acentos, iconos activos, racha, anillo del objetivo diario |
| `primary-strong` | `#C2410C` | `#FDBA74` | Fondo de botones principales (texto blanco en claro, texto `#1C1917` en oscuro) para cumplir contraste AA |
| `primary-soft` | `#FFF1E6` | `#3A2314` | Fondos de chips seleccionados y destacados |
| `background` | `#FAFAF9` | `#0F0E0D` | Fondo de la app |
| `surface` | `#FFFFFF` | `#1C1A18` | Tarjetas, hojas, diálogos |
| `surface-variant` | `#F2F1EF` | `#282522` | Campos de texto, filas alternas |
| `border` | `#E7E5E4` | `#35312D` | Bordes y separadores |
| `text` | `#1C1917` | `#F5F5F4` | Texto principal |
| `text-muted` | `#78716C` | `#A8A29E` | Texto secundario |
| `success` | `#15803D` | `#4ADE80` | Acierto (siempre con ✓) |
| `error` | `#BE123C` | `#FB7185` | Fallo (siempre con ✗). Rojo frambuesa para que no se confunda con el naranja de marca |
| `warning` | `#B45309` | `#FBBF24` | Timer a punto de agotarse |

Los grises son cálidos (familia *stone*) para acompañar al naranja. Los valores son una propuesta: se pueden ajustar manteniendo el contraste WCAG AA.

**Paleta de proyectos** (12 colores que el usuario elige para cada proyecto; valor para tema claro / oscuro):

| Color | Claro | Oscuro |
|---|---|---|
| Naranja | `#EA580C` | `#FB923C` |
| Ámbar | `#D97706` | `#FBBF24` |
| Lima | `#65A30D` | `#A3E635` |
| Verde | `#16A34A` | `#4ADE80` |
| Turquesa | `#0D9488` | `#2DD4BF` |
| Cian | `#0891B2` | `#22D3EE` |
| **Azul** | `#2563EB` | `#60A5FA` |
| Índigo | `#4F46E5` | `#818CF8` |
| Violeta | `#7C3AED` | `#A78BFA` |
| Rosa | `#DB2777` | `#F472B6` |
| Fucsia | `#C026D3` | `#E879F9` |
| Pizarra | `#475569` | `#94A3B8` |

No hay "frambuesa" en la paleta: se confundía con el rojo de fallo (`error`).

**Colores en gráficas (aciertos / fallos):** aciertos `#15803D` y fallos `#FB7185` en tema claro; aciertos `#16A34A` y fallos `#FB7185` en tema oscuro. El rojo de fallo se aclara en las gráficas para que se distinga del verde también por luminosidad: con `#BE123C` junto a `#15803D` una persona con daltonismo rojo-verde no los diferencia. Las gráficas llevan siempre leyenda con ✓/✗ y valores, y un espacio de 2 px entre segmentos apilados.

### 3.2 Tipografía

- **Plus Jakarta Sans** (Google Fonts), pesos 400, 500, 600, 700 y 800. Buena legibilidad y soporte completo de acentos.
- Escala orientativa: Display 32 · Título 22 · Subtítulo 17 · Cuerpo 15 · Etiqueta 13 · Pie 12.
- **Texto de la tarjeta de estudio:** grande (24–28 pt en móvil, 32–36 pt en escritorio), centrado. El usuario puede escalarlo del 80% al 160%, así que el diseño de la tarjeta debe aguantar textos largos (hasta ~300 caracteres) con desplazamiento interno.

### 3.3 Forma y espaciado

- Rejilla de 4 px (espaciados de 4, 8, 12, 16, 24, 32, 48).
- Radios: tarjeta de estudio 24 · tarjetas de lista 16 · botones y campos 12 · chips 999.
- Sombras muy suaves en modo claro; en modo oscuro, elevación mediante superficies más claras en lugar de sombras.
- Áreas táctiles mínimas de 48 px.

### 3.4 Iconografía

Iconos de línea redondeados y consistentes (estilo Lucide, trazo 2). Los proyectos se representan con un icono de una selección curada dentro de un cuadrado con el color del proyecto al 12% de opacidad. En los diseños no se usan emojis; la app puede permitir elegir emoji como alternativa.

## 4. Estructura y navegación

- **Móvil (390 × 844):** navegación en pila Dashboard → Proyecto → Baraja. El menú general (Archivados, Papelera, Estadísticas, Importar, Exportar todo, Ajustes) está en un cajón lateral o menú desde el dashboard. Botón flotante para crear.
- **Escritorio (1440 × 900):** barra lateral izquierda fija (~280 px) con logo, buscador, lista de proyectos (favoritos arriba) y, al pie, Archivados, Papelera, Estadísticas y Ajustes. A la derecha, el contenido del proyecto o baraja seleccionados.
- **Sin atajos de teclado:** en escritorio todas las acciones son botones visibles.

## 5. Contenido de ejemplo

Usar datos realistas en español para todas las pantallas:

| Proyecto | Color / icono | Tipo | Barajas |
|---|---|---|---|
| Inglés B2 | Azul · icono globo | Idioma (inglés → español) | Verbos irregulares (84), Phrasal verbs (52), Vocabulario viajes (120) |
| Oposiciones · Tema 3 | Naranja · icono balanza | General | Constitución (65), Ley 39/2015 (40) |
| Biología 2º Bach. | Verde · icono matraz | General | Célula (38), Genética (45) |
| Alemán A1 | Ámbar · icono globo | Idioma (alemán → español) | Saludos (20) — **archivado** |

Tarjetas de ejemplo:
- **Simple (idioma):** "to bring" → "traer (brought, brought)". Ejemplo: "Can you **bring** me some water?". Notas: "Verbo irregular".
- **Test, una correcta:** "¿Cuál es la capital de Australia?" → Sídney / **Canberra** / Melbourne / Perth. Explicación: "Canberra es la capital desde 1913".
- **Test, varias correctas:** "¿Qué números son primos?" → **2** / 4 / **7** / 9.
- **Simple (general, larga):** "¿Qué establece el artículo 14 de la Constitución?" → "Los españoles son iguales ante la ley, sin que pueda prevalecer discriminación alguna…".

Estadísticas de ejemplo: racha 12 días, objetivo diario 14/20, 78% de aciertos, 9 errores pendientes.

## 6. Pantallas a diseñar

Todas en **móvil y escritorio**, en **tema claro y oscuro**.

### 6.1 Dashboard
- Cabecera: saludo breve, **racha** (icono de llama + "12 días") y **anillo de objetivo diario** (14/20).
- Buscador por título.
- Lista de proyectos: favoritos primero (con estrella), después por último uso. Cada tarjeta de proyecto muestra icono con su color, nombre, "3 barajas · 256 tarjetas", % de aciertos, "Estudiado hace 2 días" y, si tiene errores, un botón pequeño **"Repasar errores (9)"**. Menú ⋮: Editar, Compartir, Favorito, Archivar, Eliminar.
- Botón flotante "Nuevo proyecto".
- **Estado vacío:** ilustración mínima + "Crea tu primer proyecto" + botón + enlace "o importa uno".

### 6.2 Crear / editar proyecto (hoja inferior en móvil, diálogo en escritorio)
Nombre, descripción, selector de color (12 círculos), selector de icono/emoji y tipo (segmentado: General / Idioma). Si es Idioma, aparecen idioma origen y destino.

### 6.3 Proyecto
- Cabecera con el color del proyecto: icono, nombre, descripción y métricas (tarjetas, % aciertos, errores).
- Acciones principales: **Estudiar** (botón primario) y **Repasar errores (9)**. Secundarias: Editar, Compartir, Importar.
- Pestañas **Barajas** | **Estadísticas**.
- Lista de barajas: franja de color, nombre, nº de tarjetas, % aciertos y errores. Menú ⋮ por baraja. Botón "Nueva baraja".
- Estado vacío sin barajas.

### 6.4 Estadísticas del proyecto (pestaña)
Gráfica de barras apiladas aciertos/fallos por día (30 días), % de aciertos por baraja (barras horizontales), top 10 de tarjetas más falladas e historial de sesiones (fecha, barajas, resultado, duración).

### 6.5 Baraja
- Cabecera con nombre, nº de tarjetas y acciones: **Añadir tarjeta** (primario), **Estudiar**, **Repasar errores**, **Importar tarjetas**, **Descargar plantilla**, **Copiar prompt para IA**, **Compartir**.
- Buscador y selector de orden (Recientes / A–Z / Más falladas).
- Filas de tarjeta: pregunta (1–2 líneas), icono de tipo (simple / test) y % de aciertos con una pequeña barra.
- **Modo selección múltiple:** casillas y barra de acciones (Copiar a…, Mover a…, Eliminar).
- Diálogo "Mover a…" / "Copiar a…" con la lista de barajas del proyecto.
- Estado vacío: "Añade tu primera tarjeta", con "Importar desde CSV" y "Descargar plantilla".

### 6.6 Editor de tarjeta
- Campo **Pregunta** con mini barra de formato (negrita, cursiva) y botón para añadir imagen.
- Toggle **Tipo test**.
  - Desactivado: campo **Respuesta** (+ imagen).
  - Activado: lista de **opciones** (2–6) con botón "Añadir opción", quitar opción y selector de correcta. Check **"Permitir varias correctas"**: cambia los selectores de radio a casillas. Campo **Explicación** (opcional, + imagen).
- En proyectos de idioma: **Frase de ejemplo** y **Notas**.
- **Vista previa en vivo** de la tarjeta, que se gira al pulsarla: debajo del formulario en móvil y en una columna a la derecha en escritorio.
- Botones: **Guardar** y **Guardar y añadir otra**.
- Mostrar los estados de validación: pregunta vacía, menos de 2 opciones, ninguna correcta marcada.

### 6.7 Importar (asistente de 3 pasos)
1. Elegir fichero (JSON o CSV).
2. Elegir destino, según desde dónde se abre: proyecto nuevo / baraja nueva / añadir a esta baraja.
3. **Vista previa:** resumen "42 nuevas · 3 duplicadas · 1 con errores", lista de filas con error ("Fila 7: falta la respuesta") y botón Importar.

Resumen final como aviso: "42 añadidas, 3 omitidas".

### 6.8 Configurar sesión
Hoja o pantalla con:
- Barajas: chips de selección múltiple + "Todo el proyecto".
- Nº de tarjetas: segmentado 10 / 20 / 50 / Todas / Personalizado.
- Modo: Normal / Solo errores.
- Sentido: Normal / Inverso (solo en idiomas).
- Interruptores: "Priorizar las más falladas", "Repetir falladas al final".
- Timer: Sin timer / Por pregunta (5–120 s) / General (1–120 min), con un control de valor.
- Texto dinámico: "84 tarjetas disponibles".
- Botón **Empezar**.

### 6.9 Sesión de estudio
- Barra superior: botón Salir, progreso "7 / 20" con barra, contador ✓ 5 ✗ 2, timer y botón Pausa.
- Tarjeta grande centrada.
- Botones inferiores según el estado:
  - **Simple sin girar:** Girar (primario) · Ver respuesta · Dejar para el final.
  - **Simple girada:** ✗ Fallé · ✓ Acerté (dos botones grandes, rojo y verde).
  - **Test sin responder:** Comprobar (primario) · Ver respuesta · Dejar para el final.
  - **Test respondida:** Siguiente.
- En móvil, al arrastrar la tarjeta girada se insinúa el resultado: tinte verde con ✓ a la derecha y rojo con ✗ a la izquierda.
- Si hay repeticiones pendientes: "+3 repasos" junto al progreso.
- En escritorio, la tarjeta tiene un ancho máximo (~720 px) centrada, con los botones debajo.

### 6.10 Pausa
Superposición que **oculta completamente la tarjeta** (fondo opaco o muy desenfocado), con "En pausa", el tiempo transcurrido y los botones Continuar y Salir.

### 6.11 Resultados
- Gran porcentaje de aciertos en un anillo, con aciertos, fallos y sin responder.
- Tiempo total y tiempo medio por tarjeta.
- Secciones plegables **Falladas** (pregunta + respuesta correcta) y **No respondidas**.
- Botones: **Repasar falladas ahora** (primario), Repetir sesión y Volver.
- Variante con **celebración discreta** (≥ 80%): confeti ligero o destello naranja, sin sonido.
- Variante con timer general agotado: "Se acabó el tiempo" y la lista de no respondidas destacada.

### 6.12 Estadísticas globales
Racha actual y récord, tarjetas hoy / 7 días / 30 días, gráfica de 30 días de todos los proyectos y resumen por proyecto. Sin botones de repaso.

### 6.13 Archivados, Papelera y Ajustes
- **Archivados:** lista con Desarchivar y Eliminar.
- **Papelera:** proyectos y barajas con etiqueta "Se elimina en 12 días", Restaurar, Eliminar definitivamente y Vaciar papelera.
- **Ajustes:** Tema (Sistema / Claro / Oscuro), tamaño de texto de las tarjetas (deslizador con vista previa), objetivo diario, estado de voces TTS, Exportar todo, Restaurar copia y Acerca de.

### 6.14 Diálogos y avisos
- Eliminar proyecto: "Se moverán a la papelera 3 barajas y 256 tarjetas. Podrás recuperarlo durante 15 días."
- Eliminar tarjeta: confirmación simple.
- Aviso inferior con **Deshacer** (5 s).
- Restaurar copia con datos existentes: **Reemplazar todo** / **Fusionar**.
- Compartir: elegir **JSON** (para la app) o **CSV** (para Excel).
- Salir de la sesión: "Se guardarán tus respuestas".
- Voz no instalada: aviso con instrucciones.

## 7. Hoja de estilos de la tarjeta

Además de las pantallas, una lámina con **todas las variantes de la tarjeta de estudio**, en claro y oscuro:

1. Simple — anverso.
2. Simple — reverso.
3. Test — antes de comprobar (una opción seleccionada).
4. Test — después, acierto (correcta en verde con ✓).
5. Test — después, fallo (marcada en rojo con ✗, correcta en verde con ✓, explicación visible).
6. Test multirespuesta — con casillas y la indicación "Varias respuestas correctas".
7. Idioma — anverso con botón de altavoz; reverso con traducción, frase de ejemplo y notas.
8. Con imagen en la pregunta y en la respuesta.
9. Con timer por pregunta activo y en sus últimos 5 s (anillo o barra en `warning`).
10. Pantalla de pausa.
11. Texto largo con desplazamiento interno.
12. Momento del arrastre en móvil (tinte de acierto y de fallo).

**Anatomía de la tarjeta:** superficie `surface`, radio 24, franja o borde superior con el color del proyecto, etiqueta pequeña arriba (nombre de la baraja y tipo), contenido centrado y un indicador sutil "Toca para girar".

## 8. Movimiento

| Interacción | Animación |
|---|---|
| Girar tarjeta | Giro 3D sobre el eje vertical, ~350 ms, curva suave |
| Acierto / fallo | Destello breve del borde en verde o rojo con icono, y vibración ligera en móvil |
| Siguiente tarjeta | La tarjeta sale hacia el lado de la respuesta y entra la siguiente |
| Timer en aviso | Pulso suave en color `warning` |
| Resultados | Anillo que se rellena; confeti ligero si ≥ 80% |

Respetar la opción del sistema de reducir movimiento (sustituir por fundidos).

## 9. Accesibilidad

- Contraste mínimo WCAG AA en claro y oscuro.
- Acierto y fallo con icono y texto, nunca solo color.
- El diseño debe funcionar con el texto del sistema al 200% y el texto de tarjeta al 160%.
- Áreas táctiles de al menos 48 px.
- Foco visible en escritorio.

## 10. Entregables esperados

1. **Tokens de diseño:** colores (claro/oscuro), tipografía, espaciado, radios, sombras y paleta de proyectos.
2. **Componentes:** botones (primario, secundario, texto, peligro), campos, toggles, chips, segmentados, tarjeta de proyecto, fila de baraja, fila de tarjeta, tarjeta de estudio, barra de progreso, timer, anillo de objetivo, gráficas, avisos con Deshacer, diálogos y estados vacíos.
3. **Todas las pantallas de la sección 6** en móvil (390 × 844) y escritorio (1440 × 900), en claro y oscuro, incluidos estados vacíos y diálogos.
4. **Hoja de estilos de la tarjeta** (sección 7).
5. **Propuesta de icono de app y logotipo** para "EstudiCards", simple, reconocible a 48 px y basado en el naranja de marca. **Aprobado:** placa `#C2410C`, tarjeta trasera `#FDBA74` girada y tarjeta delantera blanca con un ✓ en `#C2410C` (variante oscura: placa `#1C1917`, tarjetas `#9A3412` y `#FB923C`). Logotipo: la marca sin placa + "Estudi**Cards**" en Plus Jakarta Sans 800, con "Cards" en naranja. Ficheros exportados en `assets/branding/`: iconos SVG y PNG de 1024 px para iOS, Android (primer plano adaptativo y monocromo), macOS y Windows.

## 11. Qué evitar

- Estética infantil, mascotas o exceso de gamificación.
- Emojis como iconos de interfaz.
- Degradados fuertes, efecto cristal pesado o sombras duras.
- Usar el naranja para indicar errores (el error es rojo frambuesa).
- Pantallas de estudio con elementos que distraigan de la tarjeta.
- Controles específicos de iOS o Android que no existan en la otra plataforma.
- Atajos de teclado o indicaciones de teclas en la interfaz.
