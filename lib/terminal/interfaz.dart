import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../jellyfin.dart';
import '../locutor.dart';
import '../mezclas.dart';
import 'consola.dart';
import 'elegir.dart';
import 'mpv.dart';
import 'reproductor.dart';
import 'texto.dart';

/// Una fila de una lista: lo que se ve y lo que pasa con Enter. Sin accion es un
/// titulo de seccion (o un aviso) y el cursor se la salta.
typedef Fila = ({String texto, String? detalle, FutureOr<void> Function()? accion});

Fila titulo(String t) => (texto: t, detalle: null, accion: null);

/// Una pagina de la columna central. Las que cargan de Jellyfin guardan lo
/// cargado; las "vivas" (la cola, la radio) se recalculan en cada cuadro.
class Pagina {
  Pagina(this.nombre, Future<List<Fila>> Function() cargar)
      : _cargar = cargar,
        _viva = null;
  Pagina.viva(this.nombre, List<Fila> Function() filas)
      : _viva = filas,
        _cargar = null;

  final String nombre;
  final Future<List<Fila>> Function()? _cargar;
  final List<Fila> Function()? _viva;
  List<Fila>? _filas;
  Object? error;
  var _pedida = false;
  var sel = 0;
  var desde = 0;

  /// Las filas, o null mientras cargan. Pide cargar la primera vez.
  List<Fila>? filas(void Function() listo) {
    if (_viva != null) return _viva();
    if (!_pedida) {
      _pedida = true;
      _cargar!().then((f) {
        _filas = f;
      }, onError: (Object e) {
        error = e;
      }).whenComplete(listo);
    }
    return _filas;
  }

  /// Vuelve a pedir las filas (la busqueda cambio).
  void recargar() {
    _pedida = false;
    _filas = null;
    error = null;
    sel = 0;
    desde = 0;
  }
}

/// Tiempo de una cancion de Jellyfin, "3:41".
String duracionDe(Item t) {
  final ticks = t['RunTimeTicks'] as int?;
  return ticks == null ? '' : tiempo(Duration(microseconds: ticks ~/ 10));
}

const _secciones = ['Inicio', 'Buscar', 'Biblioteca', 'Mezclas', 'Listas', 'Radio', 'Cola'];
const _lateral = 18;
const _esc = '\x1b[';
const _normal = '${_esc}0m';

/// La interfaz de la terminal, como la web: barra lateral, lista en el centro y el
/// reproductor abajo. `v` pone el visualizador a pantalla completa.
class Interfaz {
  Interfaz(this.jf, this.rep, {this.locutor, this.ascii = false});

  final Jellyfin jf;
  final Reproductor rep;
  final String? locutor;
  bool ascii;

  var seccion = 0;
  var enLateral = true;
  var visual = false;
  String? buscando; // texto que se escribe en Buscar; null si no se esta escribiendo
  var consulta = '';
  Vista? ahora;
  String? mensaje;
  var _rumbo = 0;
  String _estadoRadio = 'Enter para sintonizar.';
  Timer? _borrarMensaje;
  final _fin = Completer<void>();
  final _reloj = Stopwatch()..start();
  var _ocupado = false;

  late final Future<List<Mezcla>> _mezclas = jf.canciones().then((c) => mezclas(c, const {}, DateTime.now()));
  late final List<List<Pagina>> _pilas = [for (final s in _secciones) [_raiz(s)]];

  Pagina get pagina => _pilas[seccion].last;

  // ---------- paginas ----------

