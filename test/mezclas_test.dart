import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rockola/armazon.dart';
import 'package:rockola/jellyfin.dart';
import 'package:rockola/mezclas.dart';
import 'package:rockola/player.dart';
import 'package:rockola/tema.dart';

import 'falso.dart';

Item c(String id, String artista, {String genero = 'Rock', int anio = 2005, int escuchas = 0}) => {
      'Id': id,
      'Name': id,
      'AlbumArtist': artista,
      'Genres': [genero],
      'ProductionYear': anio,
      'UserData': {'PlayCount': escuchas},
    };

List<String> ids(Mezcla m) => [for (final x in m.canciones) x['Id'] as String];
Mezcla llamada(List<Mezcla> ms, String nombre) => ms.firstWhere((m) => m.nombre == nombre);

void main() {
  final hoy = DateTime(2026, 9, 21);
  setUpAll(() => player = BaseAudioHandler());

  test('familias: las variantes de rap son Rap, Pop Rap tambien, lo raro se queda', () {
    for (final g in ['Hip Hop', 'Rap/Hip Hop', 'Hip-Hop/Rap', 'Pop Rap', 'Gangsta Rap', 'Hispanic Hip Hop']) {
      expect(familia(g), 'Rap', reason: g);
    }
    expect(familia('Blues Rock'), 'Rock');
    expect(familia('Alternative'), 'Rock');
    expect(familia('Jazz'), 'Jazz');
  });

  test('sin historial: familias y decadas por tamaño, sin "Lo más tuyo"', () {
    final ms = mezclas(Falso.canciones, {}, hoy);
    expect(ms.map((m) => m.nombre), ['Mezcla de rock', 'Mezcla de rap', 'Dosmilera', 'Setentera', 'Lo que casi no tocas']);
    expect(ids(llamada(ms, 'Mezcla de rap')), everyElement(startsWith('h')));
  });

  test('con historial aparece "Lo más tuyo" del artista mas escuchado', () {
    final cs = [
      for (var i = 0; i < 8; i++) c('a$i', 'The Cranberries', escuchas: i < 3 ? 2 : 0),
      for (var i = 0; i < 8; i++) c('b$i', 'Fleetwood Mac', escuchas: i == 0 ? 1 : 0),
    ];
    final ms = mezclas(cs, {}, hoy);
    expect(ms.map((m) => m.nombre), contains('Lo más tuyo: The Cranberries'));
    expect(llamada(ms, 'Mezcla de rock').descripcion, contains('lo que más escuchas'));
  });

  test('tope de 3 por artista y sin dos seguidas del mismo', () {
    final cs = [
      for (var i = 0; i < 40; i++) c('s$i', 'The Strokes'),
      for (var i = 0; i < 10; i++) c('o$i', 'Otro $i'),
    ];
    final m = llamada(mezclas(cs, {}, hoy), 'Dosmilera');
    expect(ids(m).where((id) => id.startsWith('s')), hasLength(lessThanOrEqualTo(3)));
    final artistas = [for (final x in m.canciones) x['AlbumArtist']];
    for (var i = 1; i < artistas.length; i++) {
      expect(artistas[i], isNot(artistas[i - 1]));
    }
  });

  test('pocos artistas: el tope sube hasta llenar 25, alternando', () {
    final cs = [
      for (var i = 0; i < 20; i++) c('p$i', 'Post Malone', genero: 'Pop Rap'),
      for (var i = 0; i < 20; i++) c('k$i', 'Cartel de Santa', genero: 'Hip Hop'),
    ];
    final m = llamada(mezclas(cs, {}, hoy), 'Mezcla de rap');
    expect(m.canciones, hasLength(25));
    final artistas = [for (final x in m.canciones) x['AlbumArtist']];
    for (var i = 1; i < artistas.length; i++) {
      if (artistas[i] == artistas[i - 1]) {
        // Solo se repite al final, cuando del otro ya no quedan.
        expect(artistas.skip(i).toSet(), hasLength(1));
        break;
      }
    }
  });

  test('una cancion en dos discos sale una vez', () {
    final cs = [
      for (var i = 0; i < 8; i++) c('d$i', 'The Cranberries'),
      {...c('dreams1', 'The Cranberries'), 'Name': 'Dreams'},
      {...c('dreams2', 'The Cranberries'), 'Name': 'Dreams'},
    ];
    final m = llamada(mezclas(cs, {}, hoy), 'Mezcla de rock');
    expect(m.canciones.where((x) => x['Name'] == 'Dreams'), hasLength(1));
  });

  test('una saltada 3 veces y nunca escuchada no entra en ninguna', () {
    final ms = mezclas(Falso.canciones, {'r0': 3}, hoy);
    expect(ms.expand(ids), isNot(contains('r0')));
  });

  test('mismo dia mismas mezclas; otro dia, otras', () {
    final cs = [for (var i = 0; i < 60; i++) c('x$i', 'Artista ${i % 20}')];
    final a = mezclas(cs, {}, hoy), b = mezclas(cs, {}, hoy), otro = mezclas(cs, {}, hoy.add(const Duration(days: 1)));
    expect(a.map(ids), b.map(ids));
    expect(ids(a.first), isNot(ids(otro.first)));
  });

  testWidgets('Inicio muestra las mezclas y tocar una abre su pagina', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: tema, home: Armazon(Falso().jf)));
    await tester.pumpAndSettle();

    expect(find.text('Mezclas para ti'), findsOneWidget);
    await tester.tap(find.text('Mezcla de rock'));
    await tester.pumpAndSettle();
    expect(find.text('Rock de tu biblioteca'), findsOneWidget);
    expect(find.byTooltip('Reproducir mezcla'), findsOneWidget);
  });
}
