## Context

Tras la fase 1: `Armazon` con cuatro `Navigator`, `MiniPlayer` y `BarraAncha` leyendo
del `AudioHandler` global `player`, `Biblioteca` (cuadrícula provisional) y `AlbumPage`
(lista pelada) en `lib/biblioteca.dart`, `Portada` con reemplazo de color. El plano son
los artboards **iPhone · Biblioteca**, **iPhone · Álbum** y **iPhone · Reproductor**.

Probado contra el Jellyfin de casa antes de escribir esto:
- `/Users/{id}/Items?searchTerm=strokes` **no encuentra nada**: solo compara con el nombre
  de canciones y álbumes, nunca con el artista.
- `/Search/Hints?searchTerm=…&includeItemTypes=Audio,MusicAlbum,MusicArtist` sí:
  "strokes" da el artista, "cartel" el artista y dos canciones, "rumours" el álbum.
- `/Artists/AlbumArtists` devuelve los artistas pero con `TotalRecordCount: 0`.
- `ChildCount` de un álbum no es de fiar: Angles dice 2.
- `Items?AlbumArtistIds=<id>&IncludeItemTypes=MusicAlbum` da los siete de The Strokes.

## Goals / Non-Goals

**Goals:** las tres pantallas del lienzo y la búsqueda, sobre el armazón que ya existe.

**Non-Goals:** descargas, mezclas y radio (fases 3–6); fondo del reproductor teñido
por la portada.

## Decisions

**Búsqueda por `/Search/Hints`, no por `/Items?searchTerm`.** Es la que encuentra
artistas (ver Context). Una sola consulta para los tres grupos.

**Retardo de 300 ms con un `Timer` en el `State`.** `rxdart` está en el árbol solo
porque lo trae `audio_service`; importar una dependencia transitiva para un
`debounce` es atarse a algo que no se declaró. Un `Timer` que se cancela en cada
tecla son cuatro líneas.

**Canciones y minutos del álbum se cuentan de la lista de canciones**, que ya se pide
para pintarla; `ChildCount` miente. La línea de cabecera sale de una función pura
`lineaAlbum(año, canciones, duración)` con su prueba.

**El orden "Escuchados hace poco" reutiliza `recientes()` de la fase 1.** Una función
pura `porRecientes(items, idsRecientes)`: primero los que están en el historial, en
ese orden, luego el resto por nombre. Para álbumes, los ids son `AlbumId` del
historial; para artistas, el `AlbumArtist` de cada canción comparado por nombre (las
canciones no traen el id del artista de álbum).

**Una sola función `cancion(jf, item)` hace el `MediaItem`**, para Álbum y Búsqueda.
Lleva en `extras` el id de Jellyfin de la canción (`itemId`) y el del álbum
(`albumId`): el `id` del `MediaItem` es la URL de stream, y el favorito y la
portada de reemplazo necesitan los ids reales. La canción que suena se reconoce
comparando `itemId`.

**Aleatorio y repetir, al `Player`.** `setShuffleMode` y `setRepeatMode` de
audio_service pasan a `setShuffleModeEnabled`/`shuffle()` y `LoopMode` de just_audio,
y `_state` los devuelve en el `PlaybackState`. El ciclo de repetir (nada → todo →
una → nada) es una función pura con prueba.

**El Reproductor va en el `Navigator` raíz** (`rootNavigator: true`), así tapa pestañas
y lateral igual en teléfono que en web, y cerrar vuelve a donde se estaba. La cola es
una hoja inferior (`showModalBottomSheet`) con la lista de `player.queue`.

**Favoritos optimistas.** El corazón cambia al tocarlo, se llama a
`POST`/`DELETE /Users/{userId}/FavoriteItems/{id}`, y si falla vuelve atrás con un
`SnackBar`. El estado inicial sale de `UserData.IsFavorite` del propio item.

**Progreso arrastrable con `Slider` y valor local mientras se arrastra**, y `seek` al
soltar (`onChangeEnd`); si se hiciera `seek` en cada movimiento, el audio tartamudea.

## Risks / Trade-offs

- [El orden de artistas compara por nombre] → Dos artistas con el mismo nombre se
  confundirían; en una biblioteca personal no pasa.
- [`/Search/Hints` es una API antigua de Jellyfin] → Es la que usa su propio cliente
  web para la búsqueda rápida; si desaparece, el fallo se ve en el test contra el
  servidor falso y en la primera búsqueda real.
- [La hoja de la cola lista toda la cola] → Con álbumes y búsquedas son decenas de
  canciones; si algún día son miles (radio), se pagina ahí.
