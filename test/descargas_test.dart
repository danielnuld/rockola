import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rockola/biblioteca.dart';
import 'package:rockola/descargas.dart';
import 'package:rockola/jellyfin.dart';
import 'package:rockola/player.dart';
import 'package:rockola/tema.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'falso.dart';

const album = {'Id': 'a1', 'Name': 'Room on Fire', 'AlbumArtist': 'The Strokes', 'ProductionYear': 2003};
const pistas = [
  {'Id': 't1', 'Name': 'What Ever Happened?', 'Container': 'flac'},
  {'Id': 't2', 'Name': 'Reptilia', 'Container': 'flac'},
];

/// Servidor de descargas: apunta cada peticion y deja romper la de t2.
class Servidor {
  final pedidas = <String>[];
  bool rompeT2 = false;

  late final cliente = MockClient((r) async {
    final u = r.url.toString();
    pedidas.add(u);
    if (rompeT2 && u.contains('/t2/')) return http.Response('no', 500);
    return http.Response(u.contains('/Images/') ? 'jpg' : 'audio de ${r.url.pathSegments[1]}', 200);
  });

  int veces(String id) => pedidas.where((u) => u.contains('/$id/')).length;
}

void main() {
  late Directory dir;
  final jf = Falso().jf;

  setUpAll(() => player = BaseAudioHandler());
  setUp(() => dir = Directory.systemTemp.createTempSync('rockola'));
  tearDown(() {
    descargas = null;
    dir.deleteSync(recursive: true);
  });

  test('estimar y tamano con las cifras medidas', () {
    const total = (bytes: 8160000000, dura: Duration(hours: 39));
    expect([for (final c in Calidad.values) tamano(estimar(total, c))], ['8.2 GB', '4.5 GB', '2.8 GB', '1.7 GB']);
    expect(tamano(190000000), '190 MB');
  });

  test('URLs: original con su extension, AAC comprimido por Jellyfin', () {
    expect(jf.descarga(pistas[0], Calidad.original), ('http://jf/Items/t1/Download?api_key=tk', 'flac'));
    final (url, ext) = jf.descarga(pistas[0], Calidad.normal);
    expect(ext, 'm4a');
    expect(url, contains('/Audio/t1/universal?'));
    expect(url, contains('MaxStreamingBitrate=160000'));
    expect(url, contains('AudioCodec=aac'));
  });

  test('con servidor de huellas, la huella viaja con la cancion y se borra con ella', () async {
    final s = Servidor();
    final sin = await Descargas.abrir(dir, cliente: s.cliente);
    await sin.pedir(jf, album, pistas);
    expect(s.pedidas.where((u) => u.contains('/huella/')), isEmpty, reason: 'sin servidor no se pide');
    await sin.borrar('a1');

    SharedPreferences.setMockInitialValues({'huellas': 'http://tu-servidor:8788/'});
    final d = await Descargas.abrir(dir, cliente: s.cliente, prefs: await SharedPreferences.getInstance());
    await d.pedir(jf, album, pistas);
    expect(s.pedidas, contains('http://tu-servidor:8788/huella/t2'));
    expect(d.huellaGuardada('t2'), 'audio de t2');
    await d.borrar('a1');
    expect(d.huellaGuardada('t2'), isNull);
  });

  test('baja un album entero y lo recuerda al volver a abrir', () async {
    final s = Servidor();
    final d = await Descargas.abrir(dir, cliente: s.cliente);
    await d.pedir(jf, album, pistas);

    expect(d.completo('a1'), isTrue);
    expect(File(d.archivo('t2')!.ruta).readAsStringSync(), 'audio de t2');
    expect(d.archivo('t2')!.ruta, endsWith('t2.m4a'), reason: 'Normal por defecto: AAC');
    expect(d.archivo('t2')!.calidad, Calidad.normal);
    expect(d.portada('a1'), isNotNull);
    expect(d.usado, 'audio de t1'.length + 'audio de t2'.length);

    final otra = await Descargas.abrir(dir, cliente: s.cliente);
    expect(otra.completo('a1'), isTrue);
    expect(otra.albumes.single['Name'], 'Room on Fire');
  });

  test('retoma un album a medias sin volver a bajar lo que ya tiene', () async {
    final s = Servidor()..rompeT2 = true;
    final d = await Descargas.abrir(dir, cliente: s.cliente);
    await d.pedir(jf, album, pistas);
    expect(d.completo('a1'), isFalse);
    expect(d.avance('a1'), (1, 2));
    expect(File('${dir.path}/t2.m4a').existsSync(), isFalse, reason: 'una a medias no parece terminada');

    s.rompeT2 = false;
    final otra = await Descargas.abrir(dir, cliente: s.cliente);
    await otra.reanudar();
    expect(otra.completo('a1'), isTrue);
    expect(s.veces('t1'), 1);
  });

  test('sin Wi-Fi espera y empieza al llegar', () async {
    var wifi = false;
    final s = Servidor();
    final d = await Descargas.abrir(dir, cliente: s.cliente, hayWifi: () async => wifi);
    await d.pedir(jf, album, pistas);
    expect(d.esperandoWifi, isTrue);
    expect(s.pedidas, isEmpty);

    wifi = true;
    await d.reanudar();
    expect(d.esperandoWifi, isFalse);
    expect(d.completo('a1'), isTrue);
  });

  test('borrar quita archivos, portada e indice', () async {
    final d = await Descargas.abrir(dir, cliente: Servidor().cliente);
    await d.pedir(jf, album, pistas);
    final archivo = d.archivo('t1')!.ruta;
    await d.borrar('a1');

    expect(File(archivo).existsSync(), isFalse);
    expect(File('${dir.path}/a1.jpg').existsSync(), isFalse);
    expect(d.entrada('a1'), isNull);
    expect(d.usado, 0);
  });

  testWidgets('sin red, un album descargado se abre con lo guardado', (tester) async {
    // Archivos de verdad: fuera del reloj falso de los tests de widget.
    await tester.runAsync(() async {
      descargas = await Descargas.abrir(dir, cliente: Servidor().cliente);
      await descargas!.pedir(jf, album, pistas);
    });
    final caido = Jellyfin('http://jf', 'tk', 'u', cliente: MockClient((_) async => http.Response('caído', 503)));
    await tester.pumpWidget(MaterialApp(theme: tema, home: AlbumPage(caido, const {'Id': 'a1', 'Name': 'Room on Fire'})));
    await tester.pumpAndSettle();

    expect(find.text('Reptilia'), findsOneWidget);
    expect(find.text('Álbum · 2003 · 2 canciones · 0 min'), findsOneWidget);
    expect(find.byTooltip('Descargado. Quitar la descarga'), findsOneWidget);
  });

  testWidgets('sin gestor, como en la web, no hay boton de descarga', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: tema, home: AlbumPage(Falso().jf, const {'Id': 'a1', 'Name': 'Room on Fire'})));
    await tester.pumpAndSettle();
    expect(find.text('Reptilia'), findsOneWidget);
    expect(find.byTooltip('Descargar álbum'), findsNothing);
  });
}