  Pagina _raiz(String s) => switch (s) {
        'Inicio' => Pagina('Inicio', () async {
            final (m, recientes) = (await _mezclas, await jf.recientes());
            final albumes = <String, Item>{};
            for (final c in recientes) {
              if (c['AlbumId'] != null) albumes.putIfAbsent('${c['AlbumId']}', () => c);
            }
            return [
              titulo('Mezclas para ti'),
              for (final x in m) (texto: x.nombre, detalle: artistasDe(x), accion: () => _abrir(_pistas(x.nombre, () async => x.canciones))),
              titulo(''),
              titulo('Volver a escuchar'),
              for (final c in albumes.values.take(8))
                (texto: '${c['Album']}', detalle: '${c['AlbumArtist'] ?? ''}', accion: () => _abrirAlbum('${c['AlbumId']}', '${c['Album']}')),
            ];
          }),
        'Buscar' => Pagina('Buscar', () async {
            if (consulta.isEmpty) return [titulo('Escribe con / y Enter.')];
            final r = await jf.buscar(consulta);
            if (r.isEmpty) return [titulo('Nada con «$consulta».')];
            return [for (final x in r) (texto: describir(x), detalle: null, accion: () => _tocarResultado(x))];
          }),
        'Biblioteca' => Pagina('Biblioteca', () async => [
              for (final a in await jf.albums())
                (texto: '${a['Name']}', detalle: '${a['AlbumArtist'] ?? ''}', accion: () => _abrirAlbum('${a['Id']}', '${a['Name']}')),
            ]),
        'Mezclas' => Pagina('Mezclas del día', () async => [
              for (final x in await _mezclas) (texto: x.nombre, detalle: x.descripcion, accion: () => _abrir(_pistas(x.nombre, () async => x.canciones))),
            ]),
        'Listas' => Pagina('Listas', () async => [
              for (final l in await jf.listas())
                (texto: '${l['Name']}', detalle: null, accion: () => _abrir(_pistas('${l['Name']}', () => jf.cancionesDeLista('${l['Id']}')))),
            ]),
        'Radio' => Pagina.viva('Radio', () => [
              (texto: '▶ Sintonizar', detalle: null, accion: () => _sintonizar()),
              (texto: '↻ Cambiar el rumbo', detalle: 'otras canciones de las mezclas', accion: () => _sintonizar(otroRumbo: true)),
              titulo(''),
              titulo(_estadoRadio),
            ]),
        _ => Pagina.viva('Cola', () => [
              if (rep.cola.isEmpty) titulo('No suena nada.'),
              for (var i = 0; i < rep.cola.length; i++)
                (
                  texto: '${i == rep.indice ? '▶ ' : '  '}${rep.cola[i].cancion?['Name'] ?? 'La locutora habla'}',
                  detalle: rep.cola[i].cancion == null ? null : duracionDe(rep.cola[i].cancion!),
                  accion: () => rep.saltar(i),
                ),
            ]),
      };

  Pagina _pistas(String nombre, Future<List<Item>> Function() canciones) {
    late List<Item> todas;
    return Pagina(nombre, () async {
      todas = await canciones();
      return [
        for (var i = 0; i < todas.length; i++)
          (
            texto: '${todas[i]['Name']}',
            detalle: [((todas[i]['Artists'] as List?)?.join(', ') ?? todas[i]['AlbumArtist']), duracionDe(todas[i])].whereType<String>().join('  '),
            accion: () => _tocar(todas, i),
          ),
      ];
    });
  }

  void _abrirAlbum(String id, String nombre) => _abrir(_pistas(nombre, () => jf.tracks(id)));

  void _abrir(Pagina p) {
    _pilas[seccion].add(p);
    enLateral = false;
  }

  Future<void> _tocar(List<Item> canciones, int desde) async {
    await rep.tocar([for (final c in canciones) deCancion(jf, c)], desde: desde);
    _avisar('Suena ${canciones[desde]['Name']}');
  }

  Future<void> _tocarResultado(Item r) async {
    if (r['Type'] == 'MusicAlbum') return _abrirAlbum('${r['Id']}', '${r['Name']}');
    final c = await colaDe(jf, r);
    if (c.canciones.isNotEmpty) await _tocar(c.canciones, c.desde);
  }

