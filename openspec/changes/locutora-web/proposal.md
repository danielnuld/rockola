## Why

La radio con locutora es lo que ningún otro cliente de Jellyfin tiene, y es la razón
de que Rockola exista. En la web la locutora no puede vivir en el navegador (no hay
modelo ni voz, y una clave de API ahí queda expuesta), así que la genera un servidor
del locutor que el usuario configura. En la instalación de Daniel ese servidor es
Giulia (`danielnuld/jarvis-m710q#4`, cambio `ruta-radio`). Issue #5.

## What Changes

- **Contrato del servidor del locutor** documentado en `docs/locutor.md`: `GET` y
  `POST /locutor`, para que quien instale Rockola sin Giulia pueda montar el suyo.
- **Ajustes** con el campo "Servidor del locutor" y una prueba de conexión que
  muestra el nombre de la locutora.
- **Rockola FM en la web**, como el artboard **Web · Radio con locutora**: una hora de
  canciones sacadas de las mezclas del día, con entradas de la locutora intercaladas
  cada tres canciones (cada seis con "Menos charla"); lo que dice, escrito en grande;
  lo que sigue; "En la rotación" con canciones y entradas; "Cambiar el rumbo" arma otra
  hora.
- Cada entrada se pide mientras suena la canción anterior. Si no llega a tiempo o el
  servidor falla, la música sigue sin locutora.
- La tarjeta de Rockola FM de Inicio lleva a la radio; mini reproductor y barra web
  muestran a la locutora mientras habla.

## Capabilities

### New Capabilities
- `radio`: cómo se arma la hora, cuándo entra la locutora y qué pasa si no responde.
- `ajustes`: el servidor del locutor y dónde se guarda.

### Modified Capabilities
- `navegacion`: la pestaña Radio deja de estar vacía en la web.

## Impact

- Nuevos `lib/radio.dart` (sesión, cliente del locutor y pantalla) y `lib/ajustes.dart`.
- `lib/player.dart`: insertar en la cola a media reproducción.
- `docs/locutor.md` con el contrato.
- Sin dependencias nuevas.

## Fuera de alcance

- **La radio en el iPhone**: fase 6, con Foundation Models y Piper en el teléfono. Allí
  la pestaña Radio sigue anunciando que viene; el iPhone nunca llama al servidor.
- **"Pedirle algo"** a la locutora: el botón del lienzo queda para después.
- Guardar radios pasadas o repetir una hora.
- Probar la radio en Safari: reproduce OGG/Opus de forma irregular; el objetivo es
  Chrome.
