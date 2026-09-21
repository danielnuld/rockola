## 1. Servidor

- [x] 1.1 Instalar LrcLib Lyrics 3.0 en Jellyfin, reiniciar y lanzar "Descargar letras que faltan"
- [ ] 1.2 Medir la cobertura al terminar la tarea (antes: 80 de 768)

## 2. Cliente y datos

- [ ] 2.1 `Jellyfin.letra(id)` → líneas con inicio opcional; null si 404
- [ ] 2.2 `cancion()` con `letra: HasLyrics` en `extras`
- [ ] 2.3 `lineaActual(inicios, posicion)` pura, con test (antes de la primera, justo en un inicio, entre dos, después de la última)
- [ ] 2.4 Ruta de letras en el Jellyfin falso (una sincronizada, una plana)

## 3. Vista de letra

- [ ] 3.1 `lib/letras.dart`: lista de líneas; sincronizada con la actual en coral, las cantadas atenuadas, centrado al cambiar de línea, tocar salta; plana sin resaltar
- [ ] 3.2 Botón "Letra" en el Reproductor solo con `HasLyrics`; la letra reemplaza la portada, y con 900 px o más van lado a lado
- [ ] 3.3 Tests de widget: botón solo con letra; línea resaltada según la posición; tocar una línea pide ese `seek`; letra plana sin resaltar

## 4. Sin conexión

- [ ] 4.1 `Descargas` baja la letra de cada canción con `HasLyrics` (un fallo ahí no marca la canción); `letra` cae al archivo sin red
- [ ] 4.2 Test: la letra de una canción descargada se ve con Jellyfin caído

## 5. Cierre

- [ ] 5.1 `flutter analyze` y `flutter test` en verde
- [ ] 5.2 En Chrome con canciones reales: una sincronizada (resalta, centra, saltar) y una plana
- [ ] 5.3 IPA compilado
- [ ] 5.4 En el lienzo, el botón de letra en el Reproductor