  Future<void> _sintonizar({bool otroRumbo = false}) async {
    if (otroRumbo) _rumbo++;
    _estadoRadio = 'Sintonizando…';
    final hora = horaDeRadio(await _mezclas, _rumbo);
    if (hora.isEmpty) {
      _estadoRadio = 'No hay mezclas para armar la radio.';
      return;
    }
    final (radio, cola) = await sintonizar(locutor, [for (final c in hora) deCancion(jf, c)]);
    await rep.tocar(cola, radio: radio);
    _estadoRadio = radio != null
        ? 'En el aire, con ${radio.nombre}.'
        : locutor == null
            ? 'Sin "locutor" en la configuración: solo música.'
            : 'El locutor no responde: solo música.';
  }

  void _avisar(String m) {
    mensaje = m;
    _borrarMensaje?.cancel();
    _borrarMensaje = Timer(const Duration(seconds: 3), () => mensaje = null);
  }

  // ---------- bucle ----------

  /// Corre hasta `q`. `inicial` elige seccion y, si hay, busca o sintoniza.
  Future<void> correr({String? buscar, bool radio = false, bool mezclasDelDia = false}) async {
    final consola = stdin.hasTerminal;
    StreamSubscription<List<int>>? teclas;
    StreamSubscription<ProcessSignal>? ctrlC;
    Timer? tic;
    int? modo;
    try {
      if (consola) {
        stdin
          ..echoMode = false
          ..lineMode = false;
        // Despues de lineMode: Dart pone su propio modo al cambiarlo.
        modo = activarTeclasVT();
      }
      stdout.write('\x1b[?1049h\x1b[?25l'); // pantalla alterna, sin cursor
      teclas = stdin.listen(_tecla);
      ctrlC = ProcessSignal.sigint.watch().listen((_) => _salir());
      if (buscar != null) {
        seccion = 1;
        consulta = buscar;
        enLateral = false;
      } else if (radio) {
        seccion = 5;
        enLateral = false;
        unawaited(_accion(_sintonizar));
      } else if (mezclasDelDia) {
        seccion = 3;
        enLateral = false;
      }
      tic = Timer.periodic(const Duration(milliseconds: 50), (_) => _tic());
      await _fin.future;
    } finally {
      tic?.cancel();
      _borrarMensaje?.cancel();
      await teclas?.cancel();
      await ctrlC?.cancel();
      await rep.cerrar();
      stdout.write('\x1b[?25h\x1b[?1049l'); // la terminal como estaba
      if (consola) {
        restaurarConsola(modo);
        stdin
          ..lineMode = true
          ..echoMode = true;
      }
    }
  }

  void _salir([Object? error]) {
    if (_fin.isCompleted) return;
    error == null ? _fin.complete() : _fin.completeError(error);
  }

  Future<void> _tic() async {
    if (_ocupado || _fin.isCompleted) return;
    _ocupado = true;
    try {
      ahora = await rep.tic(_reloj.elapsedMicroseconds / 1e6);
      _pintar();
    } on MpvCerrado catch (e) {
      _salir(e);
    } finally {
      _ocupado = false;
    }
  }

  /// Una accion de Enter: los errores se avisan abajo, no rompen la interfaz.
  Future<void> _accion(FutureOr<void> Function() f) async {
    try {
      await f();
    } on MpvCerrado catch (e) {
      _salir(e);
    } catch (e) {
      _avisar('No se pudo: $e');
    }
  }

  void _tecla(List<int> bytes) {
    final escribiendo = buscando != null;
    for (final t in teclasDe(bytes)) {
      if (escribiendo && buscando != null) {
        _escribir(t);
        continue;
      }
      switch (t) {
        case 'q' || 'ctrl-c':
          return _salir();
        case ' ':
          unawaited(_accion(rep.pausa));
        case 'n':
          unawaited(_accion(rep.siguiente));
        case 'p':
          unawaited(_accion(rep.anterior));
        case 'derecha':
          unawaited(_accion(() => rep.adelantar(10)));
        case 'izquierda':
          unawaited(_accion(() => rep.adelantar(-10)));
        case 'v':
          visual = !visual;
        case 'a':
          ascii = !ascii;
        case 'esc' when visual:
          visual = false;
        case '/':
          seccion = 1;
          _pilas[1].removeRange(1, _pilas[1].length);
          enLateral = false;
          visual = false;
          buscando = consulta;
        case 'tab':
          enLateral = !enLateral;
        case 'arriba' || 'k':
          _mover(-1);
        case 'abajo' || 'j':
          _mover(1);
        case 'repag':
          _mover(-10);
        case 'avpag':
          _mover(10);
        case 'enter':
          _enter();
        case 'esc' || 'borrar':
          _atras();
      }
    }
    _pintar();
  }

