## 1. Separar lo puro

- [ ] 1.1 `huella.dart` (Huella, cuadroEn, golpe, sintetico) desde `visualizador.dart`
- [ ] 1.2 `mezclas.dart` puro y sus widgets a `mezclas_pantalla.dart`
- [ ] 1.3 `locutor.dart` (Locutor, horaDeRadio); `entrada` recibe un registro y `SesionRadio` lo arma desde el `MediaItem`
- [ ] 1.4 `flutter analyze` y `flutter test` en verde, sin cambiar tests más allá de los imports

## 2. mpv

- [ ] 2.1 `lib/terminal/mpv.dart`: buscar mpv, arrancarlo con su tubería, abrirla por `\\?\pipe\`, petición-respuesta con `request_id`, cerrar
- [ ] 2.2 Cola: cargar la lista, insertar un archivo en una posición, siguiente, anterior, pausa, adelantar
- [ ] 2.3 Test contra un mpv falso (el protocolo de líneas JSON, eventos que se ignoran, tubería rota)

## 3. Sesión y comandos

- [ ] 3.1 `lib/terminal/config.dart`: el JSON en `%APPDATA%\Rockola`; `login` y `ajustes`
- [ ] 3.2 `bin/rockola.dart`: búsqueda con lista numerada, `mezclas`, `radio`; ayuda con `-h`
- [ ] 3.3 Test: de los resultados de búsqueda a la cola (canción + resto del álbum, álbum, artista)

## 4. Pantalla "Suena"

- [ ] 4.1 `lib/terminal/pantalla.dart`: buffer alterno, dibujo por cuadro, restaurar al salir y con Ctrl+C
- [ ] 4.2 Barras de texto (Unicode con color y ASCII) como función pura `barras(bandas, ancho, alto, ascii)`, con test
- [ ] 4.3 Letra: línea actual y siguiente con `letraDe` sin Flutter (Jellyfin, si no lrclib)
- [ ] 4.4 Teclas y el tic de 50 ms (posición, índice, pausa); escuchas al empezar y terminar

## 5. Radio

- [ ] 5.1 Hora de radio con `horaDeRadio`; entradas del locutor a `.ogg` temporal e insertadas en la cola; su texto en pantalla

## 6. Cierre

- [ ] 6.1 `flutter analyze`, `flutter test` y `dart build cli -t bin/rockola.dart` en verde
- [ ] 6.2 Con Daniel en su terminal: búsqueda, mezcla y radio con canciones reales, visualizador con color y con `--ascii`
- [ ] 6.3 `docs/terminal.md`: instalar mpv, compilar, `login`, comandos y teclas
