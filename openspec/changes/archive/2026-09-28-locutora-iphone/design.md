## Context

La radio ya funciona en la web: `SesionRadio` (`lib/radio.dart`) arma la hora, pide
cada entrada a un `Locutor` con `nombre()` y `entrada()`, y mete en la cola un
`MediaItem` cuyo `id` es el audio de la entrada. Hoy `Locutor` es el cliente HTTP del
servidor del locutor, y su audio es OGG/Opus en una `data:` URI. En iOS la pestaña
Radio es un estado vacío (`lib/armazon.dart`).

En el iPhone suena con just_audio sobre AVPlayer, que no reproduce OGG ni `data:`.
No hay Mac: se compila en `ios.yml` (macos-latest, Xcode 26) y se prueba con
Sideloadly. Apple Intelligence exige iOS 26 y un iPhone 15 Pro o posterior; la app
se queda en iOS 15 como mínimo.

## Goals / Non-Goals

**Goals:** la radio con locutora en el iPhone, sin red para la voz ni para el texto,
sin clave y sin tocar cómo `SesionRadio` arma la hora.

**Non-Goals:** Piper, elegir motor en el iPhone, datos verificados, radio en Windows.

## Decisions

**`Locutor` pasa a interfaz con dos motores.** `abstract interface class Locutor` con
`nombre()` y `entrada()`; el cliente HTTP de hoy se renombra `LocutorServidor` y se
añade `LocutorIphone`. Es el caso que `openspec/config.yaml` ya prevé (dos motores
reales detrás de una interfaz). `SesionRadio` no cambia más que al elegir el motor.
Alternativa: `LocutorIphone implements Locutor` sobre la clase concreta; obliga a
fingir `url` y deja el tipo mintiendo.

**`entrada().audio` es una URI cualquiera.** El servidor sigue dando `data:`; el
iPhone da `file:` de un `.caf` temporal. `SesionRadio` ya la usa tal cual como `id`
del `MediaItem`.

**Un canal de plataforma, `rockola/locutor`, en `AppDelegate.swift`.** Ninguna
dependencia de pub.dev envuelve Foundation Models y `AVSpeechSynthesizer.write` a la
vez; son ~60 líneas de Swift. Tres métodos:
- `voz` → el nombre de la voz si el modelo está disponible, `null` si no. Sirve de
  `nombre()`: sin modelo no hay locutora y la pantalla ya sabe decirlo.
- `escribir {instrucciones, pedido}` → el texto, con una `LanguageModelSession`
  nueva por entrada (sin historia que crezca).
- `decir {texto}` → la ruta del `.caf` con `AVSpeechSynthesizer.write`, en el
  directorio temporal.
Todo detrás de `if #available(iOS 26, *)`; `import FoundationModels` sin `#if`: sin
el SDK de iOS 26, que falle la compilación y no la locutora en silencio.

**El texto que se le pide al modelo se arma en Dart.** Instrucciones y pedido salen de
una función pura (`pedidoLocutora`) con prueba, igual que `horaDeRadio`; Swift solo
ejecuta. Cambiar el tono no requiere compilar en macOS.

**La voz: la mejor en español instalada.** Entre `speechVoices()` con idioma `es`, la
de mayor `quality` (premium > mejorada > normal), prefiriendo la región del teléfono y
después `es-MX`. Sin nada en español, la del idioma `es-MX` por defecto.

**Elegir la voz en Ajustes.** El identificador de la voz se guarda en
`SharedPreferences` (`voz`) y `LocutorIphone` lo lee en cada entrada y lo pasa al canal
(`voz`, `decir`); `voces` lista las instaladas ya ordenadas y `probar` dice una frase
con un segundo `AVSpeechSynthesizer` que sí suena. La lista no se guarda en Swift:
una voz recién descargada aparece sin reabrir la app.

**Sin dato en el iPhone.** `LocutorIphone` ignora `dato`: el modelo (~3B) no sabe
historia de la música y la inventaría. Habla de lo que le pasa la app: título,
artista, álbum, año y escuchas.

**En el iPhone, siempre `LocutorIphone`.** `SesionRadio.configurar` elige por
plataforma (`defaultTargetPlatform == TargetPlatform.iOS && !kIsWeb`), y Ajustes
esconde el campo del servidor del locutor en iOS. Un servidor en el iPhone no sonaría
(OGG en `data:`).

**Los `.caf` se quedan en el temporal.** iOS lo vacía solo; cada entrada pesa
~1 MB (PCM de 20 s). No se borran a mano.

## Risks / Trade-offs

- [macos-latest sin el SDK de iOS 26] → `ios.yml` falla al compilar: se ve enseguida.
- [El modelo se niega (guardrails) o tarda] → `escribir` devuelve error, la entrada
  es `null` y la música sigue: el mismo camino que un servidor caído. La apertura ya
  espera como mucho 8 s.
- [La voz normal suena robótica] → Se usa la mejor instalada; en la pantalla de radio
  sin voz mejorada no se avisa (fuera de alcance). Piper queda como siguiente paso.
- [`AVSpeechSynthesizer.write` con el audio de la app sonando] → No reproduce, solo
  escribe buffers: no toca la sesión de audio.
- Nada de esto se puede probar sin iPhone: la prueba ejecutable es el test del
  pedido y de la elección de motor; la de la voz, en el teléfono del autor.
