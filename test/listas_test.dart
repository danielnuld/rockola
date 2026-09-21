import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rockola/biblioteca.dart';
import 'package:rockola/descargas.dart';
import 'package:rockola/jellyfin.dart';
import 'package:rockola/listas.dart';
import 'package:rockola/player.dart';
import 'package:rockola/tema.dart';

import 'falso.dart';

void main() {
  setUpAll(() => player = BaseAudioHandler());
  late Falso f;
  setUp(() => f = Falso());

  Future<void> abrir(WidgetTester tester, Widget pagina) async {
    await tester.pumpWidget(MaterialApp(theme: tema, home: pagina));
    await tester.pumpAndSettle();
  }

  Future<void> tocar(WidgetTester tester, Finder donde) async {
    await tester.tap(donde);
    await tester.pumpAndSettle();
  }

  List<String> nombres(String lista) => [for (final e in f.listas[lista]!.entradas) e['Name'] as String];

  testWidgets('añadir una cancion a una lista nueva', (tester) async {
    await abrir(tester, AlbumPage(f.jf, const {'Id': 'a1', 'Name': 'Room on Fire'}));
    await tocar(tester, find.byTooltip('Más opciones de Reptilia'));
    await tocar(tester, find.text('Añadir a una lista'));
    await tocar(tester, find.text('Nueva lista…'));
    await tester.enterText(find.byType(TextField), 'Para correr');
    await tocar(tester, find.text('Crear'));

    expect(f.listas.values.single.nombre, 'Para correr');
    expect(nombres(f.listas.keys.single), ['Reptilia']);
    expect(find.text('Añadida a Para correr'), findsOneWidget);
  });

  testWidgets('añadir el album entero a una lista existente', (tester) async {
    final id = f.nuevaLista('Para correr', ['t3']);
    await abrir(tester, AlbumPage(f.jf, const {'Id': 'a1', 'Name': 'Room on Fire'}));
    await tocar(tester, find.byTooltip('Añadir el álbum a una lista'));
    await tocar(tester, find.text('Para correr'));

    expect(nombres(id), ['Automatic Stop', 'What Ever Happened?', 'Reptilia']);
    expect(find.text('Añadidas a Para correr'), findsOneWidget);
  });

  testWidgets('reordenar mueve la entrada correcta al sitio correcto', (tester) async {
    final id = f.nuevaLista('Mix', ['t1', 't2', 't3']);
    final entrada = f.listas[id]!.entradas[2]['PlaylistItemId'] as String;
    await abrir(tester, ListaPage(f.jf, {'Id': id, 'Name': 'Mix'}));

    tester.widget<ReorderableListView>(find.byType(ReorderableListView)).onReorderItem!(2, 0);
    await tester.pumpAndSettle();

    expect(f.movimientos, [(entrada, 0)]);
    expect(nombres(id), ['Automatic Stop', 'What Ever Happened?', 'Reptilia']);
    final titulos = tester.widgetList<ListTile>(find.byType(ListTile)).map((t) => (t.title as Text).data).toList();
    expect(titulos, ['Automatic Stop', 'What Ever Happened?', 'Reptilia']);
  });

  testWidgets('un quitar que falla vuelve a su sitio y avisa', (tester) async {
    final id = f.nuevaLista('Mix', ['t1', 't2']);
    await abrir(tester, ListaPage(f.jf, {'Id': id, 'Name': 'Mix'}));
    f.listasCaidas = true;
    await tocar(tester, find.byTooltip('Más opciones de Reptilia'));
    await tocar(tester, find.text('Quitar de la lista'));

    expect(find.text('Reptilia'), findsOneWidget);
    expect(find.text('No pude quitarla'), findsOneWidget);
    expect(nombres(id), ['What Ever Happened?', 'Reptilia']);
  });

  testWidgets('renombrar la lista', (tester) async {
    final id = f.nuevaLista('Mix', ['t1']);
    await abrir(tester, ListaPage(f.jf, {'Id': id, 'Name': 'Mix'}));
    await tocar(tester, find.byTooltip('Opciones de la lista'));
    await tocar(tester, find.text('Renombrar'));
    await tester.enterText(find.byType(TextField), 'Para correr');
    await tocar(tester, find.text('Guardar'));

    expect(f.listas[id]!.nombre, 'Para correr');
    expect(find.text('Para correr'), findsOneWidget);
  });

  testWidgets('borrar una lista la quita de la Biblioteca', (tester) async {
    f.nuevaLista('Mix', ['t1']);
    await abrir(tester, Biblioteca(f.jf, mezclas: Future.value(const [])));
    await tocar(tester, find.text('Listas'));
    expect(find.text('Lista · 1 canciones'), findsOneWidget);

    await tocar(tester, find.text('Mix'));
    await tocar(tester, find.byTooltip('Opciones de la lista'));
    await tocar(tester, find.text('Borrar lista'));
    await tocar(tester, find.text('Borrar'));

    expect(f.listas, isEmpty);
    expect(find.text('Todavía no tienes listas'), findsOneWidget);
  });

  testWidgets('una lista descargada se abre sin red', (tester) async {
    final id = f.nuevaLista('Mix', ['t1', 't2']);
    final dir = Directory.systemTemp.createTempSync('rockola');
    addTearDown(() {
      descargas = null;
      dir.deleteSync(recursive: true);
    });
    await tester.runAsync(() async {
      descargas = await Descargas.abrir(dir, cliente: MockClient((_) async => http.Response('audio', 200)));
      await descargas!.pedir(f.jf, {'Id': id, 'Name': 'Mix', 'Type': 'Playlist'}, await f.jf.cancionesDeLista(id));
    });
    final caido = Jellyfin('http://jf', 'tk', 'u', cliente: MockClient((_) async => http.Response('caído', 503)));
    await abrir(tester, ListaPage(caido, {'Id': id, 'Name': 'Mix'}));

    expect(find.text('Reptilia'), findsOneWidget);
    expect(find.byTooltip('Descargado. Quitar la descarga'), findsOneWidget);
  });
}
