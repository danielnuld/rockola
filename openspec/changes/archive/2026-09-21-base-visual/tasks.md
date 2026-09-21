## 1. Tema y tipografías

- [x] 1.1 Bajar las instancias estáticas de Bricolage Grotesque (600, 800) y DM Sans (400, 500, 700) a `assets/fonts/` con su `OFL.txt`, y declararlas en `pubspec.yaml`
- [x] 1.2 Crear `lib/tema.dart`: colores del lienzo como `const Color` y un `ThemeData` oscuro con las dos familias; `MaterialApp` lo usa con `themeMode: ThemeMode.dark`
- [x] 1.3 Portada de reemplazo: `Cover` recibe id y nombre, y sin imagen pinta el bloque de color (ocho tonos, `id.hashCode % 8`) con la inicial
- [x] 1.4 Comprobar: `flutter analyze` limpio y en Chrome el login y la cuadrícula ya salen con el tema nuevo

## 2. Armazón de navegación

- [x] 2.1 `lib/armazon.dart`: `IndexedStack` con cuatro `Navigator` (Inicio, Buscar, Biblioteca, Radio); tocar la pestaña activa hace `popUntil` a la primera pantalla
- [x] 2.2 Pestañas de abajo como en **Pieza · Barra inferior**: iconos de trazo, etiqueta, activa en `#F4EDE6` y el resto en `#9C9086`, objetivos de 44 px
- [x] 2.3 Buscar y Radio con su estado vacío ("Aquí vas a poder buscar…", "Rockola FM llega pronto"); Biblioteca con la cuadrícula actual de álbumes
- [x] 2.4 Test de widget: entrar a un álbum en Biblioteca, cambiar a Inicio, volver y seguir en el álbum; tocar Biblioteca otra vez regresa a la cuadrícula

## 3. Mini reproductor

- [x] 3.1 Rehacer `MiniPlayer` como en la barra del lienzo: fondo `#4A2519`, portada, título, artista, pausa/reproducir con etiqueta de accesibilidad
- [x] 3.2 Línea de progreso con la posición de `playbackState` (ver design.md) contra la duración del `MediaItem`
- [x] 3.3 Se muestra solo con cola; sin cola, solo las pestañas
- [x] 3.4 Comprobar en Chrome: poner un álbum, ver avanzar el progreso, pausar y reanudar desde la barra

## 4. Inicio

- [x] 4.1 `Jellyfin.recientes()`: canciones con `SortBy=DatePlayed`, `SortOrder=Descending`, `Filters=IsPlayed`, `Limit=60`
- [x] 4.2 Función pura `albumesRecientes(canciones, max: 6)` que deja los `AlbumId` distintos en orden, con su test
- [x] 4.3 Pantalla Inicio como **iPhone · Inicio**: saludo por hora (función pura con test para 5:59, 6:00, 11:59, 12:00, 18:59, 19:00), tarjeta ámbar de Rockola FM, cuadrícula de dos columnas de "Volver a escuchar". Los chips del lienzo quedan para la fase 3 (ver design.md)
- [x] 4.4 "Sintonizar" cambia a la pestaña Radio; tocar un álbum lo abre dentro de Inicio
- [x] 4.5 Estados: sin historial se oculta la sección; con error, una línea con "Reintentar"

## 5. Diseño ancho (web)

- [x] 5.1 `LayoutBuilder` a 900 px en el armazón: lateral de 320 px con logo, las cuatro secciones y la lista de la biblioteca; panel principal redondeado; barra del reproductor abajo a todo lo ancho, como **Web · Inicio**
- [x] 5.2 Barra del reproductor ancha: canción a la izquierda, controles y progreso al centro, volumen a la derecha
- [x] 5.3 Test de widget: a 1440 px no hay pestañas abajo y sí lateral; a 390 px al revés
- [x] 5.4 Comprobar en Chrome: cambiar el ancho de la ventana con música sonando y que no se corte

## 6. Cierre

- [x] 6.1 `flutter analyze` y `flutter test` en verde
- [x] 6.2 `gh workflow run ios.yml` y que el IPA compile
- [x] 6.3 Si algo del lienzo no funcionó igual en la app, corregir el lienzo para que siga siendo el plano
