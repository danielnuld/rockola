## Context

Prueba hecha en casa antes de escribir esto (script en el scratchpad, mismo cálculo):
- ffmpeg decodifica a mono 22 050 Hz, FFT de 2048 con ventana de Hann cada 50 ms, 16
  bandas logarítmicas de 40 Hz a 11 kHz, dB, y cada banda normalizada entre su 5 % y
  su 99.5 % dentro de la canción → un byte.
- Reptilia (flac, 3:41): 0.4 s decodificar + 0.4 s FFT, 4433 cuadros, 69 KB (92 KB en
  JSON base64). La Pelotona: igual. Toda la biblioteca (776): ~10 min, ~54 MB.
- Pintadas como imagen, se ven la batería de *Reptilia* (rayas regulares), su riff en
  medios, la entrada de la banda a los 13 s, y el beat de *La Pelotona* a los 11.5 s.
- Las dos se mueven (desviación ~60 de 255 por banda): las barras no se quedan quietas.
- En casa: ffmpeg 8, Python 3.14 sin numpy (se instala `python3-numpy` por apt, lo
  único que no pide contraseña), puerto 8788 libre, 22 GB libres.

## Goals / Non-Goals

**Goals:** visualizaciones que reaccionan a la música en web e iPhone, también sin red.

**Non-Goals:** análisis en tiempo real, más de cuatro estilos, visualizador fuera del reproductor.

## Decisions

**Servicio propio, decidido por Daniel.** `servidor/huellas.py` en el repo de Rockola:
`http.server` de la stdlib con hilos (una huella nueva tarda ~1 s), numpy y ffmpeg.
Pregunta a Jellyfin la ruta del archivo (`Items/{id}?Fields=Path`) con su clave; la
biblioteca está en la misma ruta dentro y fuera del contenedor, así que ffmpeg la lee
directo. Configuración por variables (`JELLYFIN_URL`, `JELLYFIN_API_KEY`,
`HUELLAS_DIR`, `HUELLAS_TAILSCALE`, `HUELLAS_ORIGENES`), leídas del `.env` de
`/srv/stack` para no duplicar la clave. Asserts en `--check` con un tono generado, como
en Giulia.

**Toda la biblioteca de una vez, decidido por Daniel**: `--todas` recorre las canciones
de Jellyfin y calcula las que falten; lo nuevo se calcula al pedirlo.

**Caché en `/srv/data/huellas/<id>.json`.** Se puede rehacer con `--todas`, así que
queda fuera del respaldo, como la caché de Jellyfin.

**`python3-numpy` del sistema**, no un venv: el servicio no tiene más dependencias y
apt es lo que se puede instalar sin contraseña.

**La app interpola entre cuadros.** `cuadroEn(huella, posicion)` (puro, con prueba)
mezcla los dos cuadros vecinos: a 60 fps la animación no salta cada 50 ms. La posición
sale de `playbackState.value.position`, que ya extrapola con el reloj; con la música en
pausa no avanza y la visualización se queda quieta.

**Un `Ticker` y cuatro `CustomPainter`.** Sin paquetes. Cada estilo recibe las 16
bandas (0–1) y el tiempo; los que tienen estado (picos que caen en Barras, ondas vivas
en Ondas, chispas en Batería) lo guardan en el painter y se reinician al cambiar de
estilo. Los "golpes de graves" se detectan con una función pura: la media de las 3
bandas bajas sube más de un umbral respecto a su media reciente.

**Sin huella, un patrón sintético** de senos lentos por banda: el mismo painter, sin
errores en pantalla.

**Estilo recordado en `SharedPreferences`**, como el servidor del locutor.

**La huella viaja con la descarga**: `Descargas` baja `<id>.huella.json` después del
audio si hay servidor de huellas; un fallo ahí no marca la canción.

## Risks / Trade-offs

- [Instalar el servicio de systemd pide sudo, y crear reglas persistentes quedó
  bloqueado por los permisos de la sesión] → Se deja la unidad y el comando listos;
  si hace falta, Daniel lo corre con `!`.
- [La huella de otra versión del archivo (si se reemplaza el archivo) queda vieja] →
  Se guarda con el tamaño del archivo; si cambia, se recalcula.
- [60 fps de CustomPainter en un iPhone] → Son 16 valores por fotograma; si pesa, se
  baja a 30 fps.
