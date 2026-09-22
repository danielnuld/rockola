## Context

Medido en el Jellyfin 10.11.11 de casa:
- `GET /Audio/{id}/Lyrics` → `{"Metadata": {}, "Lyrics": [{"Text", "Start"?}]}`; `Start`
  en ticks (100 ns). 404 si no hay letra.
- Hay letras sincronizadas ("Blah, blah, blah…" de Cartel de Santa: 68 líneas con
  `Start`) y planas (*Highway to Hell*: sin `Start`).
- Cada canción trae `HasLyrics` sin pedir campos extra.
- Antes del cambio: 80 de 768 canciones con letra y ningún proveedor instalado. El
  catálogo oficial tiene **LrcLib Lyrics** 3.0 para 10.11, y Jellyfin trae la tarea
  "Descargar letras que faltan" (`DownloadLyrics`).

**Primer intento, en el servidor, y por qué no quedó**: se instaló el plugin oficial
**LrcLib Lyrics** 3.0 y se lanzó `DownloadLyrics` (2 min 39 s): la cobertura siguió en
80 de 776. `RemoteSearch/Lyrics` de *Reptilia* devolvía `[]` aunque lrclib.net la
tiene (consultada desde el servidor y desde el contenedor: 200 en 0.4 s). Tampoco
cambió con `UseStrictSearch: false` ni con LrcLib como proveedor de la biblioteca. El
registro solo dice "Artist name is required" en 26 canciones sin artista. lrclib a
veces responde 503 (saturado): puede que el plugin lo trague sin avisar. El plugin se
queda instalado; Rockola no depende de él.

## Goals / Non-Goals

**Goals:** letras en el reproductor, resaltadas cuando se puede, también sin red.

**Non-Goals:** editar, traducir, letra fuera del reproductor.

## Decisions

**Jellyfin primero, lrclib después, desde la app.** Lo que tenga Jellyfin se usa (y lo
ven los demás clientes); lo demás se le pide a lrclib.net desde Rockola, que tiene
CORS abierto y no pide clave. Búsqueda exacta (`/api/get`, exige la duración a ±2 s)
y, si no, amplia (`/api/search`) con elección propia: mismo artista, no instrumental,
duración a ≤ 5 s, sincronizada primero. Medido: "La Pelotona" (230 s) no aparece en la
exacta y la amplia trae tres versiones de Cartel de Santa (226, 221 y 222 s),
sincronizadas. `mejorCandidato` y el lector de LRC son puros y llevan prueba.

**Un 503 no es "sin letra".** Un error de lrclib lanza y no se guarda en la caché, así
que se reintenta al volver a abrirla; solo un 404 (o ningún candidato) es "no tiene".

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

**Sin red, la de la descarga.** `Descargas` guarda `<id>.letra.json` después del audio:
la de Jellyfin tal cual si `HasLyrics`, o la de lrclib convertida al mismo formato.
Un fallo ahí no marca la canción como fallida. Sin red, la vista cae a ese archivo.

## Risks / Trade-offs

- [lrclib no tiene todo, sobre todo rap mexicano poco conocido] → Se lee "Esta
  canción no tiene letra"; se mide en la prueba real.
- [Una letra sincronizada de otra versión de la canción va desfasada] → Es lo que
  devuelve LrcLib por título, artista, disco y duración; no se corrige en la app.
