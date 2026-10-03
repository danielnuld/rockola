## Context

`LocutorIphone._entrada` pide el texto a Foundation Models (`escribir`) y lo manda tal
cual a `decir`, que lo lee con `AVSpeechUtterance(string:)`. El texto también se ve en
la pantalla de Radio (`extras['texto']`).

## Goals / Non-Goals

**Goals:** que la voz del sistema varíe el ritmo, el tono y las pausas según la entrada.

**Non-Goals:** otro motor de voz, emociones "actuadas", la locutora web.

## Decisions

**El ánimo lo elige el modelo, en una etiqueta al principio.** El modelo ya sabe qué
está diciendo, y una etiqueta es lo más fácil de pedirle a un modelo pequeño y de
quitar después. Se descartó pedirle SSML directamente: lo rompería a menudo.

**El SSML se arma en Dart (`hablada`), no en Swift.** Así se prueba con `flutter test`
sin Mac, y Swift solo elige entre `AVSpeechUtterance(ssmlRepresentation:)` y el texto
plano. Una etiqueta desconocida se quita igual y se habla normal.

**Cuatro ánimos con `<prosody rate pitch>` y `<break>` entre frases.** Es lo que
AVSpeech respeta de SSML; `<emphasis>` casi no hace nada con las voces del sistema.

## Risks / Trade-offs

- [El modelo no siempre pone la etiqueta] → Sin etiqueta se habla normal: nunca peor
  que hoy.
- [Los números de cada ánimo están puestos a ojo] → `ponytail:` en `animos`; se afinan
  de oído en el iPhone.
- [`ssmlRepresentation` devuelve nil con SSML que no entiende] → Se dice el texto plano.
