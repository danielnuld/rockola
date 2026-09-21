import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rockola/armazon.dart';
import 'package:rockola/inicio.dart';
import 'package:rockola/jellyfin.dart';
import 'package:rockola/player.dart';
import 'package:rockola/tema.dart';

import 'falso.dart';

Future<void> abrir(WidgetTester tester, Size tam) async {
  tester.view.physicalSize = tam;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: tema, home: Armazon(Falso().jf)));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => player = BaseAudioHandler());

  test('saludo segun la hora, en los bordes', () {
    String a(int h, int m) => saludo(DateTime(2026, 9, 21, h, m));
    expect(a(5, 59), 'Buenas noches');
    expect(a(6, 0), 'Buenos días');
    expect(a(11, 59), 'Buenos días');
    expect(a(12, 0), 'Buenas tardes');
    expect(a(18, 59), 'Buenas tardes');
    expect(a(19, 0), 'Buenas noches');
  });

  test('albumes recientes: en orden, sin repetir, sin album y con tope', () {
    Item c(String? album) => {'AlbumId': album, 'Album': 'Nombre $album'};
    final r = albumesRecientes([c('room'), c('rumours'), c('room'), c(null), c('parade')]);
    expect(r.map((a) => a['Id']), ['room', 'rumours', 'parade']);
    expect(r.first['Name'], 'Nombre room');
    expect(albumesRecientes([for (var i = 0; i < 10; i++) c('$i')]), hasLength(6));
  });

  testWidgets('cada pestaña guarda su recorrido', (tester) async {
    await abrir(tester, const Size(390, 844));

    await tester.tap(find.text('Biblioteca'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Room on Fire'));
    await tester.pumpAndSettle();
    expect(find.text('Reptilia'), findsOneWidget);

    await tester.tap(find.text('Inicio'));
    await tester.pumpAndSettle();
    expect(find.text('Reptilia'), findsNothing);

    await tester.tap(find.text('Biblioteca'));
    await tester.pumpAndSettle();
    expect(find.text('Reptilia'), findsOneWidget, reason: 'volver a la pestaña deja el album abierto');

    await tester.tap(find.text('Biblioteca'));
    await tester.pumpAndSettle();
    expect(find.text('Reptilia'), findsNothing, reason: 'tocar la pestaña activa vuelve al principio');
    expect(find.text('Tu biblioteca'), findsOneWidget);
  });

  testWidgets('Sintonizar lleva a la pestaña Radio', (tester) async {
    await abrir(tester, const Size(390, 844));
    await tester.tap(find.text('Sintonizar'));
    await tester.pumpAndSettle();
    expect(find.text('La radio con locutora llega pronto.'), findsOneWidget);
  });

  testWidgets('ancho: lateral y barra; estrecho: pestañas', (tester) async {
    await abrir(tester, const Size(1440, 900));
    expect(find.byType(Lateral), findsOneWidget);
    expect(find.byType(BarraAncha), findsOneWidget);
    expect(find.byType(Pestanas), findsNothing);

    await abrir(tester, const Size(390, 844));
    expect(find.byType(Lateral), findsNothing);
    expect(find.byType(Pestanas), findsOneWidget);
  });
}
