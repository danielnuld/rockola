## Why

En el iPhone la pestaña Radio todavía dice "llega pronto": es la fase 6, la
locutora en el propio teléfono, sin servidor ni clave. Con iOS 26 el modelo de
Apple Intelligence (Foundation Models) ya está en el iPhone del autor (15 Pro), así
que la radio puede sonar allí igual que en la web.

## What Changes

- **Rockola FM en el iPhone**: la misma pantalla que en la web (artboard **Web · Radio
  con locutora**, en el ancho del teléfono) en lugar del aviso "llega pronto".
- **La locutora del iPhone**: el texto de cada entrada lo escribe Foundation Models en
  el teléfono y la voz la pone el sintetizador del sistema (`AVSpeechSynthesizer`),
  con la mejor voz en español instalada. Se llama como esa voz.
- En el iPhone es la locutora **siempre**: no llama al servidor del locutor (su audio
  es OGG en `data:`, que AVPlayer no reproduce) y Ajustes no muestra ese campo.
- Sin Apple Intelligence (iPhone anterior al 15 Pro, iOS < 26 o apagado), la radio
  suena solo con música y la pantalla lo dice.
- La locutora del iPhone no cuenta datos: el modelo es pequeño y los inventaría.

## Capabilities

### New Capabilities
<!-- ninguna -->

### Modified Capabilities
- `radio`: la radio existe también en el iPhone, con su locutora local; el dato no
  se pide al modelo del teléfono.
- `navegacion`: la pestaña Radio deja de estar vacía en el iPhone.
- `ajustes`: el servidor del locutor es solo de la web.

## Fuera de alcance

- **Piper** (sherpa-onnx, `es_AR-daniela-high`) para la voz: se queda la del sistema
  por decisión del autor; Piper si la voz no convence.
- Elegir en el iPhone entre la locutora local y un servidor.
- La radio en Windows y en la terminal.
- Datos verificados en el iPhone (buscarlos en la red para el modelo).

## Impact

- `lib/locutor.dart`: `Locutor` pasa a interfaz con dos motores, `LocutorServidor` (el
  cliente HTTP de hoy) y `LocutorIphone` (canal de plataforma).
- `ios/Runner/AppDelegate.swift`: el canal `rockola/locutor` con Foundation Models y
  `AVSpeechSynthesizer.write` a un `.caf` temporal. Protegido con
  `#available(iOS 26)`: el mínimo de la app sigue en iOS 15.
- `lib/radio.dart`, `lib/armazon.dart`, `lib/ajustes.dart`, `lib/terminal/reproductor.dart`.
- Sin dependencias nuevas de Dart ni de CocoaPods.
