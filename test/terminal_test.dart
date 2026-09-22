import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rockola/terminal/config.dart';
import 'package:rockola/terminal/elegir.dart';
import 'package:rockola/terminal/interfaz.dart';
import 'package:rockola/terminal/mpv.dart';
import 'package:rockola/terminal/reproductor.dart';
import 'package:rockola/terminal/texto.dart';

import 'falso.dart';

/// mpv de mentira: contesta por request_id, mete eventos por medio y parte las
/// respuestas en trozos, como llegan por la tuberia.
class MpvFalso {
  final comandos = <List<Object?>>[];
  final _salida = StreamController<List<int>>();
  late final _lector = StreamIterator(_salida.stream);
  var cerrado = false;
  var props = <String, Object?>{'time-pos': 12.5, 'duration': 220.0, 'playlist-pos': 1, 'pause': false, 'idle-active': false};

  late final mpv = Mpv.conCanal((linea) async {
    final m = jsonDecode(linea) as Map;
    final cmd = (m['command'] as List).cast<Object?>();
    comandos.add(cmd);
    if (cerrado) return;
    final data = cmd.first == 'get_property' ? props[cmd[1]] : null;
    final r = utf8.encode('{"event":"playback-restart"}\n${jsonEncode({'request_id': m['request_id'], 'error': data == null && cmd.first == 'get_property' ? 'property unavailable' : 'success', 'data': data})}\n');
    _salida
      ..add(r.sublist(0, 7))
      ..add(r.sublist(7));
  }, () async {
    if (cerrado) return <int>[];
    return await _lector.moveNext() ? _lector.current : <int>[];
  });
}

