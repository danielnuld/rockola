import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rockola/ajustes.dart';
import 'package:rockola/descargas.dart';
import 'package:rockola/huella.dart';
import 'package:rockola/player.dart';
import 'package:rockola/tema.dart';
import 'package:rockola/visualizador.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Quieto extends BaseAudioHandler {}

// Dos bandas, tres cuadros: 0, 100, 200 en la primera; al reves en la segunda.
final _chica = Huella(20, 2, Uint8List.fromList([0, 200, 100, 100, 200, 0]));

Map<String, Object> jsonDe(Huella h) => {'fps': h.fps, 'bandas': h.bandas, 'cuadros': h.cuadros, 'datos': base64Encode(h.datos)};

MediaItem suena(String id) => MediaItem(id: 'http://jf/$id', title: 'Reptilia', artist: 'The Strokes', extras: {'itemId': id});

/// Servidor de huellas falso que apunta lo que le piden.
class Huellas {
  final pedidos = <String>[];
  var caido = false;

  late final cliente = MockClient((r) async {
    pedidos.add(r.url.path);
    if (caido) return http.Response('no', 503);
    if (r.url.path.endsWith('0' * 32)) return http.Response('{"error": "Jellyfin no conoce esa cancion"}', 404);
    return http.Response(jsonEncode(jsonDe(_chica)), 200);
  });
}

void main() {
  final h = Quieto();
  setUpAll(() => player = h);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    descargas = null;
  });

  test('cuadroEn: interpola entre vecinos y no se sale de la cancion', () {
    // 46 ms: el centro de la primera ventana de FFT.
    const centro = Duration(microseconds: 46440);
    List<int> en(Duration d) => [for (final v in cuadroEn(_chica, d)) (v * 255).round()];
    expect(en(Duration.zero), [0, 200]);
    expect(en(centro), [0, 200]);
    expect(en(centro + const Duration(milliseconds: 25)), [50, 150]); // mitad entre 0 y 1
    expect(en(centro + const Duration(milliseconds: 100)), [200, 0]);
    expect(en(const Duration(minutes: 5)), [200, 0]);
  });

  test('golpe: una subida sobre la media reciente, y solo si es fuerte', () {
    expect(golpe([], 0.9), isFalse);
    expect(golpe([0.3, 0.3, 0.3], 0.6), isTrue);
    expect(golpe([0.5, 0.5], 0.6), isFalse, reason: 'sube poco');
    expect(golpe([0.1, 0.1], 0.4), isFalse, reason: 'sube mucho pero sigue bajo');
  });

  test('huellaDe: sin servidor no pide nada; del servidor; caido, reintenta', () async {
    final s = Huellas();
    clienteHuellas = s.cliente;
    expect(await huellaDe(suena('a1')), isNull);
    expect(s.pedidos, isEmpty);
    expect(await huellaDe(const MediaItem(id: 'data:audio/ogg;base64,eA==', title: 'Giulia')), isNull);

    SharedPreferences.setMockInitialValues({'huellas': 'http://nuld:8788/'});
    s.caido = true;
    expect(await huellaDe(suena('a1')), isNull);
    s.caido = false;
    final hu = await huellaDe(suena('a1'));
    expect(hu?.cuadros, 3);
    expect(s.pedidos, ['/huella/a1', '/huella/a1']);
    await huellaDe(suena('a1'));
    expect(s.pedidos, hasLength(2), reason: 'la segunda vez sale de memoria');
  });

  test('probarHuellas: el 404 con error es el servicio; lo demas no', () async {
    final s = Huellas();
    clienteHuellas = s.cliente;
    expect(await probarHuellas('http://nuld:8788'), isTrue);
    s.caido = true;
    expect(await probarHuellas('http://nuld:8788'), isFalse);
  });

  test('los cuatro estilos pintan, con golpes y sin ellos', () {
    for (final (nombre, crear) in estilos) {
      final c = Cuadro();
      final p = crear(c);
      for (var i = 0; i < 30; i++) {
        c.poner(sintetico(i / 60), i / 60, golpe: i % 10 == 0);
        p.paint(Canvas(PictureRecorder()), const Size(400, 800));
      }
      expect(c.golpes, 3, reason: nombre);
    }
  });

  testWidgets('sin servidor se abre y se mueve; tocar cambia y lo recuerda', (tester) async {
    h.mediaItem.add(suena('b1'));
    await tester.pumpWidget(MaterialApp(theme: tema, home: const Visualizador()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Reptilia'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(Visualizador));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Ambiente'), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getInt('visualizador'), 1);
    await tester.pump(const Duration(seconds: 2)); // el nombre se va
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('abre en el estilo recordado', (tester) async {
    SharedPreferences.setMockInitialValues({'visualizador': 3});
    h.mediaItem.add(suena('b1'));
    await tester.pumpWidget(MaterialApp(theme: tema, home: const Visualizador()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byType(Visualizador));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Barras'), findsOneWidget, reason: 'de Ondas se pasa a Barras');
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Ajustes guarda el servidor de huellas y lo prueba', (tester) async {
    final s = Huellas();
    clienteHuellas = s.cliente;
    await tester.pumpWidget(MaterialApp(theme: tema, home: const AjustesPage()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'http://100.102.40.65:8788');
    await tester.tap(find.text('Guardar y probar').last);
    await tester.pumpAndSettle();
    expect(find.text('Responde.'), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getString('huellas'), 'http://100.102.40.65:8788');
  });

  test('sin red, la huella guardada con la descarga', () async {
    final dir = await Directory.systemTemp.createTemp('huellas');
    addTearDown(() => dir.delete(recursive: true));
    File('${dir.path}/c1.huella.json').writeAsStringSync(jsonEncode(jsonDe(_chica)));
    descargas = await Descargas.abrir(dir);
    SharedPreferences.setMockInitialValues({'huellas': 'http://nuld:8788'});
    clienteHuellas = MockClient((_) async => throw const SocketException('sin red'));
    expect((await huellaDe(suena('c1')))?.cuadros, 3);
  });
}
