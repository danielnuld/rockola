## Why

El lienzo promete "Mezclas para ti, armadas con lo que escuchas", y la radio de las
fases 5 y 6 va a sacar sus canciones de ahí. Pero medido en el Jellyfin de casa:
**12 canciones escuchadas de 622, 15 reproducciones en total y ningún favorito**.
El motivo es de la propia app: Rockola nunca le avisa a Jellyfin de lo que suena,
así que ni las mezclas ni "Volver a escuchar" ni el orden "Escuchados hace poco"
tienen de qué aprender. Issue #4.

## What Changes

- **Rockola avisa a Jellyfin de lo que suena**: una canción que pasa de la mitad
  cuenta como escuchada (sube su contador y su fecha). Sin conexión, el aviso espera
  y sale cuando vuelve la red.
- **Registro local de saltos**: una canción que se deja antes de los 30 segundos
  cuenta como saltada. Jellyfin no guarda eso; se queda en el equipo.
- **Mezclas calculadas en el equipo** a partir de las canciones y sus datos
  (veces escuchada, favorita, género, año, artista) y de los saltos:
  - por familia de género, con los géneros agrupados ("Hip Hop", "Rap/Hip Hop" y
    "Pop Rap" son la misma familia);
  - por década ("Dosmilera", "Setentera");
  - "Lo más tuyo: <artista>", cuando ya hay historial;
  - "Lo que casi no tocas": sin escuchar, de lo que sí te gusta.
  Funcionan desde el primer día, con el historial vacío, y mejoran según se usa.
- Sección **Mezclas para ti** en Inicio (teléfono y web), como en **iPhone · Inicio**
  y **Web · Inicio**; página de cada mezcla con reproducir y aleatorio; filtro
  **Mezclas** en la Biblioteca.

## Capabilities

### New Capabilities
- `escuchas`: avisar a Jellyfin de lo escuchado y llevar la cuenta local de saltos.
- `mezclas`: cómo se arman las mezclas y dónde se ven.

### Modified Capabilities
- `inicio`: se añade la sección Mezclas para ti.
- `biblioteca`: se añade el filtro Mezclas.

## Impact

- Nuevo `lib/mezclas.dart` (algoritmo puro y página) y `lib/escuchas.dart`.
- `Jellyfin`: todas las canciones con géneros y año; marcar como escuchada.
- Sin dependencias nuevas.

## Fuera de alcance

- Mezclas sin conexión a partir de lo descargado: la función recibe una lista de
  canciones, así que la fase 6 le pasa las descargadas; el cableado es de esa fase.
- `InstantMix` de Jellyfin: se calcula en el servidor y no sirve sin red (ver design.md).
- Guardar las mezclas como listas en Jellyfin.
- Aprender con modelos o embeddings: primero la heurística, con su techo escrito.
- Llenar los géneros que faltan (116 canciones sin género): es trabajo de etiquetado.
