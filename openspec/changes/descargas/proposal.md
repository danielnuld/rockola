## Why

Rockola es para el iPhone, y el iPhone no siempre tiene conexión, o la tiene cara:
Tailscale en datos móviles para escuchar un disco que ya se escuchó cien veces. Y el
original no cabe: la biblioteca pesa 8.16 GB en mp3 y flac. Issue #3.

## What Changes

- Descargar un álbum desde su página, con la calidad elegida. Jellyfin comprime en el
  servidor: medido con Reptilia (flac de 28.9 MB), AAC 256 da 7.2 MB, AAC 160 da
  4.5 MB y AAC 96 da 2.7 MB.
- Pantalla **Descargas** como el artboard **iPhone · Descargas y calidad**: espacio
  usado en el teléfono, elegir calidad (Original, Alta, Normal, Ahorro) con lo que
  ocuparía toda la biblioteca en cada una, y "Descargar solo con Wi-Fi".
- Lo descargado suena desde el archivo, con o sin conexión.
- Sin conexión la app arranca y deja escuchar lo descargado.
- Filtro **Descargado** en la Biblioteca; chips **Todo** y **Descargado** en Inicio.
- Insignia en el Reproductor cuando la canción sale del teléfono: "En el iPhone · AAC 160 kbps".

## Capabilities

### New Capabilities
- `descargas`: descargar y borrar álbumes, calidad, espacio usado, solo con Wi-Fi.
- `sin-conexion`: qué hace la app sin red y de dónde suena lo descargado.

### Modified Capabilities
- `biblioteca`: se añade el filtro Descargado.
- `inicio`: se añaden los chips Todo y Descargado.
- `album`: se añade el botón de descarga.
- `reproductor`: se añade la insignia de origen y calidad.

## Impact

- Nuevo `lib/descargas.dart` (gestor e índice) y la pantalla de Descargas.
- `cancion()` elige archivo local o stream; `AlbumPage` cae al índice local sin red.
- Dependencias: `path_provider` pasa de transitiva (la trae just_audio) a declarada, y
  `connectivity_plus` para saber si hay Wi-Fi.
- Solo iOS: en la web no se descarga (ver design.md).

## Fuera de alcance

- Descargas que siguen con la app cerrada o en segundo plano: arrancan de nuevo al
  abrirla. Si molesta, se evalúa `background_downloader`.
- Descargar canciones sueltas o artistas enteros: por álbum.
- Borrar automáticamente lo que no se escucha: no está pedido.
- El interruptor "Giulia en este iPhone" del lienzo: fase 6.
- Espacio libre del teléfono: pediría otro plugin y el sistema ya lo dice en Ajustes.
