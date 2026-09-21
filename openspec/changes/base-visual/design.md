## Context

Hoy la app es un solo `lib/main.dart` con `LoginPage`, `AlbumsPage`, `AlbumPage`,
`Cover` y `MiniPlayer` sobre el tema Material con semilla verde, más `jellyfin.dart`
(cliente HTTP) y `player.dart` (puente just_audio ↔ audio_service). Funciona en Chrome
y compila para iOS. El plano es el lienzo: artboards **iPhone · Inicio**, **Pieza ·
Barra inferior** y **Web · Inicio**.

## Goals / Non-Goals

**Goals:**
- Que Inicio, la barra y el esqueleto web se vean como en el lienzo.
- Dejar el armazón (tema, pestañas, diseño ancho) que las fases 2–6 solo rellenan.

**Non-Goals:**
- Pantallas nuevas fuera de Inicio (ver "Fuera de alcance" en la propuesta).
- Animaciones o transiciones propias: las de Flutter por defecto bastan.

## Decisions

**Tipografías como assets, no el paquete `google_fonts`.** La app tiene que verse
igual sin conexión; `google_fonts` descarga en tiempo de ejecución salvo que se
empaqueten los archivos igual, y entonces el paquete sobra. Se bajan una vez las
instancias estáticas (Bricolage 600/800, DM Sans 400/500/700) desde la API CSS de
Google Fonts y se declaran en `pubspec.yaml`. Estáticas y no variables: con la
variable, que `FontWeight` mueva el eje `wght` depende de la plataforma, y aquí se
quiere lo mismo en Chrome que en iOS. Licencia OFL: el archivo de licencia va junto.

**Tema en un archivo, con `ThemeData` y constantes.** `lib/tema.dart` con los colores
como `const Color` y un `ThemeData` oscuro. Sin clase de tokens ni `ThemeExtension`:
una sola paleta y ningún tema alternativo.

**Pestañas con `IndexedStack` de cuatro `Navigator`, no `go_router`.** Es lo que
pide "cada pestaña guarda su recorrido" y cabe en unas 30 líneas; `go_router` con
`StatefulShellRoute` hace lo mismo con una dependencia y rutas con nombre que nadie
va a enlazar desde fuera. Si algún día hace falta abrir la app en una URL concreta de
la web, ahí se reconsidera.

**Un armazón, dos disposiciones, con `LayoutBuilder` a 900 px.** Mismos cuatro
`Navigator`; lo único que cambia es quién los elige (pestañas abajo o lateral) y si el
reproductor es mini o barra completa. Sin plataforma detectada: manda el ancho, así
un iPad o una ventana estrecha de escritorio caen donde deben.

**La barra lee de `player` directamente.** `MiniPlayer` ya escucha `mediaItem` y
`playbackState` del `AudioHandler` global; se rehace su apariencia y se le añade la
línea de progreso con `AudioService.position`. Nada de gestor de estado nuevo.

**Volver a escuchar = canciones recientes, agrupadas por álbum.** Jellyfin no guarda
"fecha de reproducción" de álbumes, solo de canciones. Una consulta
`IncludeItemTypes=Audio&SortBy=DatePlayed&SortOrder=Descending&Filters=IsPlayed&Limit=60`
y quedarse con los primeros seis `AlbumId` distintos. La función que agrupa es pura
y lleva su prueba.

**Color de portada de reemplazo por hash del id.** Una lista fija de ocho tonos del
lienzo e índice `id.hashCode % 8`: estable por álbum sin guardar nada.

## Risks / Trade-offs

- [60 canciones pueden no alcanzar seis álbumes si se escucha un disco entero de
  seguido] → Se muestran los que salgan; subir el `Limit` es un número.
- [`hashCode` de `String` en Dart no está garantizado entre versiones] → Solo es un
  color de reemplazo; si cambia, cambia el color, nada se rompe.
- [El diseño ancho se prueba en Chrome, el estrecho debería probarse en el iPhone] →
  Chrome con la ventana estrecha cubre la mayor parte; el IPA se compila al cerrar la
  fase para mirarlo en el teléfono.
