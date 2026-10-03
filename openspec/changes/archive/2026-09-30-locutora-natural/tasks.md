## 1. Dart

- [x] 1.1 Instrucciones de `pedidoLocutora`: escribir para oírse y empezar con el ánimo entre corchetes
- [x] 1.2 `hablada(salida)`: separa el ánimo, devuelve el texto limpio y el SSML (prosodia del ánimo, pausas, XML escapado)
- [x] 1.3 `LocutorIphone` muestra el texto limpio y manda el SSML a `decir`
- [x] 1.4 Tests de `hablada` y del canal; `flutter analyze` y `flutter test` en verde

## 2. iOS

- [x] 2.1 `decir` usa `AVSpeechUtterance(ssmlRepresentation:)` en iOS 16+ si llega SSML válido; si no, el texto plano

## 3. En el iPhone

- [x] 3.1 IPA con `gh workflow run ios.yml`: sintonizar y oír que las entradas cambian de ritmo y hacen pausas; ajustar los números de cada ánimo de oído
