## 1. Separar lo puro

- [x] 1.1 `huella.dart` (Huella, cuadroEn, golpe, sintetico) desde `visualizador.dart`
- [x] 1.2 `mezclas.dart` puro y sus widgets a `mezclas_pantalla.dart`
- [x] 1.3 `locutor.dart` (Locutor, horaDeRadio); `entrada` recibe un registro y `SesionRadio` lo arma desde el `MediaItem`
- [x] 1.4 `flutter analyze` y `flutter test` en verde, sin cambiar tests más allá de los imports

## 2. mpv

- [x] 2.1 `lib/terminal/mpv.dart`: buscar mpv, arrancarlo con su tubería, abrirla por `\\?\pipe\`, petición-respuesta con `request_id`, cerrar
- [x] 2.2 Cola: cargar la lista, insertar un archivo en una posición, siguiente, anterior, pausa, adelantar
- [x] 2.3 Test contra un mpv falso (el protocolo de líneas JSON, eventos que se ignoran, tubería rota)

## 3. Sesión y comandos

- [x] 3.1 `lib/terminal/config.dart`: el JSON escrito a mano, `rockola.json` junto al `.exe` o el de `%APPDATA%\Rockola`; sin token, pide la contraseña
- [x] 3.2 `bin/rockola.dart`: búsqueda con lista numerada, `mezclas`, `radio`; ayuda con `-h`
- [x] 3.3 Test: de los resultados de búsqueda a la cola (canción + resto del álbum, álbum, artista)

## 4. Pantalla "Suena"

- [x] 4.1 `lib/terminal/suena.dart` y `texto.dart`: buffer alterno, dibujo por cuadro, restaurar al salir y con Ctrl+C
- [x] 4.2 Barras de texto (Unicode con color y ASCII) como función pura `barras(bandas, ancho, alto, ascii)`, con test
- [x] 4.3 Letra: línea actual y siguiente con `letraDe` sin Flutter (Jellyfin, si no lrclib)
- [x] 4.4 Teclas y el tic de 50 ms (posición, índice, pausa); escuchas al empezar y terminar

## 5. Radio

- [x] 5.1 Hora de radio con `horaDeRadio`; entradas del locutor a `.ogg` temporal e insertadas en la cola; su texto en pantalla

## 5b. Interfaz (pedida después de probar los comandos)

- [x] 5b.1 `reproductor.dart`: lo de mpv sin pantalla ni teclas; `interfaz.dart`: secciones con pila de páginas, foco, buscador, reproductor abajo, `v` a pantalla completa
- [x] 5b.2 Configuración en JSON a mano (`rockola.json` junto al `.exe` o `%APPDATA%`), contraseña la primera vez
- [x] 5b.3 Vigía Lua en mpv: probado matando `rockola.exe`, mpv sale a los 6.1 s
- [x] 5b.4 Tests: teclas (flechas, ñ), `ajusta`, cada línea del ancho exacto en color y en ASCII, navegación

## 6. Cierre

- [x] 6.1 `flutter analyze`, `flutter test` y `dart build cli -t bin/rockola.dart` en verde
- [x] 6.2 Con Daniel en su terminal: búsqueda, mezcla y radio con canciones reales, visualizador con color y con `--ascii`
- [x] 6.3 `docs/terminal.md`: instalar mpv, compilar, configuración, comandos y teclas
