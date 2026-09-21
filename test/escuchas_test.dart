import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rockola/escuchas.dart';
import 'package:rockola/player.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'falso.dart';

MediaItem cancion(String id, int segundos) =>
    MediaItem(id: 'http://jf/$id', title: id, duration: Duration(seconds: segundos), extras: {'itemId': id});

void main() {
  final h = BaseAudioHandler();
  setUpAll(() => player = h);

  late Falso f;
  late SharedPreferences prefs;
  late Escuchas e;

  // Pausado a proposito: sin reproducir, la posicion no se extrapola con el reloj.
  void estado(int i, int segundos, {bool termino = false}) => h.playbackState.add(PlaybackState(
        queueIndex: i,
        updatePosition: Duration(seconds: segundos),
        processingState: termino ? AudioProcessingState.completed : AudioProcessingState.ready,
      ));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    f = Falso();
    h.playbackState.add(PlaybackState());
    h.queue.add([cancion('t1', 220), cancion('t2', 200), cancion('t3', 190), cancion('t4', 180)]);
    e = Escuchas(f.jf, prefs)..iniciar();
  });
  tearDown(() => e.cerrar());

  test('al cambiar de cancion avisa el fin con la posicion y el inicio de la nueva', () async {
    estado(0, 0);
    estado(0, 120);
    estado(1, 0);
    await pumpEventQueue();
    expect(f.avisos, containsAll(['inicio:t1', 'fin:t1@120', 'inicio:t2']));
    expect(e.saltos, isEmpty);
  });

  test('dejarla antes de 30 s es un salto', () async {
    estado(0, 0);
    estado(0, 12);
    estado(1, 0);
    await pumpEventQueue();
    expect(e.saltos, {'t1': 1});
  });

  test('repetir una: cada vuelta es un fin y un inicio', () async {
    estado(0, 0);
    estado(0, 219);
    estado(0, 1);
    estado(0, 219);
    estado(0, 0);
    await pumpEventQueue();
    expect(f.avisos.where((a) => a == 'fin:t1@219'), hasLength(2));
    expect(f.avisos.where((a) => a == 'inicio:t1'), hasLength(3));
  });

  test('fin de la cola avisa la ultima', () async {
    estado(3, 0);
    estado(3, 179);
    estado(3, 180, termino: true);
    await pumpEventQueue();
    expect(f.avisos, contains('fin:t4@179'));
  });

  test('sin red los fines esperan y salen en orden al volver', () async {
    f.sesionesCaidas = true;
    estado(0, 0);
    estado(0, 200);
    estado(1, 0);
    estado(1, 190);
    estado(2, 0);
    estado(2, 180);
    estado(3, 0);
    await pumpEventQueue();
    expect(f.avisos, isEmpty);
    expect(prefs.getStringList('fines'), hasLength(3));

    f.sesionesCaidas = false;
    await e.cerrar();
    e = Escuchas(f.jf, prefs)..iniciar(); // al abrir la app
    await pumpEventQueue();
    expect(f.avisos.where((a) => a.startsWith('fin:')), ['fin:t1@200', 'fin:t2@190', 'fin:t3@180']);
    expect(prefs.getStringList('fines'), isEmpty);
  });
}