  void _escribir(String t) {
    switch (t) {
      case 'enter':
        consulta = buscando!.trim();
        buscando = null;
        _pilas[1].first.recargar();
      case 'esc' || 'ctrl-c':
        buscando = null;
      case 'borrar':
        final r = buscando!.runes.toList();
        if (r.isNotEmpty) buscando = String.fromCharCodes(r.take(r.length - 1));
      default:
        if (t.runes.length == 1 && t.runes.first >= 32) buscando = buscando! + t;
    }
  }

  void _mover(int d) {
    if (enLateral) {
      seccion = (seccion + d.sign).clamp(0, _secciones.length - 1);
      return;
    }
    final f = pagina.filas(() {});
    if (f == null || f.isEmpty) return;
    // Solo las filas con accion: los titulos se saltan.
    final elegibles = [for (var i = 0; i < f.length; i++) if (f[i].accion != null) i];
    if (elegibles.isEmpty) return;
    final actual = elegibles.indexWhere((i) => i >= pagina.sel);
    final k = ((actual < 0 ? elegibles.length - 1 : actual) + d).clamp(0, elegibles.length - 1);
    pagina.sel = elegibles[k];
  }

  void _enter() {
    if (enLateral) {
      enLateral = false;
      _mover(0);
      return;
    }
    final f = pagina.filas(() {});
    if (f == null || pagina.sel >= f.length) return;
    final a = f[pagina.sel].accion;
    if (a != null) unawaited(_accion(a));
  }

  void _atras() {
    if (visual) {
      visual = false;
    } else if (_pilas[seccion].length > 1) {
      _pilas[seccion].removeLast();
    } else {
      enLateral = true;
    }
  }

  // ---------- pintar ----------

  int get _columnas => stdout.hasTerminal ? stdout.terminalColumns : 100;
  int get _filas => stdout.hasTerminal ? stdout.terminalLines : 30;

  void _pintar() {
    if (_fin.isCompleted) return;
    final (w, h) = (max(50, _columnas), max(14, _filas));
    if (visual) {
      final v = ahora;
      stdout.write(v == null ? '${_esc}H${_esc}2J  No suena nada. (v para volver)' : pantalla(v, w, h, ascii: ascii));
      return;
    }
    stdout.write(pintarInterfaz(this, w, h));
  }
}

