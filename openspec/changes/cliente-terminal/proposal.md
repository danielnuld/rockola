## Why

Daniel quiere Rockola en la terminal, para un PC donde Chrome con la versión web pesa
demasiado, y con el visualizador también ahí, aunque sea en ASCII. Eso descarta usar
jellyfin-tui o jftui tal cual: no saben de huellas ni de la locutora, y para visualizar
lo que suena tiene que sonar por nuestro cliente. La prueba salió bien en este PC:
mpv controlado por su tubería desde Dart contesta la posición en 0.5 ms, y el cliente
compilado gasta 0.2 % de un núcleo y 18 MB (mpv, 1.6 % y 73 MB). Issue #7.

## What Changes

- **`rockola.exe`**, un cliente de terminal en el mismo repo, que reutiliza el código
  puro de la app (Jellyfin, letras, mezclas, radio, huellas).
- **Elegir qué suena con comandos** en vez de una biblioteca navegable:
  `rockola <búsqueda>`, `rockola mezclas` y `rockola radio`.
- **Una pantalla "Suena"** con la canción, el progreso, la letra y el visualizador,
  manejada con teclas: pausa, siguiente, anterior, adelantar, cambiar de estilo y salir.
- **Visualizador de barras** con bloques Unicode y el degradado coral-ámbar en color;
  con `--ascii`, solo caracteres ASCII y sin color, para consolas viejas. Sin huella,
  el mismo patrón sintético que la app.
- **La radio con locutora** por el servidor del locutor, como la web.
- **Las escuchas cuentan** en Jellyfin, como en la app.
- La app se reorganiza un poco para separar lo puro de los widgets (sin cambios de
  comportamiento).

## Capabilities

### New Capabilities
- `terminal`: el cliente de terminal: sesión, comandos, pantalla "Suena", teclas,
  visualizador en texto y radio.

### Modified Capabilities
(ninguna: la reorganización no cambia requisitos)

## Impact

- Nuevos `bin/rockola.dart` y `lib/terminal/`. Se compila con `dart build cli`:
  `dart compile exe` rechaza el proyecto por los build hooks de `objective_c`
  (dependencia de iOS). Probado: `dart build cli` compila en 4 s.
- La lógica pura sale a sus propios archivos, siguiendo el patrón
  `descargas.dart` / `descargas_pantalla.dart`: `mezclas.dart` queda puro y sus
  widgets pasan a `mezclas_pantalla.dart`; `Locutor` y `horaDeRadio` a `locutor.dart`;
  `Huella`, `cuadroEn`, `golpe` y `sintetico` a `huella.dart`.
- `Locutor.entrada` deja de recibir `MediaItem` (de audio_service, que arrastra
  Flutter) y recibe un registro con los datos de la canción.
- Necesita mpv instalado (`winget install shinchiro.mpv`). Ya está en este PC.
- Sin dependencias nuevas de Dart.

## Fuera de alcance

- Navegar la biblioteca por pantallas (artistas, álbumes, listas): primero los comandos.
- Descargas y modo sin conexión.
- Los estilos Ambiente, Batería y Ondas en texto: primero las barras.
- Linux y macOS: mpv usa ahí un socket Unix en vez de tubería. Se añade si hace falta.
- Instalador: el `.exe` se copia a mano.
