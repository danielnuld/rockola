## Context

`Descargas._trabajar` baja cada canción y luego llama a `_guardarHuella`, que hoy solo
baja la huella del servidor si hay uno. `huellaDe` (lib/visualizador.dart) ya prefiere
la huella guardada, así que el visualizador no se toca. Las descargas son AAC en `.m4a`
(Alta, Normal, Ahorro) o el archivo original (mp3 o flac en el servidor). No hay Mac: el Swift
solo se prueba en el IPA de GitHub Actions, así que conviene que sea lo menos posible.

## Goals / Non-Goals

**Goals:** que toda canción descargada en el iPhone tenga huella sin servidor, con los
mismos números que da `servidor/huellas.py`.

**Non-Goals:** streaming, web, huellas para descargas anteriores.

## Decisions

**Swift solo decodifica; las cuentas van en Dart.** `AVAssetReaderTrackOutput` con
`outputSettings` de PCM lineal, mono, 16 bits y 22 050 Hz: AVFoundation decodifica y
remuestrea en un paso, sin ffmpeg. Devuelve los bytes como `FlutterStandardTypedData`
(unos 10 MB por canción de 4 min). Hacer la FFT en Swift con vDSP sería más rápido,
pero sin Mac no se podría probar. En Dart se prueba con `flutter test` y el visualizador
recibe lo mismo en web y en iOS. Se descartó ffmpeg_kit: 30 MB y dependencia nueva
para algo que AVFoundation ya hace.

**Una FFT radix-2 en Dart, de N = 2048.** No hay ninguna en Flutter ni en las
dependencias; son unas 20 líneas. La canción se analiza en `Isolate.run` para no
trabar la interfaz. Una de 3:40 son ~4400 FFT, menos de un segundo en AOT. La ventana
Hann, las 16 bandas geométricas de 40 Hz a 11 kHz, los dB y los percentiles 5 y 99.5
por banda se copian literales de `huellas.py`, con percentil por interpolación lineal
como el de numpy.

**El orden en `_guardarHuella`:** primero el servidor si está configurado, y si no hay
o falla, el cálculo local. Guarda el JSON `{"fps","bandas","cuadros","datos"}` en
`<id>.huella.json`, igual que el servidor. En la web no hay descargas, así que el
canal solo se llama en iOS (`descargas` es `null` en web). Cualquier error, sea un
formato que no se abre o una canción vacía, se traga como hoy.

**Los tests ponen el decodificador.** `Descargas` recibe una función
`Future<Uint8List?> Function(String ruta)` que decodifica; por defecto es el canal. El
test le pasa PCM de un tono sin tocar la plataforma.

## Risks / Trade-offs

- [PCM de canciones largas en memoria: una de 20 min son ~53 MB] → Aceptable en un
  iPhone; `ponytail:` en el código, y se decodifica por trozos si alguna vez molesta.
- [Si la FFT en Dart resulta lenta en el teléfono] → Se mide en el IPA; plan B:
  mover `bandas_db` a vDSP en Swift.
- [Pequeñas diferencias contra numpy por el redondeo de float] → Irrelevantes para
  animar; el test comprueba el comportamiento (tono de 1 kHz), no bytes exactos.
