## Why

Al reproductor le faltan las letras, una de las dos cosas que Daniel echó en falta al
usarlo. Jellyfin ya las sirve, y muchas vienen sincronizadas por tiempo, así que se
puede resaltar la línea que suena como en Spotify o Apple Music. Issue #9.

## What Changes

- **De dónde salen**: de Jellyfin si la tiene (80 de 776 canciones); si no, Rockola
  le pregunta directamente a **lrclib.net** (gratis, sin clave, con CORS abierto). El
  plugin LrcLib de Jellyfin se instaló primero y no encontró ninguna (ver design.md).
- **Letra en el Reproductor**: botón "Letra" en toda canción de la biblioteca, que
  cambia la portada por la letra; con ventana ancha, portada y letra lado a lado.
- **Sincronizada**: la línea que suena resaltada y centrada sola; tocar una línea salta
  a ese momento.
- **Sin tiempos**: la letra entera, sin resaltar.
- **Sin conexión**: la letra (de Jellyfin o de lrclib) se guarda con la descarga
  (álbum o lista) y se lee de ahí.

## Capabilities

### New Capabilities
- `letras`: dónde y cómo se ven las letras, sincronizadas o no, con y sin conexión.

### Modified Capabilities

## Impact

- `lib/jellyfin.dart`: `letra(id)` sobre `/Audio/{id}/Lyrics`.
- Nuevo `lib/lrclib.dart`: búsqueda exacta y amplia, elección del candidato y LRC.
- Nuevo `lib/letras.dart` (vista de letra); `lib/reproductor.dart` gana el modo letra.
- `lib/descargas.dart`: baja la letra junto a cada canción.
- `cancion()` lleva `HasLyrics` en `extras`.
- Sin dependencias nuevas.

## Fuera de alcance

- Editar o corregir letras desde la app.
- Traducir letras.
- Letra en el mini reproductor o en la pantalla de bloqueo.
- Guardar las letras junto a los archivos de música: la biblioteca está montada en solo
  lectura para Jellyfin, y se quedan en sus metadatos.
