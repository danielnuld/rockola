## 1. Escuchas

- [x] 1.1 `Jellyfin.empieza(id)` y `Jellyfin.termina(id, posicion)` (`/Sessions/Playing` y `/Stopped`)
- [x] 1.2 `lib/escuchas.dart`: observador de `player` que manda fin e inicio al cambiar de canción, suma saltos (< 30 s sin terminar) y guarda y reintenta los fines fallidos en `SharedPreferences`
- [x] 1.3 Tests con `BaseAudioHandler` y Jellyfin falso: fin con la posición, salto a los 12 s, dos vueltas de la misma canción, tres fines sin red que salen al volver
- [ ] 1.4 Comprobar contra `nuld` con la sesión de Daniel: escuchar una canción entera dos veces en Chrome y ver su contador subir en dos. Si no sube, plan B de design.md

## 2. Algoritmo

- [x] 2.1 `familia(genero)` con la tabla de design.md, con test (las variantes de rap, "Pop Rap", "Blues Rock", uno que no encaja)
- [x] 2.2 `mezclas(canciones, saltos, fecha)`: tipos, pesos, tope por artista, separación de artistas y semilla por fecha
- [x] 2.3 Tests: sin historial (familias y décadas por tamaño, sin "Lo más tuyo"), con historial ("Lo más tuyo" del artista más escuchado), tope de 3 por artista, saltada 3 veces fuera, misma fecha mismas mezclas y otra fecha distintas

## 3. Interfaz

- [x] 3.1 `Jellyfin.canciones()` con géneros y año; el `Armazon` la pide una vez y la pasa
- [x] 3.2 "Mezclas para ti" en Inicio: fila de tarjetas con portada de cuatro álbumes en el teléfono, cuadrícula en la web; sin datos no se pinta
- [x] 3.3 Página de mezcla: portada, nombre, descripción, reproducir, aleatorio y lista
- [x] 3.4 Filtro Mezclas en la Biblioteca
- [x] 3.5 Test de widget: Inicio con un Jellyfin falso muestra las mezclas y tocar una abre su página

## 4. Cierre

- [x] 4.1 `flutter analyze` y `flutter test` en verde
- [x] 4.2 Comprobar en Chrome contra el Jellyfin real que las mezclas tienen sentido con la biblioteca de Daniel
- [ ] 4.3 IPA compilado
- [x] 4.4 Corregir en el lienzo los nombres y textos de las mezclas si cambiaron
