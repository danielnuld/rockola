## 1. Base

- [x] 1.1 Declarar `path_provider` y añadir `connectivity_plus` en `pubspec.yaml`
- [x] 1.2 `Calidad` (original, alta, normal, ahorro) con etiqueta, tasa y extensión; `Jellyfin.descarga(item, calidad)` con las URLs de design.md; `Jellyfin.totales()` (tamaño original y duración)
- [x] 1.3 Funciones puras con test: `estimar(totales, calidad)` y `tamano(bytes)` ("190 MB", "2.8 GB")

## 2. Gestor de descargas

- [x] 2.1 `lib/descargas.dart`: `Descargas` (`ChangeNotifier`) con índice JSON, escritura por temporal y renombrado
- [x] 2.2 Cola de una canción a la vez, archivo `.parte` renombrado al acabar, portada del álbum guardada
- [x] 2.3 Retomar al arrancar lo pendiente, saltando las canciones que ya tienen archivo
- [x] 2.4 Solo con Wi-Fi: esperar y retomar con el cambio de conectividad
- [x] 2.5 Borrar un álbum (archivos e índice) y espacio usado
- [x] 2.6 Tests con directorio temporal y `MockClient`: bajar un álbum de dos canciones, retomar uno a medias, esperar sin Wi-Fi, borrar
- [x] 2.7 `main.dart`: iniciar `descargas` solo fuera de la web

## 3. Reproducir lo descargado

- [x] 3.1 `cancion()`: `file://` y `extras['local']` si hay archivo
- [x] 3.2 `Portada` usa la portada guardada si existe
- [x] 3.3 `AlbumPage` cae al índice sin conexión; test con un Jellyfin falso que falla
- [x] 3.4 Insignia "En el iPhone · <calidad>" en el Reproductor

## 4. Interfaz

- [x] 4.1 Botón de descarga en el Álbum: sin descargar, avance, descargado con tamaño; borrar con confirmación
- [x] 4.2 Pantalla Descargas como **iPhone · Descargas y calidad**: espacio usado, calidades con estimación, solo con Wi-Fi; se abre desde el botón del encabezado de Inicio
- [x] 4.3 Filtro Descargado en Biblioteca e indicador coral en las filas
- [x] 4.4 Chips Todo y Descargado en Inicio
- [x] 4.5 Nada de esto aparece en la web; test de widget sin gestor (como la web) que no encuentra el botón de descarga

## 5. Cierre

- [x] 5.1 `flutter analyze` y `flutter test` en verde
- [ ] 5.2 IPA compilado; en el iPhone: descargar un álbum, ponerlo en modo avión y escucharlo (lo hace Daniel)
- [x] 5.3 Corregir en el lienzo las estimaciones de Descargas con las cifras medidas
