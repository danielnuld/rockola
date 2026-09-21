## 1. Contrato y cliente

- [x] 1.1 `docs/locutor.md`: `GET` y `POST /locutor`, campos, errores y qué hace Rockola si falla
- [x] 1.2 `Locutor(url)`: `nombre()` y `entrada(antes, despues, poca)` → `(texto, dataUri)`; errores como `null`
- [x] 1.3 `cancion()` añade año y escuchas a `extras`

## 2. Sesión de radio

- [x] 2.1 `horaDeRadio(mezclas, rumbo)`: 16 canciones por turnos, sin repetir; test
- [x] 2.2 `Player.insertQueueItem` con `insertAudioSource`
- [x] 2.3 `Radio`: arranca la cola, pide la entrada de apertura y la de cada tercera canción (sexta con poca charla) al empezar la anterior, inserta solo si llega a tiempo
- [x] 2.4 Tests con `BaseAudioHandler` y servidor falso: apertura, entrada antes de la cuarta, poca charla cada seis, servidor caído sin entradas, entrada tardía descartada

## 3. Ajustes

- [x] 3.1 `lib/ajustes.dart`: campo del servidor, guardar en `SharedPreferences`, probar con `GET` y mostrar el nombre o el error
- [x] 3.2 Accesos desde la radio y desde el lateral web

## 4. Pantalla

- [x] 4.1 Radio como **Web · Radio con locutora**: nombre y "HABLANDO", texto de la última entrada, "Sigue", "En la rotación", "Menos charla", "Cambiar el rumbo"; sin servidor, aviso con enlace a Ajustes
- [x] 4.2 Solo en la web; en iOS la pestaña sigue en su estado vacío
- [x] 4.3 Tarjeta de Rockola FM de Inicio → Radio; mini reproductor y barra con la locutora cuando habla
- [x] 4.4 Test de widget: la radio web con servidor falso muestra el texto de la entrada

## 5. Cierre

- [x] 5.1 `flutter analyze` y `flutter test` en verde
- [ ] 5.2 En Chrome contra Giulia real (tras `ruta-radio`): sintonizar, oír la apertura y una entrada entre canciones, "Menos charla", "Cambiar el rumbo", y apagar el servidor a mitad para ver que sigue la música
- [ ] 5.3 IPA compilado (en iOS no cambia nada visible)
- [ ] 5.4 Corregir en el lienzo lo que haya cambiado
