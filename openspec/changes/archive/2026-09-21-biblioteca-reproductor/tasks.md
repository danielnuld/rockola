## 1. Cliente de Jellyfin y reproductor

- [x] 1.1 `Jellyfin`: `artistas()` (`/Artists/AlbumArtists`), `albumesDe(artistaId)` (`AlbumArtistIds`, del más reciente), `buscar(texto)` (`/Search/Hints` con los tres tipos), `favorito(id, si)` (`POST`/`DELETE FavoriteItems`); `albums()` y `tracks()` piden `ProductionYear` y `UserData`
- [x] 1.2 `cancion(jf, item)`: el `MediaItem` con `itemId` y `albumId` en `extras`; lo usan Álbum y Búsqueda
- [x] 1.3 `Player`: `setShuffleMode` y `setRepeatMode` hacia just_audio, y los dos modos en `_state`
- [x] 1.4 Funciones puras con test: `porRecientes`, `lineaAlbum` (con y sin año), `siguienteRepeticion`

## 2. Biblioteca y artista

- [x] 2.1 Biblioteca en lista como **iPhone · Biblioteca**: filtros Álbumes y Artistas, fila de orden con el total, filas de 64 px
- [x] 2.2 Orden "Escuchados hace poco" por defecto y "A–Z" al tocarlo
- [x] 2.3 Página de artista con sus álbumes; artistas con portada redonda
- [x] 2.4 Test de widget: cambiar a Artistas, entrar a uno y ver sus álbumes (Jellyfin falso)

## 3. Álbum

- [x] 3.1 Cabecera como **iPhone · Álbum**: portada de 210 px, nombre, artista que lleva a su página, `lineaAlbum`
- [x] 3.2 Fila de acciones: favorito, aleatorio y el botón coral de reproducir
- [x] 3.3 Lista de canciones con la que suena en coral (por `itemId`)
- [x] 3.4 Favorito optimista con vuelta atrás y `SnackBar` si falla; test de widget con un Jellyfin falso que responde 500

## 4. Reproductor

- [x] 4.1 `lib/reproductor.dart` como **iPhone · Reproductor**, en el `Navigator` raíz; lo abren el mini reproductor y la canción de la barra web
- [x] 4.2 Progreso con `Slider` arrastrable, tiempo transcurrido y restante; `seek` al soltar
- [x] 4.3 Aleatorio, anterior, reproducir/pausar, siguiente y repetir, encendidos en coral
- [x] 4.4 Favorito de la canción que suena y hoja de la cola que salta al tocar
- [x] 4.5 Barra web: aleatorio, repetir y botón de la cola

## 5. Buscar

- [x] 5.1 `lib/buscar.dart`: campo con retardo de 300 ms y mínimo dos letras
- [x] 5.2 Resultados en Artistas, Álbumes y Canciones; sin resultados, "Nada con «…» en tu biblioteca"
- [x] 5.3 Artista y álbum abren su página dentro de Buscar; una canción reproduce las del resultado desde ella
- [x] 5.4 Test de widget: teclear "cartel" letra a letra hace una sola consulta y pinta Artistas y Canciones sin Álbumes

## 6. Cierre

- [x] 6.1 `flutter analyze` y `flutter test` en verde
- [x] 6.2 Comprobar en Chrome: biblioteca, artista, álbum, reproductor con cola y búsqueda contra el Jellyfin real
- [x] 6.3 `gh workflow run ios.yml` y que el IPA compile
- [x] 6.4 Si algo del lienzo no funcionó igual en la app, corregir el lienzo
