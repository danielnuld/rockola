## Why

La app ya reproduce desde Jellyfin, pero con el aspecto por defecto de Material: nada
del lienzo aprobado (https://claude.ai/artifact/D14THDp29xLNVPMe49iS4m) está en el
código. Todas las fases siguientes (Biblioteca, Reproductor, Descargas, Radio) se
montan sobre el mismo tema, la misma navegación y la misma barra inferior, así que
esto va primero.

## What Changes

- Tema propio: fondo carbón cálido `#141110`, coral `#FF6B3D` para la música, ámbar
  `#F5B841` reservado a la radio; Bricolage Grotesque para títulos y DM Sans para
  texto, empaquetadas en la app (funciona sin conexión).
- Navegación con cuatro pestañas: Inicio, Buscar, Biblioteca, Radio. Cada pestaña
  conserva su pila de pantallas al cambiar de una a otra.
- La barra inferior del artboard **Pieza · Barra inferior**: mini reproductor con
  progreso encima de las pestañas, visible en todas las pantallas.
- La pantalla **iPhone · Inicio** con datos reales: saludo según la hora, tarjeta de
  Rockola FM y "Volver a escuchar" con los álbumes que más recientemente sonaron en
  Jellyfin.
- Con ventana ancha (web), el esqueleto de **Web · Inicio**: lateral con navegación y
  biblioteca, panel principal y barra del reproductor abajo a todo lo ancho.
- La cuadrícula de álbumes actual pasa a la pestaña Biblioteca tal cual, con el
  tema nuevo, hasta que la fase 2 la rehaga.

## Capabilities

### New Capabilities
- `apariencia`: colores, tipografías y reglas visuales comunes a toda la app.
- `navegacion`: pestañas, barra inferior con mini reproductor y el diseño ancho para web.
- `inicio`: contenido de la pantalla Inicio y de dónde sale cada sección.

### Modified Capabilities

## Impact

- `lib/main.dart` se parte: tema, armazón de navegación e Inicio salen a sus propios
  archivos; `LoginPage` y la lógica de sesión se quedan.
- `lib/jellyfin.dart` gana una consulta: canciones escuchadas recientemente.
- `pubspec.yaml`: las dos tipografías como assets. Ninguna dependencia nueva.

## Fuera de alcance

- Pantallas **Álbum**, **Biblioteca**, **Reproductor** y búsqueda: fase 2. Buscar
  muestra un estado vacío y el mini reproductor no abre nada todavía.
- **Descargas**: fase 3. El botón de descargas del encabezado de Inicio no aparece.
- **Mezclas para ti**: fase 4. La sección no se pinta hasta que exista el algoritmo.
- **Radio con locutora**: fases 5 y 6. La tarjeta de Rockola FM lleva a la pestaña
  Radio, que por ahora solo anuncia que viene.
- Portadas reales en todas partes ya se usan donde la API las da; los bloques de color
  del lienzo son solo el reemplazo cuando un álbum no tiene imagen.
