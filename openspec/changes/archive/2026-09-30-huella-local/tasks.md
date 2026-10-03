## 1. Cálculo en Dart

- [x] 1.1 En `lib/huella.dart`, `huellaDePcm(Int16List pcm)`: FFT radix-2 de 2048, Hann, 16 bandas log 40 Hz–11 kHz, dB, percentiles 5/99.5 por banda, bytes 0–255, igual que `servidor/huellas.py`
- [x] 1.2 Test como el `--check` de huellas.py: silencio y tono de 1 kHz, su banda va de 0 a >240; audio corto no revienta. Comparado a mano contra numpy: bytes idénticos
- [x] 1.3 `flutter analyze` y `flutter test` en verde

## 2. Decodificar en iOS

- [x] 2.1 En `AppDelegate.swift`, canal `rockola/huella` con `pcm(ruta)`: `AVAssetReader` a PCM mono 16 bits 22 050 Hz, en una cola de fondo, error de Flutter si no abre
- [x] 2.2 Registrarlo en `didInitializeImplicitFlutterEngine` como la locutora

## 3. Descargas

- [x] 3.1 `Descargas` recibe el decodificador (por defecto el canal); `_guardarHuella` usa el servidor y, si no hay o falla, decodifica + `Isolate.run(huellaDePcm)` y guarda el JSON
- [x] 3.2 Test con `MockClient` y un decodificador falso: sin servidor queda `<id>.huella.json` y `huellaGuardada` lo lee; con decodificador que falla la canción queda descargada sin huella
- [x] 3.3 `docs/huellas.md`: en el iPhone las descargas ya no necesitan servidor
- [x] 3.4 `flutter analyze` y `flutter test` en verde

## 4. En el iPhone

- [x] 4.1 `gh workflow run ios.yml`, instalar con Sideloadly, quitar el servidor de huellas en Ajustes, descargar un álbum (m4a) y otro en Original (flac/mp3)
- [x] 4.2 En modo avión, el visualizador reacciona a la música en ambos; anotar cuánto tardó la huella por canción
