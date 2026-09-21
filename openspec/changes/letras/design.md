## Context

Medido en el Jellyfin 10.11.11 de `nuld`:
- `GET /Audio/{id}/Lyrics` → `{"Metadata": {}, "Lyrics": [{"Text", "Start"?}]}`; `Start`
  en ticks (100 ns). 404 si no hay letra.
- Hay letras sincronizadas ("Blah, blah, blah…" de Cartel de Santa: 68 líneas con
  `Start`) y planas (*Highway to Hell*: sin `Start`).
- Cada canción trae `HasLyrics` sin pedir campos extra.
- Antes del cambio: 80 de 768 canciones con letra y ningún proveedor instalado. El
  catálogo oficial tiene **LrcLib Lyrics** 3.0 para 10.11, y Jellyfin trae la tarea
  "Descargar letras que faltan" (`DownloadLyrics`).

## Goals / Non-Goals

**Goals:** letras en el reproductor, resaltadas cuando se puede, también sin red.

**Non-Goals:** editar, traducir, letra fuera del reproductor.

## Decisions

**El proveedor es un plugin de Jellyfin, no código de Rockola.** Instalado LrcLib y
lanzada `DownloadLyrics`: las letras llegan a la API que ya existe y a cualquier otro
cliente de Jellyfin. La biblioteca está montada en solo lectura para el contenedor,
así que `SaveLyricsWithMedia` se queda apagado y las letras viven en los metadatos de
Jellyfin (en `/srv/config/jellyfin`, que ya se respalda).

**Una línea actual pura**: `lineaActual(inicios, posicion)` es la última cuyo inicio
es ≤ la posición (búsqueda lineal: son decenas de líneas), -1 antes de la primera. Con
prueba.

**La posición sale de `avance()`**, el mismo flujo de medio segundo del progreso: no se
abre otro temporizador.

**Centrar la línea con `Scrollable.ensureVisible`** sobre una `GlobalKey` por línea,
con `alignment: 0.4`, solo cuando cambia la línea actual (no en cada tic), y sin
animar si el usuario está arrastrando la lista.

**La letra se pide al abrirla, con caché por canción en la sesión**: no se pide para
cada canción que suena, solo para las que se miran.

**Sin red, la de la descarga.** `Descargas` baja `<id>.letra.json` (la respuesta tal
cual) después del audio si la canción tiene `HasLyrics`; un 404 o un fallo ahí no
marca la canción como fallida. `letra()` en la vista: Jellyfin primero y, si falla, el
archivo guardado.

## Risks / Trade-offs

- [LrcLib no tiene todo, sobre todo rap mexicano poco conocido] → Se mide la cobertura
  al terminar la tarea (tarea 1.2); lo que falte, sin botón.
- [Una letra sincronizada de otra versión de la canción va desfasada] → Es lo que
  devuelve LrcLib por título, artista, disco y duración; no se corrige en la app.
