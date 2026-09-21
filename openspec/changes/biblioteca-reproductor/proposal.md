## Why

La fase 1 dejó la navegación y el Inicio, pero lo que se usa todos los días (entrar a
la biblioteca, abrir un disco, ver qué suena y buscar algo) sigue siendo la cuadrícula
provisional y una lista pelada. Sin esto la app no sustituye a Finamp. Issue #2.

## What Changes

- **Biblioteca** como en el artboard **iPhone · Biblioteca**: lista con filtros Álbumes
  y Artistas, orden "Escuchados hace poco" o "A–Z", portada de 56 px y artista debajo.
- **Artista**: sus álbumes, del más reciente al más antiguo.
- **Álbum** como en **iPhone · Álbum**: portada grande, año, número de canciones y
  duración, favorito, aleatorio, reproducir y lista con la canción que suena en coral.
- **Reproductor** a pantalla completa como en **iPhone · Reproductor**: se abre tocando
  el mini reproductor (o la canción en la barra web), con progreso que se arrastra,
  aleatorio, repetir, favorito y la cola.
- **Buscar**: la pestaña deja de estar vacía; busca artistas, álbumes y canciones en
  Jellyfin mientras se escribe.
- En la web, la barra del reproductor gana aleatorio, repetir y el acceso a la cola.

## Capabilities

### New Capabilities
- `biblioteca`: lista de álbumes y artistas, filtros, orden y página de artista.
- `album`: la página de un álbum y cómo se reproduce desde ella.
- `reproductor`: pantalla completa, controles, favoritos y cola.
- `busqueda`: búsqueda en Jellyfin desde la pestaña Buscar.

### Modified Capabilities
- `navegacion`: Buscar deja de ser una pestaña vacía; solo Radio lo sigue siendo.

## Impact

- `lib/biblioteca.dart` se rehace; nuevos `lib/reproductor.dart` y `lib/buscar.dart`.
- `lib/jellyfin.dart`: artistas, álbumes de un artista, búsqueda, favoritos.
- `lib/player.dart`: aleatorio y repetir (just_audio los tiene; faltaba pasarlos).
- Ninguna dependencia nueva.

## Fuera de alcance

- Filtros **Mezclas** y **Descargado** de la Biblioteca y el botón de descarga del
  Álbum: fases 4 y 3. Los chips de filtro de Inicio llegan con la fase 3.
- La insignia "En el iPhone · AAC 160 kbps" del Reproductor: fase 3.
- Fondo del Reproductor teñido con el color de la portada: queda el tono fijo del
  lienzo. Sacarlo de la imagen pide una dependencia que no paga todavía.
- Listas de reproducción de Jellyfin: no están en el lienzo.
- Letras de canciones.
