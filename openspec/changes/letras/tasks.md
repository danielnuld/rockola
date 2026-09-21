## 1. Servidor

- [x] 1.1 Instalar LrcLib Lyrics 3.0 en Jellyfin, reiniciar y lanzar "Descargar letras que faltan"
- [x] 1.2 Medir la cobertura: siguió en 80 de 776; el plugin no encuentra nada (ver design.md). Se pasa a lrclib desde la app
- [x] 1.3 `lib/lrclib.dart`: búsqueda exacta y amplia, `mejorCandidato`, lector de LRC y conversión al formato de Jellyfin, con tests

## 2. Cliente y datos

- [x] 2.1 `Jellyfin.letra(id)` → líneas con inicio opcional; null si 404
- [x] 2.2 `cancion()` con `letra: HasLyrics` en `extras`
- [x] 2.3 `lineaActual(inicios, posicion)` pura, con test (antes de la primera, justo en un inicio, entre dos, después de la última)
- [x] 2.4 Ruta de letras en el Jellyfin falso (una sincronizada, una plana)

## 3. Vista de letra

- [x] 3.1 `lib/letras.dart`: lista de líneas; sincronizada con la actual en coral, las cantadas atenuadas, centrado al cambiar de línea, tocar salta; plana sin resaltar
- [x] 3.2 Botón "Letra" en el Reproductor en toda canción de la biblioteca; Jellyfin primero y lrclib si no; la letra reemplaza la portada, y con 900 px o más van lado a lado
- [x] 3.3 Tests de widget: línea resaltada según la posición; tocar una línea pide ese `seek`; letra plana sin resaltar; sin letra en Jellyfin sale la de lrclib

## 4. Sin conexión

- [x] 4.1 `Descargas` guarda la letra de cada canción (de Jellyfin o de lrclib; un fallo ahí no marca la canción); sin red la vista cae al archivo
- [x] 4.2 Tests: la descarga guarda la de lrclib; la letra de una canción descargada se ve con Jellyfin y lrclib caídos

## 5. Cierre

- [x] 5.1 `flutter analyze` y `flutter test` en verde
- [ ] 5.2 En Chrome con canciones reales: una sincronizada (resalta, centra, saltar) y una plana
- [x] 5.3 IPA compilado
- [ ] 5.4 En el lienzo, el botón de letra en el Reproductor
