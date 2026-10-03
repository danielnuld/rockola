## Why

La locutora del iPhone suena robótica: el sintetizador lee el texto con el mismo ritmo y
el mismo tono de principio a fin. No hay voz del sistema que exprese emociones de
verdad, pero `AVSpeechSynthesizer` acepta SSML (iOS 16+): con él se varían el ritmo,
el tono y las pausas según lo que se dice. Además, el texto que escribe el modelo no
está pensado para oírse.

## What Changes

- El modelo escribe para ser oído: frases cortas, comas donde se respira, exclamaciones
  o preguntas cuando vengan al caso.
- El modelo elige un **ánimo** por entrada (alegre, emocionada, tranquila o nostálgica)
  y lo pone al principio entre corchetes. La app lo quita del texto que se ve y lo
  convierte en ritmo y tono.
- La voz se dice en SSML: el ritmo y el tono del ánimo, y una pausa entre frases y
  en los puntos suspensivos. En iOS 15, o si el SSML no vale, se dice como hoy.
- Pantalla del lienzo: Radio. No cambia; solo la voz.

## Capabilities

### New Capabilities

(ninguna)

### Modified Capabilities
- `radio`: la locutora del iPhone habla con ánimo y pausas.

## Impact

- `lib/locutor.dart`: las instrucciones, y una función que separa el ánimo y arma el SSML.
- `ios/Runner/AppDelegate.swift`: `decir` acepta SSML.
- Sin dependencias nuevas. La locutora web, que usa el servidor del locutor, no cambia.

## Fuera de alcance

- Otro motor de voz (Kokoro, Piper) y TTS en la nube.
- Elegir el ánimo desde la app: lo decide el modelo.
- `probar` en Ajustes sigue con la frase de muestra plana.
