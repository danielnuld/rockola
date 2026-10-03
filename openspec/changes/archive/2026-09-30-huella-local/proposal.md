## Why

El visualizador solo reacciona a la música si hay un servidor de huellas, y montarlo
pide numpy, ffmpeg y acceso al disco de Jellyfin. Pocos de los que usen Rockola lo
tendrán. Pero una canción descargada ya está en el iPhone: su huella se puede calcular
ahí mismo en menos de un segundo, sin servidor. No hace falta IA: es una FFT.

## What Changes

- En iOS, al terminar de bajar cada canción, si no hay servidor de huellas o no
  responde, **se calcula la huella en el teléfono** y se guarda como
  `<id>.huella.json`, con el mismo formato que el servidor (`docs/huellas.md`).
- Con servidor configurado y respondiendo, se sigue bajando la suya, como hoy.
- El visualizador no cambia: ya lee la huella guardada con la descarga.
- Pantalla del lienzo: ninguna nueva; es el Visualizador de siempre.

## Capabilities

### New Capabilities

(ninguna)

### Modified Capabilities
- `visualizador`: la huella sin conexión ya no exige servidor de huellas en iOS.

## Impact

- `ios/Runner/AppDelegate.swift`: un canal `rockola/huella` que convierte un archivo
  a PCM mono de 16 bits a 22 050 Hz con `AVAssetReader`.
- Nuevo cálculo de bandas en Dart (`lib/huella.dart`), portado de `bandas_db` y
  `huella_de_pcm` de `servidor/huellas.py`.
- `lib/descargas.dart`: `_guardarHuella` recurre al cálculo local.
- `docs/huellas.md`: se explica que en el iPhone las descargas ya no lo necesitan.
- Sin dependencias nuevas.

## Fuera de alcance

- Streaming sin servidor: AVPlayer no entrega las muestras y la normalización necesita
  la canción entera. Se queda con el servidor opcional o con el patrón suave.
- La web: ahí no hay descargas.
- Recalcular las descargas que ya se hicieron sin huella: se rehacen si se borran y se
  vuelven a bajar.
- Formatos que `AVAssetReader` no abre (ogg, opus, wma en calidad Original): se quedan
  sin huella, como hoy.
