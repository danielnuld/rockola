## Why

Daniel quiere las visualizaciones de Windows Media Player de XP en el reproductor.
Para que reaccionen a la música hay que saber qué suena en cada momento, y ni
just_audio en el navegador ni AVPlayer en el iPhone entregan las muestras de audio.
La prueba del issue #10 salió bien: una **huella** precalculada por canción (16
bandas de frecuencia, 20 veces por segundo) cuesta 0.8 s y 69 KB en `nuld`, y en
ella se ve el ritmo (la batería de *Reptilia*, la entrada del beat de *La Pelotona*).
Issue #10.

## What Changes

- **Servicio de huellas propio**, en el repo de Rockola (`servidor/huellas.py`: stdlib,
  numpy y ffmpeg), corriendo como servicio en `nuld`. No depende de Giulia: cualquiera
  que use Rockola puede montarlo. Contrato en `docs/huellas.md`.
  - `GET /huella/{id}` devuelve la huella de una canción de Jellyfin; si no está
    calculada, la calcula (~1 s) y la guarda.
  - `--todas` calcula la biblioteca entera de una vez (~10 min, ~54 MB).
- **Visualizador a pantalla completa** desde el Reproductor, sincronizado con la
  posición, con cuatro estilos que se cambian tocando: **Barras**, **Ambiente**,
  **Batería** y **Ondas**.
- Sin servidor de huellas, o sin huella para esa canción, una animación suave que no
  reacciona.
- **Ajustes**: "Servidor de huellas" (web e iPhone).
- **Sin conexión**: la huella se guarda con la descarga.

## Capabilities

### New Capabilities
- `huellas`: el servicio que calcula y sirve huellas, y su contrato.
- `visualizador`: la pantalla, los estilos y cómo se sincronizan.

### Modified Capabilities
- `ajustes`: se añade el servidor de huellas.

## Impact

- Nuevo `servidor/huellas.py` + `servidor/huellas.service` (systemd) en el repo.
- En `nuld`: `python3-numpy` por apt, el servicio en el puerto 8788 (127.0.0.1 y
  Tailscale), la caché en `/srv/data/huellas` (se puede rehacer: no va al respaldo).
- Nuevos `lib/visualizador.dart`; `lib/reproductor.dart`, `lib/ajustes.dart` y
  `lib/descargas.dart` se tocan.
- Sin dependencias nuevas en la app.

## Fuera de alcance

- Visualización en tiempo real a partir del audio (sin muestras en just_audio).
- Más estilos o estilos configurables: primero estos cuatro.
- Visualizador en el mini reproductor o en la pantalla de bloqueo.
- Recalcular huellas solas cuando entra música nueva: se calculan al pedirlas.
