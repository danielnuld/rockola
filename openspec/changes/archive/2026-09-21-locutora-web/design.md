## Context

Hay mezclas del día (`_mezclas` en `Armazon`), un `Player` con cola de `AudioSource`,
`Escuchas` que ignora lo que no trae `itemId`, y la ruta `/locutor` de Giulia
(cambio `ruta-radio` en `jarvis-m710q`): `POST` con `antes`, `despues` y `charla`
devuelve `{texto, audio (OGG/Opus en base64), formato}`; `GET` devuelve `{nombre}`.

## Goals / Non-Goals

**Goals:** la radio con locutora en Chrome, sin claves en el navegador y sin que un
fallo del servidor pare la música.

**Non-Goals:** la radio en el iPhone (fase 6), pedirle cosas a la locutora, Safari.

## Decisions

**Contrato propio y documentado, no "la API de Giulia".** `docs/locutor.md` describe
las dos rutas; Giulia es una implementación. Así Rockola se puede publicar y otro
usuario monta su servidor (o no, y hay radio sin locutora).

**La entrada viaja como `data:` URI.** `audio/ogg;base64,…` en un `AudioSource.uri`:
just_audio en la web lo pasa a un `<audio>`, que lo reproduce en Chrome. Evita un
segundo endpoint para servir archivos y cualquier estado en el servidor.

**Insertar a media reproducción con `insertQueueItem`.** audio_service ya trae el
método; el `Player` lo implementa con `AudioPlayer.insertAudioSource`. La cola empieza
solo con música y las entradas se meten cuando llegan: si no llegan, no hay hueco.

**`Radio` es un objeto de sesión, no un widget.** Guarda la cola planeada, la
frecuencia y la última entrada, y escucha `player.playbackState`: al empezar una
canción calcula si la siguiente necesita entrada, la pide, y al recibirla la inserta
justo antes si esa canción todavía no empezó. Se prueba con un `BaseAudioHandler` y
un servidor falso, sin audio real.

**La hora sale de las mezclas por turnos.** Una canción de cada mezcla en orden
circular, saltando repetidas, hasta 16 (~1 h a 3.7 min de media en la biblioteca).
"Cambiar el rumbo" rota el orden de las mezclas una posición. Es una función pura con
prueba.

**Datos de la canción para el servidor desde el `MediaItem`.** Título, artista,
álbum, año y escuchas van en `extras` (se añaden año y escuchas a `cancion()`), así
la radio no vuelve a pedir nada a Jellyfin.

**El servidor, en `SharedPreferences`** (`locutor`), como la sesión. Solo web: en
iOS la pestaña Radio sigue siendo el estado vacío hasta la fase 6, y el iPhone nunca
llama al servidor.

**La locutora en el mini reproductor y la barra**: si el `MediaItem` trae
`extras['locutor']`, se pinta un cuadro ámbar con el icono de radio en vez de portada,
y "<nombre> habla" como título.

## Risks / Trade-offs

- [Una entrada tarda ~5 s y la canción anterior podría durar menos] → Se pide al
  empezar esa canción; con canciones de más de 10 s llega. Si no, se descarta.
- [`insertAudioSource` en just_audio web con la cola sonando] → Es la API pública
  para esto; se comprueba en Chrome (tarea 5.2).
- [OGG/Opus no suena bien en Safari] → Fuera de alcance; el contrato permite otro
  `formato` si algún día hace falta MP3.