/// La pantalla entera de la interfaz como texto, lista para escribir. Aparte y
/// pura (salvo pedir las filas) para poder probarla.
String pintarInterfaz(Interfaz ui, int w, int h) {
  final ascii = ui.ascii;
  final b = ascii ? (h: '-', v: '|', a: '+', b: '+', c: '+', d: '+', t: '+', u: '+', i: '+', j: '+') : (h: '─', v: '│', a: '┌', b: '┐', c: '└', d: '┘', t: '┬', u: '┴', i: '├', j: '┤');
  String color(String s, String codigo) => ascii ? s : '$_esc${codigo}m$s$_normal';
  String coral(String s) => color(s, '1;38;2;255;107;61');
  String ambar(String s) => color(s, '1;38;2;245;184;65');
  String suave(String s) => color(s, '2');
  String fuerte(String s) => color(s, '1');
  // En ASCII no hay fondo de color: un * en la primera columna, sin mover nada.
  String elegida(String s) => ascii ? '*${s.substring(1)}' : '$_esc' '48;2;255;107;61;38;2;26;14;8m$s$_normal';

  final centro = w - _lateral - 3; // ancho de la columna central
  final alto = h - 5; // filas entre el borde de arriba y el reproductor
  final lineas = <String>[];

  // Borde de arriba con el nombre.
  final nombre = ' Rockola ';
  lineas.add(b.a + b.h + ambar(nombre) + b.h * (_lateral - nombre.length - 1) + b.t + b.h * centro + b.b);

  // Columna central: nombre de la pagina (con la pila) y sus filas.
  final p = ui.pagina;
  final filas = p.filas(ui._pintar);
  final pila = ui._pilas[ui.seccion].map((x) => x.nombre).join(' › ');
  final centroLineas = <String>[];
  if (ui.seccion == 1 && ui.buscando != null) {
    centroLineas.add(fuerte(ajusta(' Buscar: ${ui.buscando}▏', centro)));
  } else {
    centroLineas.add(fuerte(ajusta(' $pila', centro)));
  }
  centroLineas.add(' ' * centro);
  final visibles = alto - 2;
  if (filas == null) {
    centroLineas.add(suave(ajusta(p.error == null ? '  Cargando…' : '  No se pudo cargar: ${p.error}', centro)));
  } else {
    if (p.sel >= filas.length || (filas.isNotEmpty && filas[p.sel].accion == null)) {
      p.sel = filas.indexWhere((f) => f.accion != null).clamp(0, max(0, filas.length - 1));
    }
    if (p.sel < p.desde) p.desde = p.sel;
    if (p.sel >= p.desde + visibles) p.desde = p.sel - visibles + 1;
    for (var i = p.desde; i < min(filas.length, p.desde + visibles); i++) {
      final f = filas[i];
      if (f.accion == null) {
        centroLineas.add(ambar(ajusta(' ${f.texto}', centro)));
        continue;
      }
      final det = f.detalle ?? '';
      final izq = max(10, centro - 3 - (det.isEmpty ? 0 : min(det.runes.length, centro ~/ 2) + 2));
      final texto = '  ${ajusta(f.texto, izq)}${det.isEmpty ? '' : '  ${ajusta(det, centro - izq - 4)}'}';
      final linea = ajusta(texto, centro);
      final sel = i == p.sel;
      centroLineas.add(sel && !ui.enLateral ? elegida(linea) : sel ? coral(linea) : linea);
    }
  }

  // Filas del medio: barra lateral | centro.
  for (var i = 0; i < alto; i++) {
    final s = i < _secciones.length ? _secciones[i] : null;
    String lat;
    if (s == null) {
      lat = ' ' * _lateral;
    } else if (i == ui.seccion) {
      final t = ajusta(' ▸ $s', _lateral);
      lat = ui.enLateral ? elegida(t) : coral(t);
    } else {
      lat = ajusta('   $s', _lateral);
    }
    final c = i < centroLineas.length ? centroLineas[i] : ' ' * centro;
    lineas.add('${b.v}$lat${b.v}$c${b.v}');
  }
  lineas.add(b.i + b.h * _lateral + b.u + b.h * centro + b.j);

  // El reproductor: titulo, mini visualizador, tiempo; y la letra o el aviso.
  final interior = w - 2;
  final v = ui.ahora;
  if (v == null) {
    lineas.add(b.v + suave(ajusta(' Nada sonando.', interior)) + b.v);
    lineas.add(b.v + ajusta(ui.mensaje == null ? '' : ' ${ui.mensaje}', interior) + b.v);
  } else {
    final tiempos = ' ${tiempo(v.posicion)} / ${v.duracion == null ? '–:––' : tiempo(v.duracion!)} ';
    final mini = barras(v.bandas, 1, 1, ascii: ascii).first;
    // Lo que mide de verdad: con color, el espacio del final queda antes del reset.
    final miniAncho = visible(mini);
    final titulo = ajusta(' ${v.pausa ? '‖' : '▶'} ${v.titulo} · ${v.detalle}', max(10, interior - miniAncho - tiempos.length - 2));
    lineas.add('${b.v}${fuerte(titulo)}  $mini$tiempos${b.v}');
    final abajo = ui.mensaje ?? v.aviso ?? v.linea;
    final texto = abajo == null ? '' : ' ${abajo == v.linea ? '♪ ' : ''}$abajo';
    lineas.add(b.v + (abajo == v.linea ? coral(ajusta(texto, interior)) : suave(ajusta(texto, interior))) + b.v);
  }
  final ayuda = ui.buscando != null
      ? ' Enter buscar · Esc cancelar '
      : ' ↑↓ mover · Enter tocar · Tab panel · Esc atrás · / buscar · espacio pausa · n/p · ←→ 10 s · v visual · q salir ';
  final pie = ajusta(ayuda, interior);
  // El pie sobre el borde: los espacios del final se vuelven linea.
  final texto = pie.trimRight();
  lineas.add(b.c + suave(texto) + b.h * (interior - texto.runes.length) + b.d);

  // Cada linea en su fila: sin saltos de linea que puedan desplazar la pantalla.
  final sb = StringBuffer();
  for (var i = 0; i < min(h, lineas.length); i++) {
    sb.write('$_esc${i + 1};1H${ascii ? aAscii(lineas[i]) : lineas[i]}${_esc}K');
  }
  return sb.toString();
}

