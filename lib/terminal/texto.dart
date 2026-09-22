import 'dart:math';

/// Lo que se pinta en la pantalla "Suena" en un cuadro.
typedef Vista = ({
  String titulo,
  String detalle,
  Duration posicion,
  Duration? duracion,
  bool pausa,
  List<double> bandas,
  List<double> picos,
  String? linea,
  String? siguienteLinea,
  String? aviso,
});

const _bloques = ' ▁▂▃▄▅▆▇█';
const _ascii = ' .:+#';
const _esc = '\x1b[';

String _rgb(int r, int g, int b) => '${_esc}38;2;$r;$g;${b}m';
const _normal = '${_esc}0m';

/// Coral abajo, ambar arriba, como en la app.
String _colorFila(int fila, int alto) {
  final t = alto <= 1 ? 0.0 : fila / (alto - 1);
  int mezcla(int a, int b) => (a + (b - a) * t).round();
  return _rgb(mezcla(0xFF, 0xF5), mezcla(0x6B, 0xB8), mezcla(0x3D, 0x41));
}

/// Las bandas (0–1) como `alto` filas de texto, de arriba abajo. Cada banda ocupa
/// `anchoBanda` columnas y un espacio. `picos`, si hay, marca con una raya el
/// maximo reciente de cada banda.
List<String> barras(List<double> bandas, int anchoBanda, int alto, {List<double>? picos, bool ascii = false}) {
  final niveles = ascii ? _ascii : _bloques;
  final pasos = niveles.length - 1;
  final filas = <String>[];
  for (var fila = alto - 1; fila >= 0; fila--) {
    final sb = StringBuffer(ascii ? '' : _colorFila(fila, alto));
    for (var i = 0; i < bandas.length; i++) {
      final lleno = (bandas[i].clamp(0.0, 1.0) * alto - fila).clamp(0.0, 1.0);
      var c = niveles[(lleno * pasos).round()];
      final pico = picos == null ? -1 : min((picos[i].clamp(0.0, 1.0) * alto).floor(), alto - 1);
      if (c == ' ' && fila == pico && fila > 0) c = ascii ? '-' : '▔';
      sb
        ..write(c * anchoBanda)
        ..write(' ');
    }
    if (!ascii) sb.write(_normal);
    filas.add(sb.toString().trimRight());
  }
  return filas;
}

String tiempo(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

/// Una linea de progreso de `ancho` columnas con los tiempos al final.
String progreso(Duration pos, Duration? total, int ancho, {bool ascii = false}) {
  final tiempos = ' ${tiempo(pos)} / ${total == null ? '–:––' : tiempo(total)}';
  final barra = max(0, ancho - tiempos.length);
  final hecho = total == null || total.inMilliseconds == 0 ? 0 : (barra * pos.inMilliseconds / total.inMilliseconds).round().clamp(0, barra);
  return (ascii ? '=' * hecho + '-' * (barra - hecho) : '━' * hecho + '─' * (barra - hecho)) + tiempos;
}

/// El ancho visible de un texto, sin las secuencias de color.
int visible(String s) => s.replaceAll(RegExp('\x1b\\[[0-9;]*m'), '').runes.length;

String _corta(String s, int ancho) {
  final r = s.runes.toList();
  return r.length <= ancho ? s : '${String.fromCharCodes(r.take(max(0, ancho - 1)))}…';
}

const ayuda = 'v o Esc volver · espacio pausa · n/p pista · ←/→ 10 s · a ascii · q salir';

/// La pantalla entera, lista para escribir desde la esquina: cada linea borra lo
/// que quedaba a su derecha y al final se borra lo de abajo, sin parpadeo.
String pantalla(Vista v, int columnas, int filas, {bool ascii = false, bool conLetra = true}) {
  final ancho = max(20, columnas - 4);
  final altoBarras = (filas - 12).clamp(3, 14);
  final anchoBanda = max(1, (ancho - v.bandas.length + 1) ~/ v.bandas.length);
  String fuerte(String s) => ascii ? s : '${_esc}1m$s$_normal';
  String suave(String s) => ascii ? s : '${_esc}2m$s$_normal';
  String coral(String s) => ascii ? s : '${_rgb(0xFF, 0x6B, 0x3D)}${_esc}1m$s$_normal';

  final lineas = <String>[
    '',
    fuerte(_corta('${v.pausa ? '‖ ' : ''}${v.titulo}', ancho)),
    suave(_corta(v.detalle, ancho)),
    '',
    ...barras(v.bandas, anchoBanda, altoBarras, picos: v.picos, ascii: ascii),
    '',
    progreso(v.posicion, v.duracion, ancho, ascii: ascii),
    '',
    if (conLetra) ...[
      // Lo que dice la locutora ocupa varias lineas; una de letra, una.
      if (v.linea == null) '' else for (final l in partir(v.linea!, ancho).take(3)) coral(l),
      v.siguienteLinea == null ? '' : suave(_corta(v.siguienteLinea!, ancho)),
    ],
    if (v.aviso != null) suave(_corta(v.aviso!, ancho)),
    '',
    suave(_corta(ayuda, ancho)),
  ];
  final sb = StringBuffer('${_esc}H');
  for (final l in lineas.take(filas)) {
    sb.write('  $l${_esc}K\n');
  }
  sb.write('${_esc}J');
  return sb.toString();
}

/// Un texto largo (lo que dice la locutora) partido en lineas de `ancho`.
List<String> partir(String texto, int ancho) {
  final lineas = <String>[];
  var actual = '';
  for (final p in texto.split(RegExp(r'\s+'))) {
    if (actual.isEmpty) {
      actual = p;
    } else if (actual.length + 1 + p.length <= ancho) {
      actual += ' $p';
    } else {
      lineas.add(actual);
      actual = p;
    }
  }
  if (actual.isNotEmpty) lineas.add(actual);
  return lineas;
}
