import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rockola/armazon.dart';
import 'package:rockola/biblioteca.dart';
import 'package:rockola/player.dart';
import 'package:rockola/tema.dart';

import 'falso.dart';

Future<Falso> abrirApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final f = Falso();
  await tester.pumpWidget(MaterialApp(theme: tema, home: Armazon(f.jf)));
  await tester.pumpAndSettle();
  return f;
}

void main() {
  setUpAll(() => player = BaseAudioHandler());

  test('porRecientes: historial primero, en su orden; el resto por nombre', () {
    final items = [
      {'Id': 'a2', 'Name': 'Rumours'},
      {'Id': 'a1', 'Name': 'Room on Fire'},
      {'Id': 'a3', 'Name': 'angles'},
      {'Id': 'a4', 'Name': 'Bayou Country'},
    ];
    final r = porRecientes(items, ['a1', 'x', 'a2', 'a1'], (a) => '${a['Id']}');
    expect(r.map((a) => a['Name']), ['Room on Fire', 'Rumours', 'angles', 'Bayou Country']);
  });

  test('lineaAlbum: con año, sin año y en singular', () {
    expect(lineaAlbum(2003, 11, const Duration(minutes: 33, seconds: 24)), 'Álbum · 2003 · 11 canciones · 33 min');
    expect(lineaAlbum(null, 1, const Duration(minutes: 3)), 'Álbum · 1 canción · 3 min');
  });

  test('repetir: nada, toda la cola, una, nada', () {
    var m = AudioServiceRepeatMode.none;
    final vistos = [for (var i = 0; i < 3; i++) m = siguienteRepeticion(m)];
    expect(vistos, [AudioServiceRepeatMode.all, AudioServiceRepeatMode.one, AudioServiceRepeatMode.none]);
  });

  testWidgets('Biblioteca: Artistas, un artista y sus álbumes', (tester) async {
    await abrirApp(tester);
    await tester.tap(find.text('Biblioteca'));
    await tester.pumpAndSettle();
    expect(find.text('2 álbumes'), findsOneWidget);

    await tester.tap(find.text('Artistas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('The Strokes'));
    await tester.pumpAndSettle();
    expect(find.text('Room on Fire'), findsOneWidget);
    expect(find.text('Álbum · 2003'), findsOneWidget);
  });

  testWidgets('Álbum: cabecera contada y favorito que vuelve atrás si falla', (tester) async {
    final f = Falso()..estadoFavorito = 500;
    await tester.pumpWidget(MaterialApp(theme: tema, home: AlbumPage(f.jf, const {'Id': 'a1', 'Name': 'Room on Fire'})));
    await tester.pumpAndSettle();
    expect(find.text('Álbum · 2003 · 2 canciones · 6 min'), findsOneWidget);

    await tester.tap(find.byTooltip('Marcar como favorito'));
    await tester.pump();
    expect(find.byTooltip('Quitar de favoritos'), findsOneWidget, reason: 'cambia al tocar');
    await tester.pumpAndSettle();
    expect(find.byTooltip('Marcar como favorito'), findsOneWidget, reason: 'vuelve atrás con el 500');
    expect(find.text('No pude guardar el favorito'), findsOneWidget);
  });

  testWidgets('Buscar: escribir rápido hace una consulta y agrupa', (tester) async {
    final f = await abrirApp(tester);
    await tester.tap(find.text('Buscar'));
    await tester.pumpAndSettle();

    for (var i = 1; i <= 'cartel'.length; i++) {
      await tester.enterText(find.byType(TextField), 'cartel'.substring(0, i));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(f.busquedas, ['cartel']);
    expect(find.text('Artistas'), findsOneWidget);
    expect(find.text('Cartel de Santa'), findsOneWidget);
    expect(find.text('Canciones'), findsOneWidget);
    expect(find.text('Álbumes'), findsNothing);
  });
}
