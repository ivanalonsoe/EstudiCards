## EstudiCards 1.0

La primera versión completa de EstudiCards: una app de tarjetas para estudiar que funciona **sin conexión y sin cuenta**. Tus datos se quedan en tu dispositivo.

### Qué incluye

- **Proyectos, barajas y tarjetas.** Organiza lo que estudias (por ejemplo, el proyecto «Inglés B2» con las barajas «Verbos irregulares» y «Phrasal verbs»). Marca favoritos, archiva lo que ya no usas y recupera lo borrado desde la papelera durante 15 días.
- **Dos tipos de tarjeta.** Simples (pregunta y respuesta, se giran con un toque) y de test (de 2 a 6 opciones, con una o varias correctas). Con imágenes, negrita y cursiva.
- **Barajas de idiomas.** Escucha las tarjetas con la voz del sistema, añade una frase de ejemplo y notas, y estudia en sentido inverso.
- **Sesiones de estudio a tu medida.** Elige cuántas tarjetas y de qué barajas, solo las falladas, un temporizador por pregunta o para toda la sesión, y repite al final las que falles. Puedes pausar, ver la respuesta o dejar una tarjeta para el final.
- **Errores y estadísticas.** Una tarjeta fallada entra en tu lista de errores y sale cuando la aciertas dos veces seguidas. Estadísticas por proyecto y globales, racha de días y objetivo diario.
- **Importar y exportar.** Copia de seguridad completa para pasar tus datos a otro dispositivo, comparte un proyecto o una baraja (JSON o CSV) e importa tarjetas desde un CSV. Incluye una plantilla y un prompt para crear tarjetas con una IA (Claude, ChatGPT…).
- **Tema claro y oscuro**, tamaño de letra de las tarjetas ajustable y animaciones que se suavizan si tu sistema pide reducir el movimiento.

La app está en español y funciona en Android, Windows y macOS.

> **macOS:** esta versión aún no se ha probado en un Mac real. Una versión anterior de prueba sí funcionó en un Mac, pero los últimos cambios (entre ellos, guardar ficheros con «Exportar todo» y «Compartir») están sin comprobar. Si algo falla, cuéntanoslo abriendo una *issue* en GitHub.

## Cómo instalar EstudiCards

Descarga el fichero de tu sistema en **Assets**, al final de esta página.

| Sistema | Fichero |
|---|---|
| Android | `EstudiCards-…-android.apk` |
| Windows (instalador) | `EstudiCards-…-windows-setup.exe` |
| Windows (portable, sin instalar) | `EstudiCards-…-windows.zip` |
| macOS | `EstudiCards-…-macos.dmg` |

**Android.** Abre el `.apk` en el móvil. Android avisará de que no permite instalar apps de esa fuente (el navegador o la app de archivos): pulsa «Ajustes», activa «Permitir de esta fuente» y vuelve atrás. Si Play Protect avisa de una «app desconocida», pulsa «Más detalles» → «Instalar de todas formas».

**Windows.** La app aún no está firmada con un certificado de Microsoft:
- El navegador puede avisar de que el fichero «no se descarga habitualmente»: elige «Conservar».
- Al abrirlo, si aparece «Windows protegió su PC», pulsa «Más información» → «Ejecutar de todas formas».
- El instalador no pide permisos de administrador. La versión portable se descomprime en cualquier carpeta y se abre con `estudicards.exe`.
- La primera vez, la app te pide una carpeta para tus datos (propone `Documentos\EstudiCards`). Si OneDrive sincroniza tu carpeta Documentos, tus datos también se subirán a la nube; si no lo quieres, pulsa «Cambiar carpeta…» y elige una carpeta fuera de Documentos.

**macOS.** La app aún no está firmada por Apple:
1. Abre el `.dmg` y arrastra la app a «Aplicaciones».
2. Ábrela una vez; macOS dirá que no puede comprobar que no tenga software malicioso. Pulsa «Aceptar».
3. Ve a Ajustes del Sistema → Privacidad y seguridad, baja hasta «Seguridad» y pulsa «Abrir igualmente». Confirma con tu contraseña.

Tus datos no se borran al actualizar ni al desinstalar en Windows (están en la carpeta que elegiste). Haz una copia de seguridad desde Ajustes antes de cambiar de dispositivo.

## Comprobar que la descarga es la original

Descárgala siempre desde esta página. Si la consigues en otro sitio, puedes comprobar que es idéntica a la publicada aquí:

- **Checksum.** Descarga también `SHA256SUMS.txt` en la misma carpeta y ejecuta `sha256sum -c SHA256SUMS.txt --ignore-missing` (Linux, macOS o Git Bash). Debe decir `OK` junto al fichero. En PowerShell, `Get-FileHash <fichero>` debe dar el mismo valor que su línea en `SHA256SUMS.txt`.
- **Procedencia.** Con la [CLI de GitHub](https://cli.github.com/), `gh attestation verify <fichero> --repo ivanalonsoe/EstudiCards` confirma que lo construyó el workflow de este repositorio a partir de esta versión.
