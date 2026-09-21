## Context

Tras la fase 2: `cancion(jf, item)` hace todos los `MediaItem` con la URL de stream
como `id`; `Player` reproduce con `AudioSource.uri`, que acepta `file://` igual que
`http://`. `AlbumPage` pide item y canciones a Jellyfin sin alternativa si falla.

Medido en el Jellyfin de `nuld`:
- 622 canciones, 39.0 horas, 8.16 GB en original (499 mp3, 123 flac).
- `/Audio/{id}/universal` con `AudioCodec=aac`, `TranscodingContainer=m4a`,
  `TranscodingProtocol=http` y `MaxStreamingBitrate` entrega `audio/mp4`. Reptilia
  (220 s, flac de 28 892 198 bytes): 7 170 578 a 256 k, 4 510 686 a 160 k y 2 737 946
  a 96 k. Las tasas reales quedan a 1–2 % de la nominal, así que duración × tasa
  sirve para estimar.

## Goals / Non-Goals

**Goals:** descargar por álbum en cuatro calidades, que lo descargado suene del
teléfono y que la app sirva en modo avión.

**Non-Goals:** descargas en segundo plano, canciones sueltas, limpieza automática.

## Decisions

**Solo iOS.** En la web no hay a dónde ir sin servidor: si Jellyfin no responde, el
navegador tampoco tiene la app. Guardar audio en IndexedDB sería mucho código para un
caso que no existe. `descargas` es `null` en la web y la interfaz se esconde con eso;
los tests viejos, que no lo inician, se comportan como la web.

**Índice en un JSON, no en SQLite ni Hive.** `descargas.json` en el directorio de
documentos: por álbum, una copia de sus datos (nombre, artista, año, artistas),
calidad, estado y, por canción, sus datos y el archivo. Son decenas de entradas; se
lee entero al arrancar y se reescribe entero en cada cambio, escribiendo a un
temporal y renombrando para que un cierre a medias no lo deje roto.

**Un gestor global, `ChangeNotifier`, como `player`.** `Descargas` guarda el índice,
una cola y un bucle que baja de una canción en una. La interfaz escucha con
`ListenableBuilder`. Recibe el directorio, el cliente HTTP y una función "¿hay
Wi-Fi?" en el constructor: los tests le pasan un directorio temporal, un
`MockClient` y `() => true`.

**Por canción, no por álbum, se decide qué falta.** Al retomar se salta lo que ya
tiene archivo completo. Cada canción se baja a `<id>.parte` y se renombra al acabar,
así una a medias nunca parece terminada.

**URLs de descarga en `Jellyfin`.** Original: `/Items/{id}/Download` (el archivo tal
cual, con su extensión de `Container`). AAC: `/Audio/{id}/universal` con los
parámetros medidos arriba y `Container=m4a`, que fuerza la conversión salvo que el
original ya sea AAC por debajo de la tasa. La extensión importa: AVPlayer reconoce el
formato de un archivo local por ella.

**La portada se guarda con el álbum** (`<albumId>.jpg`), y `Portada` la usa si existe
antes de pedir la de red. Sin eso, lo descargado se vería con bloques de color sin
conexión.

**`cancion()` consulta el gestor.** Si la canción tiene archivo, el `id` del
`MediaItem` es `file://…` y `extras['local']` lleva la calidad para la insignia del
Reproductor. Nada más cambia en el reproductor.

**`AlbumPage` cae al índice.** Si pedir a Jellyfin falla y el álbum está descargado,
usa la copia guardada; si no está, muestra el error como hasta ahora.

**Wi-Fi con `connectivity_plus`.** Es la única forma de distinguir Wi-Fi de datos en
iOS sin escribir un canal nativo. Se escucha su cambio para retomar la cola cuando
llega el Wi-Fi.

**`path_provider` se declara.** Ya estaba en el árbol por just_audio; usar una
dependencia transitiva sin declararla es depender de algo que puede desaparecer.

**Estimación: una consulta al abrir Descargas.** Canciones con `Fields=MediaSources`:
suma de `Size` para Original y de `RunTimeTicks` × tasa para las AAC. Las funciones
que formatean tamaños y estiman son puras y llevan prueba.

**Preferencias en `SharedPreferences`**, como la sesión: `calidad` y `soloWifi`.

## Risks / Trade-offs

- [iOS suspende la app a los pocos segundos en segundo plano y la descarga se para]
  → Se retoma al volver; `ponytail:` en el bucle con el techo y la salida
  (`background_downloader`).
- [El índice en memoria y en disco pueden divergir si la app muere entre renombrar
  un archivo y guardar el índice] → Al arrancar, el índice manda y lo que tiene
  archivo pero no entrada se borra en la siguiente limpieza; lo que tiene entrada y
  no archivo se vuelve a bajar.
- [Estimar con MediaSources pesa en bibliotecas grandes] → Se pide solo al abrir la
  pantalla de Descargas; con miles de canciones se cambia a una suma paginada.
