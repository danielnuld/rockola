## 1. Servicio de huellas

- [x] 1.1 `servidor/huellas.py`: `huella(archivo)` (el cálculo de la prueba), servidor con `GET /huella/{id}`, caché con el tamaño del archivo, CORS por lista, 127.0.0.1 + Tailscale, `--todas` y `--check` con un tono de 1 kHz
- [x] 1.2 `servidor/huellas.service` y `docs/huellas.md` (contrato y cómo montarlo)
- [x] 1.3 En `nuld`: `python3-numpy`, `--check`, instalar y arrancar el servicio (sudo: si queda bloqueado, lo corre Daniel)
- [x] 1.4 `--todas` sobre la biblioteca: tiempo, espacio y fallos
- [x] 1.5 Probar desde Windows por Tailscale: una huella, un 404 y el CORS

## 2. App: datos

- [x] 2.1 `Huella` (fps, bandas, bytes) y `cuadroEn(huella, posicion)` interpolado, con test
- [x] 2.2 `golpe(historial, actual)` puro para los graves, con test
- [x] 2.3 Cliente: pedir la huella al servidor configurado; sin red, la guardada con la descarga
- [x] 2.4 "Servidor de huellas" en Ajustes, guardado al escribir y con prueba

## 3. App: visualizador

- [x] 3.1 `lib/visualizador.dart`: pantalla completa, `Ticker`, bandas del cuadro actual (o patrón sintético), título y artista abajo, cerrar
- [x] 3.2 Barras, Ambiente, Batería y Ondas como `CustomPainter`; tocar cambia y muestra el nombre; el estilo se recuerda
- [x] 3.3 Botón "Visualizador" en el Reproductor
- [x] 3.4 Tests: se abre sin servidor (patrón sintético); tocar pasa de Barras a Ambiente y lo recuerda; con huella, las bandas del cuadro correcto; los cuatro painters pintan sin fallar

## 4. Sin conexión

- [x] 4.1 `Descargas` guarda `<id>.huella.json` con cada canción si hay servidor; test

## 5. Cierre

- [x] 5.1 `flutter analyze`, `flutter test` y `huellas.py --check` en verde
- [ ] 5.2 En Chrome con Daniel: los cuatro estilos con canciones reales, que se note el ritmo
- [ ] 5.3 IPA compilado
- [ ] 5.4 En el lienzo, el botón del visualizador y una pantalla del visualizador