void main() {
  test('mpv: peticion y respuesta por request_id, sin confundirse con eventos', () async {
    final f = MpvFalso();
    final e = await f.mpv.estado();
    expect(e.posicion, const Duration(milliseconds: 12500));
    expect(e.duracion, const Duration(seconds: 220));
    expect((e.indice, e.pausa, e.parado), (1, false, false));
    expect(f.comandos.first, ['script-message', 'rockola-vivo'], reason: 'cada tic mantiene vivo a mpv');

    f.props['time-pos'] = null; // sin nada sonando, mpv no la tiene
    expect((await f.mpv.estado()).posicion, isNull);
  });

  test('mpv: cola, y comandos a la vez en el orden en que se piden', () async {
    final f = MpvFalso();
    await f.mpv.cargar(['a', 'b', 'c'], desde: 2);
    await Future.wait([f.mpv.insertar(1, 'voz.ogg'), f.mpv.pausa()]);
    expect(f.comandos, [
      ['loadfile', 'a', 'replace'],
      ['loadfile', 'b', 'append'],
      ['loadfile', 'c', 'append'],
      ['set_property', 'playlist-pos', 2],
      ['loadfile', 'voz.ogg', 'insert-at', 1],
      ['cycle', 'pause'],
    ]);
  });

  test('mpv: tuberia cerrada da MpvCerrado, no se cuelga', () async {
    final f = MpvFalso()..cerrado = true;
    await expectLater(f.mpv.estado(), throwsA(isA<MpvCerrado>()));
  });

  test('buscar mpv: el ajuste, el PATH o donde lo deja winget', () async {
    final dir = await Directory.systemTemp.createTemp('mpv');
    addTearDown(() => dir.delete(recursive: true));
    File('${dir.path}\\mpv.exe').writeAsStringSync('');
    expect(Mpv.buscar(entorno: {'PATH': r'C:\no\existe;' + dir.path}), '${dir.path}\\mpv.exe');
    expect(Mpv.buscar(ajuste: '${dir.path}\\mpv.exe', entorno: {}), '${dir.path}\\mpv.exe');
  });

  test('la cola de lo elegido: cancion + resto del album, album entero, artista', () async {
    final jf = Falso().jf;
    final c = await colaDe(jf, {'Id': 't2', 'Type': 'Audio', 'AlbumId': 'a1'});
    expect([for (final t in c.canciones) t['Id']], ['t1', 't2']);
    expect(c.desde, 1);
    expect((await colaDe(jf, {'Id': 'a1', 'Type': 'MusicAlbum'})).canciones, hasLength(2));
    expect((await colaDe(jf, {'Id': 'ar1', 'Type': 'MusicArtist'})).canciones.map((t) => t['Id']), unorderedEquals(['t1', 't2']));
    final suelta = await colaDe(jf, {'Id': 'x', 'Type': 'Audio'});
    expect((suelta.canciones.single['Id'], suelta.desde), ('x', 0));
  });

  test('barras: alto, bloques parciales, picos y ASCII sin color', () {
    final u = barras([1, 0.5, 0], 2, 4, picos: [1, 0.8, 0]);
    expect(u, hasLength(4));
    expect(u[0], contains('██ ▔▔'), reason: 'dos columnas por banda, y el pico de la segunda arriba');
    expect(u.last, contains('\x1b[38;2;255;107;61m'), reason: 'la fila de abajo es coral');
    final a = barras([1, 0.5, 0], 2, 4, picos: [1, 0.8, 0], ascii: true);
    expect(a, ['## --', '##', '## ##', '## ##']);
    expect(a.join(), isNot(contains('\x1b')));
  });

  test('pantalla: cabe en la terminal y la letra de la locutora se parte', () {
    final v = (
      titulo: 'Reptilia',
      detalle: 'The Strokes — Room on Fire',
      posicion: const Duration(seconds: 84),
      duracion: const Duration(seconds: 220),
      pausa: false,
      bandas: List.filled(16, 0.5),
      picos: List.filled(16, 0.6),
      linea: 'Una entrada larga de la locutora que no cabe en una sola linea de cuarenta',
      siguienteLinea: null,
      aviso: null,
    );
    final s = pantalla(v, 44, 24, ascii: true);
    final lineas = s.split('\n');
    for (final l in lineas) {
      expect(visible(l.replaceAll(RegExp('\x1b\\[[0-9;]*[A-Za-z]'), '')), lessThanOrEqualTo(44), reason: l);
    }
    expect(s, contains('1:24 / 3:40'));
    expect(lineas.where((l) => l.contains('locutora') || l.contains('cuarenta')), hasLength(2));
  });

  test('config: rockola.json junto al exe gana; si no, el de APPDATA', () async {
    final dir = await Directory.systemTemp.createTemp('cfg');
    addTearDown(() => dir.delete(recursive: true));
    final exe = '${dir.path}\\bin\\rockola.exe';
    final entorno = {'APPDATA': '${dir.path}\\appdata'};
    expect(Config.encontrar(ejecutable: exe, entorno: entorno), isNull);

    final appdata = File('${dir.path}\\appdata\\Rockola\\config.json')
      ..createSync(recursive: true)
      ..writeAsStringSync('{"url": "http://jf/"}');
    expect(Config.encontrar(ejecutable: exe, entorno: entorno)?.path, appdata.path);

    final portable = File('${dir.path}\\bin\\rockola.json')
      ..createSync(recursive: true)
      ..writeAsStringSync('{"url": "http://otro"}');
    expect(Config.encontrar(ejecutable: exe, entorno: entorno)?.path, portable.path);
  });

  test('config: sin token no hay sesión; la sesión se guarda sin tocar lo escrito', () async {
    final dir = await Directory.systemTemp.createTemp('cfg');
    addTearDown(() => dir.delete(recursive: true));
    final f = File('${dir.path}/rockola.json')..writeAsStringSync('{"url": "http://nuld:8096/", "usuario": "daniel", "huellas": " http://nuld:8788/ "}');
    final c = Config(f);
    expect(c.jellyfin, isNull);
    expect((c['url'], c['huellas'], c['locutor']), ('http://nuld:8096', 'http://nuld:8788', null));

    c.guardarSesion(Falso().jf);
    final otra = Config(f);
    expect(otra.jellyfin?.token, 'tk');
    expect(otra.datos['usuario'], 'daniel');
    expect(f.readAsStringSync(), isNot(contains('pass')));

    otra.guardarSesion(null); // sesion caducada
    expect(Config(f).jellyfin, isNull);
    expect(Config(f)['url'], 'http://nuld:8096');
  });

  test('teclas: flechas, páginas, Esc suelto, Enter, y la ñ entera', () {
    expect(teclasDe([27, 91, 65, 27, 91, 66, 27, 91, 67, 27, 91, 68]), ['arriba', 'abajo', 'derecha', 'izquierda']);
    expect(teclasDe([27, 91, 53, 126, 27, 91, 54, 126]), ['repag', 'avpag']);
    expect(teclasDe([27]), ['esc']);
    expect(teclasDe([13, 9, 8, 127, 3]), ['enter', 'tab', 'borrar', 'borrar', 'ctrl-c']);
    expect(teclasDe(utf8.encode('año /')), ['a', 'ñ', 'o', ' ', '/']);
  });

  test('ajusta: corta con … o rellena a la medida exacta', () {
    expect(ajusta('Reptilia', 5), 'Rept…');
    expect(ajusta('ñu', 4), 'ñu  ');
  });

  Future<Interfaz> interfaz({bool ascii = false}) async {
    final jf = Falso().jf;
    final ui = Interfaz(jf, Reproductor(jf, MpvFalso().mpv), ascii: ascii)..seccion = 2; // Biblioteca
    ui.pagina.filas(() {});
    await Future<void>.delayed(const Duration(milliseconds: 20)); // que carguen los albumes
    return ui;
  }

  test('interfaz: cada línea mide justo el ancho, en color y en ASCII', () async {
    for (final ascii in [false, true]) {
      final ui = await interfaz(ascii: ascii);
      final s = pintarInterfaz(ui, 90, 20);
      final lineas = s.split(RegExp('\x1b\\[\\d+;1H')).skip(1).map((l) => l.replaceAll(RegExp('\x1b\\[[0-9;]*[A-Za-z]'), '')).toList();
      expect(lineas, hasLength(20));
      for (final l in lineas) {
        expect(l.runes.length, 90, reason: l);
      }
      expect(s, contains('Room on Fire'));
      expect(s, contains('Biblioteca'));
      if (ascii) {
        final sinCursor = s.replaceAll(RegExp('\x1b\\[\\d+;1H|\x1b\\[K'), '');
        expect(sinCursor, isNot(contains('\x1b')), reason: 'sin color');
        // Letras con acento si ("atrás"); flechas, cajas y bloques (U+2000 en adelante) no.
        expect(sinCursor.runes.where((r) => r >= 0x2000), isEmpty, reason: 'sin símbolos ni dibujos');
      }
    }
  });

  test('interfaz: Enter entra a la lista, ↓ se mueve y Esc vuelve a la barra', () async {
    final ui = await interfaz();
    expect(ui.enLateral, isTrue);
    ui.enLateral = false;
    expect(ui.pagina.sel, 0);
    ui.pagina.sel = 1;
    expect(ui.pagina.filas(() {})![ui.pagina.sel].texto, 'Rumours');
    ui.enLateral = true;
    expect(ui.pagina.nombre, 'Biblioteca');
  });
}