/// Los simbolos de la interfaz en ASCII, uno por uno para no mover columnas. Los
/// acentos de los nombres se quedan: esos los muestra cualquier consola.
String aAscii(String s) => s.replaceAllMapped(RegExp('[▸▶›‖·…—↑↓←→♪↻▏]'), (m) => const {
      '▸': '>', '▶': '>', '›': '>', '‖': '|', '·': '-', '…': '.', '—': '-',
      '↑': '^', '↓': 'v', '←': '<', '→': '>', '♪': '~', '↻': '@', '▏': '_',
    }[m[0]]!);

/// Un texto cortado o rellenado a `ancho` columnas exactas.
String ajusta(String s, int ancho) {
  if (ancho <= 0) return '';
  final r = s.runes.toList();
  if (r.length > ancho) return '${String.fromCharCodes(r.take(ancho - 1))}…';
  return s + ' ' * (ancho - r.length);
}

/// Las teclas de un trozo de la entrada: letras (UTF-8) y nombres para las
/// especiales. Las flechas llegan como secuencias VT.
List<String> teclasDe(List<int> bytes) {
  final r = <String>[];
  var i = 0;
  while (i < bytes.length) {
    final b = bytes[i];
    if (b == 27) {
      if (i + 2 < bytes.length && (bytes[i + 1] == 91 || bytes[i + 1] == 79)) {
        final f = bytes[i + 2];
        final nombre = switch (f) { 65 => 'arriba', 66 => 'abajo', 67 => 'derecha', 68 => 'izquierda', _ => null };
        if (nombre != null) {
          r.add(nombre);
          i += 3;
          continue;
        }
        // ESC [ 5 ~ y ESC [ 6 ~: RePág y AvPág.
        if ((f == 53 || f == 54) && i + 3 < bytes.length && bytes[i + 3] == 126) {
          r.add(f == 53 ? 'repag' : 'avpag');
          i += 4;
          continue;
        }
      }
      r.add('esc');
      i++;
      continue;
    }
    final especial = switch (b) { 13 || 10 => 'enter', 9 => 'tab', 8 || 127 => 'borrar', 3 => 'ctrl-c', _ => null };
    if (especial != null) {
      r.add(especial);
      i++;
      continue;
    }
    // Un caracter UTF-8 entero (la ñ y los acentos son dos bytes).
    final largo = b >= 0xF0 ? 4 : b >= 0xE0 ? 3 : b >= 0xC0 ? 2 : 1;
    r.add(utf8.decode(bytes.sublist(i, min(bytes.length, i + largo)), allowMalformed: true));
    i += largo;
  }
  return r;
}
