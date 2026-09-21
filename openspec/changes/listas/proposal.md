## Why

Rockola reproduce álbumes, búsquedas, mezclas y la radio, pero no deja guardar una
selección propia: no hay listas de reproducción. Es lo primero que Daniel echó en
falta al usar el reproductor. Issue #8.

## What Changes

- **Listas de Jellyfin, no un formato propio.** Se crean, llenan, reordenan y borran
  con `/Playlists`, así que se ven igual en Finamp, en la web de Jellyfin o en
  cualquier otro cliente. Hoy hay 0.
- Filtro **Listas** en la Biblioteca, con "Nueva lista".
- **Página de lista**: portada, nombre, canciones y duración, reproducir, aleatorio,
  reordenar arrastrando, quitar una canción, renombrar y borrar la lista.
- **"Añadir a una lista"** en cada canción (álbum, búsqueda, mezcla, lista y el
  reproductor) y en el álbum entero, con una hoja que ofrece "Nueva lista…" y las
  existentes.
- En el iPhone, **descargar una lista** con el mismo botón y el mismo gestor que un
  álbum.

## Capabilities

### New Capabilities
- `listas`: listas de reproducción, su página y cómo se añaden canciones.

### Modified Capabilities
- `biblioteca`: se añade el filtro Listas.

## Impact

- `lib/jellyfin.dart`: las operaciones de `/Playlists`.
- Nuevo `lib/listas.dart`: página de lista, hoja de "Añadir a una lista" y nueva lista.
- Menú por canción en `AlbumPage`, `Buscar`, `MezclaPage` y el `Reproductor`.
- Ninguna dependencia nueva.

## Fuera de alcance

- Listas compartidas o públicas entre usuarios de Jellyfin.
- Listas inteligentes (reglas automáticas): las mezclas ya cubren eso.
- Importar listas de otros servicios.
- Carpetas de listas.
