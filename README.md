# Rockola

Un reproductor de música para tu servidor [Jellyfin](https://jellyfin.org): en el
iPhone, en Windows, en el navegador y en la terminal. Mezclas del día hechas con lo que escuchas,
una radio con locutora que presenta las canciones, letras sincronizadas y un
visualizador a la manera del Windows Media Player de XP.

**[Ver la página, con capturas y video](https://danielnuld.github.io/rockola/)** ·
**[Descargar](../../releases/latest)**

## Qué hace

| | iPhone | Windows | Web | Terminal |
|---|:---:|:---:|:---:|:---:|
| Biblioteca, álbumes, artistas y búsqueda | ✓ | ✓ | ✓ | ✓ |
| Mezclas del día | ✓ | ✓ | ✓ | ✓ |
| Listas de Jellyfin (crear, añadir, reordenar) | ✓ | ✓ | ✓ | solo tocar |
| Radio con locutora | pronto | ✓ | ✓ | ✓ |
| Letras sincronizadas | ✓ | ✓ | ✓ | ✓ |
| Visualizador | ✓ | ✓ | ✓ | en texto |
| Descargas comprimidas y modo sin conexión | ✓ | ✓ | | |
| Escuchas contadas en Jellyfin | ✓ | ✓ | ✓ | ✓ |

- **Mezclas del día.** Salen de los géneros, las décadas y los artistas de tu
  biblioteca, y se inclinan hacia lo que más escuchas. Las mismas en todo el día; al
  siguiente, otras.
- **Radio con locutora.** Una hora de radio de las mezclas, con una voz que presenta
  cada pocas canciones y a veces cuenta un dato de la canción o del artista. La voz la
  pone un *servidor del locutor* que tú eliges (ver abajo). Sin él, la radio suena solo
  con música.
- **Letras.** Las de Jellyfin si las tiene y, si no, las de [lrclib.net](https://lrclib.net).
  La línea que suena se resalta y, en la app, tocar una salta a ese momento.
- **Visualizador.** Cuatro estilos (Barras, Ambiente, Batería y Ondas) que siguen la
  música gracias a una *huella* de cada canción, calculada una vez en tu servidor (ver
  abajo). Sin ella, se mueve a su aire.
- **Descargas** (iPhone). Comprimidas por Jellyfin a la calidad que elijas (hasta ~4
  veces menos espacio), con su portada, su letra y su huella: todo funciona en modo avión.

## Qué hace falta

- Un servidor **Jellyfin** con tu música, y tu usuario y contraseña. Para la web,
  Jellyfin tiene que aceptar peticiones del origen donde la sirvas (CORS).
- Opcional: un **servidor del locutor** para que la radio hable ([contrato](docs/locutor.md)).
- Opcional: el **servidor de huellas** de este repo para que el visualizador siga la
  música ([cómo montarlo](docs/huellas.md)).

## Instalar

### iPhone

Por ahora sin App Store: el IPA de cada [release](../../releases) va sin firmar y se
instala con [Sideloadly](https://sideloadly.io) y tu Apple ID. Con un Apple ID gratuito
la app caduca a los 7 días y hay que volver a instalarla.

### Windows

Descarga `RockolaSetup.exe` de la release y ábrelo. Se instala en tu carpeta de
usuario, sin permisos de administrador, con su acceso en el menú Inicio. No está
firmado, así que Windows avisa la primera vez: «Más información» → «Ejecutar de todas
formas». Es la misma app que la web, en su propia ventana; suena por libmpv.

### Web

Descarga `rockola-web.zip` de la release y sírvelo con cualquier servidor de archivos
estáticos. Entra con la dirección de tu Jellyfin, tu usuario y tu contraseña. El
servidor del locutor y el de huellas se ponen en Ajustes.

### Terminal (Windows)

Para equipos donde el navegador pesa demasiado. Necesita [mpv](https://mpv.io):

```sh
winget install shinchiro.mpv
```

Descarga `rockola-terminal-windows.zip`, descomprímelo y renombra
`rockola.ejemplo.json` a `rockola.json` con tus datos:

```json
{
  "url": "http://tu-servidor:8096",
  "usuario": "tu-usuario",
  "huellas": "http://tu-servidor:8788",
  "locutor": "http://tu-servidor:8787"
}
```

`huellas` y `locutor` son opcionales. La primera vez te pide la contraseña y guarda
solo el token de sesión. Luego:

```sh
rockola               # la interfaz
rockola reptilia      # la interfaz, buscando
rockola radio         # la interfaz, sintonizando la radio
```

Todas las teclas, y cómo dejar la configuración en `%APPDATA%`, en
[docs/terminal.md](docs/terminal.md).

## Servidores opcionales

**Servidor del locutor.** Rockola no genera la voz de la radio: se la pide a un
servicio HTTP con dos rutas, `GET /locutor` (su nombre) y `POST /locutor` (el texto y
el audio de la entrada entre dos canciones). Así ninguna clave de API vive en la app y
cada quien usa el modelo y la voz que quiera. El contrato está en
[docs/locutor.md](docs/locutor.md).

**Servidor de huellas.** `servidor/huellas.py` (Python, numpy y ffmpeg) analiza cada
canción una vez (16 bandas de frecuencia, 20 veces por segundo, ~70 KB por canción) y
las sirve en `GET /huella/{id}`. Corre en la máquina de Jellyfin, porque lee los
archivos de audio directamente. Instalación y contrato en [docs/huellas.md](docs/huellas.md).

## Desarrollo

Flutter 3.47 (Dart 3.13). Se desarrolla sin Mac: la interfaz se prueba en el navegador
y el IPA sale de GitHub Actions.

```sh
flutter run -d web-server --web-port 5000     # la app, en http://localhost:5000
flutter analyze && flutter test               # antes de cada commit
dart build cli -t bin/rockola.dart -o build/cli   # la terminal
flutter build windows --release               # la app de escritorio
gh workflow run ios.yml                       # el IPA sin firmar, como artefacto
gh workflow run windows.yml -f version=X.Y.Z   # el instalador de Windows
```

- `lib/`: la app. `jellyfin.dart`, `mezclas.dart`, `locutor.dart`, `huella.dart` y
  `lrclib.dart` son Dart puro y los comparte la terminal.
- `lib/terminal/` y `bin/rockola.dart`: el cliente de terminal (mpv por su tubería de
  comandos).
- `servidor/`: el servidor de huellas y su unidad de systemd.
- `openspec/`: el plan. Cada fase es un cambio con propuesta, diseño, especificación y
  tareas; las especificaciones vigentes están en `openspec/specs/`.
- `test/falso.dart`: un Jellyfin de mentira que comparten los tests.

## Pendiente

- Probar las descargas y el modo sin conexión en un iPhone de verdad: están
  programadas y con tests, pero no se han usado en el teléfono.
- La locutora en el iPhone, sin servidor: el texto con Foundation Models de Apple y
  la voz con Piper, todo en el teléfono.
- CarPlay, cuando haya cuenta de Apple Developer.
