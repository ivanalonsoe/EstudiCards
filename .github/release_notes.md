## Cómo instalar EstudiCards

Descarga el fichero de tu sistema en **Assets**, al final de esta página. La app funciona sin conexión y sin cuenta.

| Sistema | Fichero |
|---|---|
| Android | `EstudiCards-…-android.apk` |
| Windows (instalador) | `EstudiCards-…-windows-setup.exe` |
| Windows (portable, sin instalar) | `EstudiCards-…-windows.zip` |
| macOS | `EstudiCards-…-macos.dmg` |

**Android.** Abre el `.apk` en el móvil y permite instalar apps de esa fuente cuando Android lo pida. Si Play Protect avisa de una «app desconocida», pulsa «Más detalles» → «Instalar de todas formas».

**Windows.** La app aún no está firmada con un certificado de Microsoft:
- El navegador puede avisar de que el fichero «no se descarga habitualmente»: elige «Conservar».
- Al abrirlo, si aparece «Windows protegió su PC», pulsa «Más información» → «Ejecutar de todas formas».
- El instalador no pide permisos de administrador. La versión portable se descomprime en cualquier carpeta y se abre con `estudicards.exe`.

**macOS.** La app aún no está firmada por Apple:
1. Abre el `.dmg` y arrastra la app a «Aplicaciones».
2. Ábrela una vez; macOS dirá que no puede comprobarla.
3. Ve a Ajustes del Sistema → Privacidad y seguridad y pulsa «Abrir igualmente».

Tus datos no se borran al actualizar ni al desinstalar en Windows (están en la carpeta que elegiste). Haz una copia de seguridad desde Ajustes antes de cambiar de dispositivo.

## Comprobar que la descarga es la original

Descárgala siempre desde esta página. Si la consigues en otro sitio, puedes comprobar que es idéntica a la publicada aquí:

- **Checksum.** Descarga también `SHA256SUMS.txt` en la misma carpeta y ejecuta `sha256sum -c SHA256SUMS.txt --ignore-missing` (Linux, macOS o Git Bash). Debe decir `OK` junto al fichero. En PowerShell, `Get-FileHash <fichero>` debe dar el mismo valor que su línea en `SHA256SUMS.txt`.
- **Procedencia.** Con la [CLI de GitHub](https://cli.github.com/), `gh attestation verify <fichero> --repo ivanalonsoe/EstudiCards` confirma que lo construyó el workflow de este repositorio a partir de esta versión.
