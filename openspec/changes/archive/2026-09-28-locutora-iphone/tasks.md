## 1. Dos motores detrás de `Locutor`

- [x] 1.1 `Locutor` como interfaz; el cliente HTTP pasa a `LocutorServidor` (radio, ajustes, terminal y tests)
- [x] 1.2 `pedidoLocutora`: instrucciones y pedido para el modelo a partir de `antes`, `despues` y `charla`, con test
- [x] 1.3 `LocutorIphone` sobre el canal `rockola/locutor` (`voz`, `escribir`, `decir`); sin dato
- [x] 1.4 `flutter analyze` y `flutter test` pasan

## 2. El lado de iOS

- [x] 2.1 Canal `rockola/locutor` en `AppDelegate.swift`: Foundation Models y `AVSpeechSynthesizer.write` a `.caf`, con `#available(iOS 26)`
- [x] 2.2 La mejor voz en español instalada, por calidad y región

## 3. La radio en el iPhone

- [x] 3.1 `SesionRadio.configurar` usa `LocutorIphone` en iOS, el servidor en la web
- [x] 3.2 La pestaña Radio muestra la radio en iOS; Ajustes esconde el campo del locutor en iOS
- [x] 3.3 Test: en iOS la sesión no llama al servidor aunque haya uno guardado
- [x] 3.4 `docs/locutor.md` y `openspec/config.yaml`: la voz del sistema en vez de Piper
- [x] 3.5 `ios.yml` compila el IPA; prueba en el iPhone: Sintonizar habla en español
- [x] 3.6 Ajustes del iPhone: elegir la voz entre las instaladas en español, con muestra y "Automática"; test
