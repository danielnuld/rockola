## Context

Probado contra el Jellyfin 10.11.11 de casa con una lista de usar y tirar (borrada):
- `POST /Playlists` (`Name`, `Ids`, `UserId`, `MediaType: Audio`) crea: 200 con el `Id`.
- `POST /Playlists/{id}/Items?ids=…` añade: 204.
- `GET /Playlists/{id}/Items?userId=…` da las canciones, cada una con su
  `PlaylistItemId` (la entrada en la lista, no la canción).
- `DELETE /Playlists/{id}/Items?entryIds=…` quita: 204. `DELETE /Items/{id}` borra: 204.
- `POST /Playlists/{id}/Items/{entrada}/Move/{i}` y `POST /Playlists/{id}` (renombrar)
  dan 400 con la clave del servidor: el registro dice `Guid can't be empty (Parameter
  'id')`, el usuario de la petición. Es lo mismo que pasó con los avisos de
  reproducción: con la sesión de un usuario deberían funcionar. Tarea 5.2 lo comprueba.
- Las listas de un usuario: `Users/{u}/Items?IncludeItemTypes=Playlist&Recursive=true`,
  con `ChildCount` y `RunTimeTicks`.

## Goals / Non-Goals

**Goals:** listas propias en web e iPhone, compartidas con los demás clientes de Jellyfin.

**Non-Goals:** listas públicas, inteligentes, importadas o en carpetas.

## Decisions

**Las listas son las de Jellyfin.** Guardarlas en el equipo sería reinventar lo que el
servidor ya hace y dejarlas atrapadas en un solo cliente.

**Quitar y mover por `PlaylistItemId`, no por el id de la canción.** Una canción puede
estar dos veces en la lista; la entrada identifica cuál.

**Cambios optimistas con vuelta atrás**, como el favorito: la página cambia al
instante y, si Jellyfin responde con error, vuelve a la copia anterior y avisa.
Reordenar con `ReorderableListView` de Flutter.

**Un solo menú por canción** (`MenuCancion`: "Añadir a una lista" y, dentro de una
lista, "Quitar de la lista") que usan álbum, búsqueda, mezcla, lista y reproductor.
La hoja de añadir pide las listas al abrirse, así nunca muestra una vieja.

**Descargar una lista reutiliza el gestor de álbumes.** `Descargas.pedir` ya recibe
un item y sus canciones; con la lista como item, el índice, el botón, la portada y la
caída sin conexión funcionan igual. La página de lista cae al índice sin red, como
`AlbumPage`.

**Portada de la lista**: la que genera Jellyfin (un mosaico de sus discos); sin ella,
el bloque de color de siempre.

## Risks / Trade-offs

- [Mover y renombrar sin probar con sesión de usuario] → Tarea 5.2 con la sesión de
  Daniel en Chrome antes de cerrar; si fallan, se investiga ahí.
- [Una lista descargada y luego editada queda desfasada en el teléfono] → Se nota en
  el botón (vuelve a "descargar" si cambian sus canciones); volver a descargar la pone
  al día.
