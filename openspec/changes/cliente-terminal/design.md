## Context

Prueba hecha en este PC (i7-1165G7, Windows 11, Windows Terminal) antes de escribir
esto, con un script de Dart y mpv 0.41 (`winget install shinchiro.mpv`):

- mpv arranca con `--no-video --input-ipc-server=\\.\pipe\rockola-<pid>` y crea la
  tubería en ~0.3 s.
- **Dart no abre `\\.\pipe\...`**: lo toma por ruta de red (errno 53). Abriendo
  `\\?\pipe\...` con `File.open(mode: FileMode.append)` llega a la misma tubería y mpv
  contesta.
- Petición y respuesta, sin lecturas pendientes a la vez: `get_property time-pos` a
  20 Hz, 323 peticiones con 0.45 ms de mediana y 3.1 ms de máximo.
- Compilado: el cliente 0.2 % de un núcleo y 18 MB; mpv 1.6 % y 73 MB (con
  `--ao=null`; con audio de verdad, algo más).
- Las barras con `▁▂▃▄▅▆▇█` y color de 24 bits se ven bien en Windows Terminal a 20 fps.
- `dart compile exe` falla en el repo por los build hooks de `objective_c`;
  `dart build cli -t bin/…` compila y el `.exe` corre.

## Goals / Non-Goals

**Goals:** escuchar desde la terminal lo mismo que en la web (búsqueda, mezclas,
radio con locutora) con visualizador y letra, gastando poco.

**Non-Goals:** una biblioteca navegable, descargas, más de un estilo, Linux.

## Decisions

**Mismo repo, `bin/rockola.dart` + `lib/terminal/`.** Lo puro ya existe en `lib/`:
`jellyfin.dart` y `lrclib.dart` compilan sin Flutter tal cual. Lo que está mezclado con
widgets se separa sin cambiarlo, con el patrón que ya hay (`descargas.dart` /
`descargas_pantalla.dart`):
- `mezclas.dart` queda con `Mezcla`, `familia`, `mezclas`, `artistasDe`; los widgets
  van a `mezclas_pantalla.dart`.
- `locutor.dart`: `Locutor` y `horaDeRadio`. `entrada` recibe
  `({String titulo, String? artista, String? album, int? anio, int? escuchas})`; la
  web lo arma desde el `MediaItem` en `SesionRadio`.
- `huella.dart`: `Huella`, `cuadroEn`, `golpe`, `sintetico`.

Un test de la CLI importa solo esos archivos: si alguno vuelve a arrastrar Flutter,
`dart build cli` falla y se nota.

**mpv como proceso, por su tubería JSON.** `just_audio` no funciona fuera de Flutter.
Ya decidido en el issue. Rockola maneja la cola: le pasa a mpv la lista
(`loadfile … append`) y las entradas de la locutora con `loadfile … insert-at`. Cada
tic de 50 ms pide `time-pos`, `playlist-pos` y `pause` (tres peticiones, ~1.5 ms). Solo
petición-respuesta: en una tubería sin "overlapped", una lectura pendiente bloquea la
escritura.

**mpv se busca** en el PATH y, si no, en `C:\Program Files\MPV Player\mpv.exe` (donde lo
deja winget, que no lo pone en el PATH de las sesiones abiertas). Sin mpv, un mensaje
con el comando para instalarlo.

**Stream original** (`jf.stream`): la CLI va por la red de casa o Tailscale, no por
datos móviles.

**Voz de la locutora a un archivo temporal.** `entrada` devuelve un `data:` URI; se
escribe como `.ogg` en la carpeta temporal y se borra al salir.

**Configuración en un JSON escrito a mano, decidido por Daniel**: `rockola.json` junto
al `.exe` (para llevarlo en una memoria) o, si no hay, `%APPDATA%\Rockola\config.json`.
Lleva `url` y `usuario` de Jellyfin y, opcionales, `huellas`, `locutor` y `mpv`. Sin
comandos de configuración: sin token, pide la contraseña sin eco y guarda en el mismo
archivo solo `token` y `usuarioId`. Un 401 de Jellyfin borra el token para pedirla otra vez.

**Pantalla con secuencias ANSI, sin paquetes.** Buffer alterno (`ESC[?1049h`), cursor
oculto, y cada cuadro se escribe desde `ESC[H` de una vez (sin borrar: no parpadea). Al
salir, incluso con Ctrl+C, se restaura la terminal. Teclas con
`stdin.lineMode = false` y `echoMode = false`; las flechas llegan como secuencias VT.

**Visualizador:** las 16 bandas del cuadro actual (`cuadroEn` con la posición de mpv)
repartidas en el ancho de la terminal, alto de 8 filas con los 8 bloques parciales de
Unicode. Color de 24 bits por fila, de coral abajo a ámbar arriba. `--ascii`:
` .:+#` y sin color. Sin huella, `sintetico`.

**Escuchas** con `jf.empieza` y `jf.termina`, que funcionan con la sesión del usuario
(con la API key del servidor fallaban, pero aquí siempre hay sesión).

**La interfaz, como la web (decidido por Daniel entre esta y una estilo cmus).**
`Reproductor` (mpv, cola, escuchas, huella, letra, locutora) no pinta ni lee teclas;
`Interfaz` encima tiene una pila de páginas por sección. Cada página es una lista de
filas `(texto, detalle, accion)`; las que cargan de Jellyfin guardan lo cargado y las
vivas (Cola, Radio) se recalculan en cada cuadro. Sin paquetes de TUI: `pintarInterfaz`
es una función que devuelve la pantalla como texto, cada línea en su fila con
`ESC[fila;1H` (sin saltos de línea que desplacen la pantalla) y del ancho exacto de la
terminal, que se lee en cada cuadro (redimensionar funciona solo). Se repinta a 20 fps
con el tic y en cada tecla. En ASCII, los símbolos de la interfaz se cambian uno por
uno (mismo ancho) y los acentos de los nombres se quedan.

**Vigía dentro de mpv.** En Windows mpv no muere con quien lo lanzó: cerrar la
ventana dejaba la música sonando. Un script Lua de 5 líneas que se le pasa con
`--script` lo cierra si pasan 5 s sin `script-message rockola-vivo`, que Rockola manda
en cada tic. Medido: mpv sale 6.1 s después de matar `rockola.exe`. Cubre cerrar la
ventana, matar el proceso y que se caiga, sin tocar la API de Windows.

## Risks / Trade-offs

- [La consola clásica de Windows (conhost) sin VT] → Windows 10+ la activa; si algo se
  ve mal, `--ascii`.
- [mpv se cae o lo cierran] → el tic detecta la tubería rota y la CLI sale con un
  mensaje, no se queda colgada.
- [Que una búsqueda no encuentre lo que se quiere] → se muestran canciones, álbumes y
  artistas numerados; elegir uno con su número.
