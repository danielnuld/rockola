import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rockola/descargas.dart';
import 'package:rockola/jellyfin.dart';
import 'package:rockola/letras.dart';
import 'package:rockola/lrclib.dart';
import 'package:rockola/player.dart';
import 'package:rockola/reproductor.dart';
import 'package:rockola/tema.dart';

import 'falso.dart';

/// Reproductor falso que apunta los saltos.
class ConSaltos extends BaseAudioHandler {
  final saltos = <Duration>[];

  @override
  Future<void> seek(Duration position) async => saltos.add(position);
}

MediaItem suena(String id, String titulo, {bool letra = true, String artista = 'The Strokes'}) => MediaItem(
      id: 'http://jf/$id',
      title: titulo,
      artist: artista,
      album: 'Room on Fire',
      duration: const Duration(seconds: 230),
      extras: {'itemId': id, 'albumId': 'a1', 'letra': letra},
    );

/// lrclib falso: la exacta no encuentra; la amplia trae dos candidatos.
Future<http.Response> respuestaLrclib(http.Request r) async {
  if (r.url.path.endsWith('/get')) return http.Response('{"statusCode":404}', 404);
  return http.Response(
        jsonEncode([
          {'artistName': 'Otro', 'duration': 230.0, 'syncedLyrics': '[00:01.00] De otro'},
          {'artistName': 'Cartel de Santa', 'duration': 226.0, 'syncedLyrics': '[00:02.00] Ya llegó\n[00:04.00] La Pelotona'},
        ]),
        200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

MockClient lrclibFalso({bool caido = false}) =>
    MockClient((r) async => caido ? http.Response('saturado', 503) : respuestaLrclib(r));

void main() {
  final h = ConSaltos();
  setUpAll(() => player = h);
  setUp(() => h.saltos.clear());

  test('lineaActual: antes, justo en un inicio, entre dos y despues', () {
    final l = <Linea>[(inicio: const Duration(seconds: 5), texto: 'a'), (inicio: const Duration(seconds: 10), texto: 'b')];
    expect(lineaActual(l, const Duration(seconds: 1)), -1);
    expect(lineaActual(l, const Duration(seconds: 5)), 0);
    expect(lineaActual(l, const Duration(seconds: 7)), 0);
    expect(lineaActual(l, const Duration(seconds: 99)), 1);
    expect(lineaActual(const [(inicio: null, texto: 'plana')], const Duration(seconds: 3)), -1);
  });

  test('LRC: varias marcas por linea, etiquetas fuera, en orden', () {
    final l = lineasDeLrc('[ar: Cartel]\n[00:12.34] Uno\n[00:05.00][00:20.00] Coro\n\n');
    expect([for (final x in l) (x.inicio!.inMilliseconds, x.texto)], [(5000, 'Coro'), (12340, 'Uno'), (20000, 'Coro')]);
    expect(lineasDeLrclib({'plainLyrics': 'a\nb'}).map((x) => x.inicio), [null, null]);
  });

  test('candidato: mismo artista, a 5 s como mucho, sincronizado primero', () {
    final c = [
      {'artistName': 'Otro', 'duration': 230.0, 'syncedLyrics': 'x'},
      {'artistName': 'cartel de santa', 'duration': 229.0, 'plainLyrics': 'plana'},
      {'artistName': 'Cartel de Santa', 'duration': 226.0, 'syncedLyrics': 's'},
      {'artistName': 'Cartel de Santa', 'duration': 200.0, 'syncedLyrics': 'lejos'},
    ];
    expect(mejorCandidato(c, 'Cartel de Santa', const Duration(seconds: 230))?['syncedLyrics'], 's');
    expect(mejorCandidato(c.sublist(0, 1), 'Cartel de Santa', const Duration(seconds: 230)), isNull);
    final vuelta = lineasDeLetra(comoJellyfin(lineasDeLrc('[00:02.50] hola')));
    expect((vuelta.single.inicio, vuelta.single.texto), (const Duration(milliseconds: 2500), 'hola'));
  });

  Future<void> abrirLetra(WidgetTester tester, Jellyfin jf, MediaItem m) async {
    h.mediaItem.add(m);
    await tester.pumpWidget(MaterialApp(theme: tema, home: Reproductor(jf)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Letra'));
    await tester.pumpAndSettle();
  }

  Color? color(WidgetTester tester, String texto) => tester.widget<Text>(find.text(texto)).style?.color;

  testWidgets('sincronizada: resalta la que suena y tocar una salta a su tiempo', (tester) async {
    await abrirLetra(tester, Falso().jf, suena('t2', 'Reptilia'));
    h.playbackState.add(PlaybackState(updatePosition: const Duration(seconds: 6)));
    await tester.pump(const Duration(milliseconds: 600));

    expect(color(tester, 'Dos'), coral);
    expect(color(tester, 'Uno'), textoApagado);
    expect(color(tester, 'Tres'), texto);

    await tester.tap(find.text('Tres'));
    expect(h.saltos, [const Duration(seconds: 10)]);
    await tester.pumpWidget(const SizedBox()); // corta el progreso periodico
  });

  testWidgets('plana: todas igual y tocar no salta', (tester) async {
    await abrirLetra(tester, Falso().jf, suena('t1', 'What Ever Happened?'));
    expect(color(tester, 'Plana uno'), texto);
    await tester.tap(find.text('Plana uno'));
    expect(h.saltos, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('sin letra en Jellyfin, la de lrclib del mismo artista', (tester) async {
    lrclib = Lrclib(cliente: lrclibFalso());
    await abrirLetra(tester, Falso().jf, suena('t9', 'La Pelotona', letra: false, artista: 'Cartel de Santa'));
    expect(find.text('La Pelotona'), findsWidgets);
    expect(find.text('Ya llegó'), findsOneWidget);
    expect(find.text('De otro'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('sin red, la letra guardada con la descarga', (tester) async {
    final dir = Directory.systemTemp.createTempSync('rockola');
    addTearDown(() {
      descargas = null;
      dir.deleteSync(recursive: true);
    });
    await tester.runAsync(() async {
      descargas = await Descargas.abrir(dir, cliente: lrclibFalso());
      File('${dir.path}/t8.letra.json').writeAsStringSync(jsonEncode(comoJellyfin(lineasDeLrc('[00:01.00] Guardada'))));
    });
    lrclib = Lrclib(cliente: lrclibFalso(caido: true));
    final caido = Jellyfin('http://jf', 'tk', 'u', cliente: MockClient((_) async => http.Response('caído', 503)));
    await abrirLetra(tester, caido, suena('t8', 'Otra', letra: true));
    expect(find.text('Guardada'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  test('la descarga guarda la letra de lrclib si Jellyfin no la tiene', () async {
    final dir = Directory.systemTemp.createTempSync('rockola');
    addTearDown(() => dir.deleteSync(recursive: true));
    // Audio y portada responden "audio"; lrclib, como el falso de arriba.
    final cliente = MockClient((r) async => r.url.host == 'lrclib.net' ? respuestaLrclib(r) : http.Response('audio', 200));
    final d = await Descargas.abrir(dir, cliente: cliente);
    await d.pedir(Falso().jf, {'Id': 'a9', 'Name': 'Vol. II'}, [
      {'Id': 't7', 'Name': 'La Pelotona', 'AlbumArtist': 'Cartel de Santa', 'RunTimeTicks': 2300000000, 'Container': 'mp3'},
    ]);
    expect(lineasDeLetra(jsonDecode(d.letraGuardada('t7')!)).map((l) => l.texto), ['Ya llegó', 'La Pelotona']);
  });
}
