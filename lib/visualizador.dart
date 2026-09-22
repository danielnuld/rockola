import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'descargas.dart';
import 'huella.dart';
import 'player.dart';
import 'tema.dart';

/// El cliente del servidor de huellas; los tests ponen uno falso.
http.Client clienteHuellas = http.Client();

final _huellas = <String, Future<Huella?>>{};

/// La huella guardada con la descarga; si no, la del servidor de Ajustes. Null si
/// no hay ninguna: nunca falla.
Future<Huella?> huellaDe(MediaItem m) {
  final id = m.extras?['itemId'] as String?;
  if (id == null) return Future.value(); // la voz del locutor no tiene huella
  return _huellas[id] ??= () async {
    try {
      final guardada = descargas?.huellaGuardada(id);
      if (guardada != null) return Huella.deJson(jsonDecode(guardada));
      final url = _sinBarra((await SharedPreferences.getInstance()).getString('huellas') ?? '');
      if (url.isEmpty) throw 'sin servidor';
      final r = await clienteHuellas.get(Uri.parse('$url/huella/$id')).timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) throw 'respondio ${r.statusCode}';
      return Huella.deJson(jsonDecode(r.body));
    } catch (_) {
      _huellas.remove(id); // la proxima vez se reintenta: quiza ya hay servidor
      return null;
    }
  }();
}

/// Si en `url` hay un servidor de huellas. Una cancion que no existe da 404 con su
/// error en JSON: eso basta para saber que contesta el servicio correcto.
Future<bool> probarHuellas(String url) async {
  try {
    final r = await clienteHuellas.get(Uri.parse('${_sinBarra(url)}/huella/${'0' * 32}')).timeout(const Duration(seconds: 8));
    return r.statusCode == 200 || (r.statusCode == 404 && (jsonDecode(r.body) as Map).containsKey('error'));
  } catch (_) {
    return false;
  }
}

String _sinBarra(String url) => url.trim().replaceAll(RegExp(r'/+$'), '');

/// Lo que ve cada estilo en un fotograma. Los estilos lo escuchan para repintar.
class Cuadro extends ChangeNotifier {
  List<double> bandas = List.filled(16, 0);
  double t = 0;

  /// Cuenta de golpes de graves: un estilo sabe que hubo uno nuevo si cambio.
  int golpes = 0;

  double get graves => (bandas[0] + bandas[1] + bandas[2]) / 3;
  double energia(int desde, int hasta) => bandas.sublist(desde, hasta).reduce((a, b) => a + b) / (hasta - desde);

  void poner(List<double> b, double nt, {bool golpe = false}) {
    bandas = b;
    t = nt;
    if (golpe) golpes++;
    notifyListeners();
  }
}

/// Un estilo. Los que tienen estado (picos, chispas, ondas) lo avanzan con el
/// tiempo transcurrido desde el ultimo pintado, no por pintado: repintar sin un
/// cuadro nuevo no los adelanta.
abstract class Pintor extends CustomPainter {
  Pintor(this.c) : super(repaint: c);

  final Cuadro c;
  double? _t;
  int _golpes = 0;

  /// Segundos desde el ultimo pintado, y si hubo un golpe nuevo.
  (double, bool) avanzar() {
    final dt = _t == null ? 0.0 : (c.t - _t!).clamp(0.0, 0.1);
    _t = c.t;
    final g = c.golpes != _golpes;
    _golpes = c.golpes;
    return (dt, g);
  }

  @override
  bool shouldRepaint(Pintor old) => old != this;
}

/// Las 16 bandas en bloques, de coral a ambar, con picos que caen y su reflejo.
class Barras extends Pintor {
  Barras(super.c);

  final _picos = List<double>.filled(16, 0);

  @override
  void paint(Canvas canvas, Size size) {
    final (dt, _) = avanzar();
    final n = c.bandas.length;
    final ancho = min(size.width * 0.86, 900.0), izq = (size.width - ancho) / 2;
    final base = size.height * 0.66, alto = size.height * 0.5;
    final paso = ancho / n, barra = paso * 0.74;
    const bloque = 7.0, hueco = 2.5;
    final p = Paint();
    for (var i = 0; i < n; i++) {
      final v = c.bandas[i];
      _picos[i] = max(v, _picos[i] - dt * 0.45);
      final x = izq + i * paso + (paso - barra) / 2;
      final bloques = (v * alto / (bloque + hueco)).floor();
      for (var k = 0; k < bloques; k++) {
        final y = base - (k + 1) * (bloque + hueco);
        p.color = Color.lerp(coral, ambar, (k * (bloque + hueco)) / alto)!;
        canvas.drawRect(Rect.fromLTWH(x, y, barra, bloque), p);
        // Reflejo en el piso, cada vez mas tenue.
        p.color = p.color.withValues(alpha: 0.16 * (1 - k / max(bloques, 1)));
        canvas.drawRect(Rect.fromLTWH(x, base + hueco + k * (bloque + hueco), barra, bloque), p);
      }
      p.color = texto;
      canvas.drawRect(Rect.fromLTWH(x, base - _picos[i] * alto - bloque, barra, 3), p);
    }
  }
}

/// Una forma de color que respira y se deforma con las bandas, en tres capas que
/// giran en sentidos contrarios.
class Ambiente extends Pintor {
  Ambiente(super.c);

  @override
  void paint(Canvas canvas, Size size) {
    avanzar();
    final centro = size.center(Offset.zero);
    final r0 = min(size.width, size.height) * 0.26 * (1 + 0.04 * sin(c.t * 0.9));
    final brillo = c.energia(0, 16);
    canvas.drawCircle(
        centro,
        r0 * 2.4,
        Paint()
          ..shader = RadialGradient(colors: [coral.withValues(alpha: 0.10 + 0.25 * brillo), fondoProfundo.withValues(alpha: 0)])
              .createShader(Rect.fromCircle(center: centro, radius: r0 * 2.4)));
    const capas = [(barraMini, 1.25, 0.35), (coral, 1.0, 0.75), (ambar, 0.62, 0.85)];
    for (var k = 0; k < capas.length; k++) {
      final (color, escala, alfa) = capas[k];
      final giro = c.t * 0.12 * (k + 1) * (k.isEven ? 1 : -1);
      canvas.drawPath(
          forma(centro, r0 * escala, giro, c.bandas, c.t + k),
          Paint()
            ..color = color.withValues(alpha: alfa)
            ..maskFilter = k == 0 ? const MaskFilter.blur(BlurStyle.normal, 24) : null);
    }
  }
}

/// Un contorno cerrado y suave: el radio de cada angulo sale de las bandas, en
/// espejo para que cierre sin costura.
Path forma(Offset centro, double r0, double giro, List<double> bandas, double t, {int puntos = 72}) {
  final n = bandas.length;
  final pts = <Offset>[];
  for (var i = 0; i < puntos; i++) {
    var u = 2 * i / puntos;
    if (u > 1) u = 2 - u;
    final x = u * (n - 1), j = x.floor(), f = x - j;
    final v = bandas[j] * (1 - f) + bandas[min(j + 1, n - 1)] * f;
    final a = giro + 2 * pi * i / puntos;
    final r = r0 * (0.72 + 0.5 * v + 0.04 * sin(3 * a + t * 1.3));
    pts.add(centro + Offset(cos(a), sin(a)) * r);
  }
  // Curvas por los puntos medios: sin picos entre muestra y muestra.
  Offset medio(int i) => (pts[i % puntos] + pts[(i + 1) % puntos]) / 2;
  final path = Path()..moveTo(medio(0).dx, medio(0).dy);
  for (var i = 1; i <= puntos; i++) {
    final p = pts[i % puntos], m = medio(i);
    path.quadraticBezierTo(p.dx, p.dy, m.dx, m.dy);
  }
  return path..close();
}

/// Tres anillos que giran con graves, medios y agudos, y chispas en cada golpe.
class Bateria extends Pintor {
  Bateria(super.c);

  final _giros = [0.0, 0.0, 0.0];
  final _chispas = <({Offset pos, Offset vel, double vida})>[];
  final _azar = Random();

  @override
  void paint(Canvas canvas, Size size) {
    final (dt, g) = avanzar();
    final centro = size.center(Offset.zero);
    final r = min(size.width, size.height) * 0.4;
    final energias = [c.energia(0, 5), c.energia(5, 11), c.energia(11, 16)];
    const segmentos = 12;
    for (var k = 0; k < 3; k++) {
      final e = energias[k];
      _giros[k] += dt * (0.25 + 2.8 * e) * (k.isEven ? 1 : -1);
      final radio = r * (0.38 + 0.26 * k);
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3 + 11 * e
        ..color = Color.lerp(coral, ambar, k / 2)!.withValues(alpha: 0.35 + 0.65 * e);
      for (var s = 0; s < segmentos; s++) {
        canvas.drawArc(Rect.fromCircle(center: centro, radius: radio), _giros[k] + s * 2 * pi / segmentos, 2 * pi / segmentos * 0.55, false, p);
      }
    }
    canvas.drawCircle(centro, r * 0.14 * (1 + c.graves), Paint()..color = coral);
    if (g) {
      for (var i = 0; i < 16; i++) {
        final a = _azar.nextDouble() * 2 * pi, v = r * (0.8 + _azar.nextDouble() * 0.9);
        _chispas.add((pos: centro, vel: Offset(cos(a), sin(a)) * v, vida: 1.0));
      }
    }
    final p = Paint();
    for (var i = _chispas.length - 1; i >= 0; i--) {
      final ch = _chispas[i];
      final vida = ch.vida - dt * 1.1;
      if (vida <= 0) {
        _chispas.removeAt(i);
        continue;
      }
      _chispas[i] = (pos: ch.pos + ch.vel * dt, vel: ch.vel * 0.97, vida: vida);
      p.color = ambar.withValues(alpha: vida);
      canvas.drawCircle(_chispas[i].pos, 1.5 + 3 * vida, p);
    }
  }
}

/// Circulos que nacen del centro con cada golpe de graves y se desvanecen, sobre
/// un contorno fino que sigue a las bandas.
class Ondas extends Pintor {
  Ondas(super.c);

  final _ondas = <({double nace, double fuerza})>[];
  static const _dura = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final (_, g) = avanzar();
    final centro = size.center(Offset.zero);
    final r = min(size.width, size.height) * 0.5;
    if (g) _ondas.add((nace: c.t, fuerza: c.graves));
    _ondas.removeWhere((o) => c.t - o.nace > _dura);
    for (var i = 0; i < _ondas.length; i++) {
      final o = _ondas[i];
      final edad = (c.t - o.nace) / _dura;
      canvas.drawCircle(
          centro,
          r * 0.12 + r * 1.1 * edad,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = (2 + 8 * o.fuerza) * (1 - edad)
            ..color = (i.isEven ? coral : ambar).withValues(alpha: 1 - edad));
    }
    canvas.drawPath(
        forma(centro, r * 0.2, c.t * 0.2, c.bandas, c.t),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = texto.withValues(alpha: 0.7));
  }
}

final estilos = <(String, Pintor Function(Cuadro))>[
  ('Barras', Barras.new),
  ('Ambiente', Ambiente.new),
  ('Batería', Bateria.new),
  ('Ondas', Ondas.new),
];

Future<void> abrirVisualizador(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const Visualizador()));

/// La cancion que suena, a pantalla completa. Tocar cambia de estilo.
class Visualizador extends StatefulWidget {
  const Visualizador({super.key});

  @override
  State<Visualizador> createState() => _VisualizadorState();
}

class _VisualizadorState extends State<Visualizador> with SingleTickerProviderStateMixin {
  final _cuadro = Cuadro();
  late final _ticker = createTicker(_tic);
  late StreamSubscription<MediaItem?> _sub;
  var _estilo = 0;
  late Pintor _pintor = estilos[0].$2(_cuadro);
  String? _id;
  Huella? _huella;
  final _historial = <double>[];
  var _ultimoGolpe = -1.0;
  var _nombre = false;
  Timer? _ocultar;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      final e = p.getInt('visualizador') ?? 0;
      if (mounted && e != _estilo) setState(() => _poner(e));
    });
    _sub = player.mediaItem.listen(_cancion);
    _ticker.start();
  }

  void _cancion(MediaItem? m) {
    final id = m?.extras?['itemId'] as String?;
    if (id == _id) return;
    _id = id;
    _huella = null;
    if (m != null) huellaDe(m).then((h) => _id == id ? _huella = h : null);
  }

  void _tic(Duration pasado) {
    final t = pasado.inMicroseconds / 1e6;
    final h = _huella;
    // position ya extrapola con el reloj; en pausa no avanza y todo se queda quieto.
    final b = h == null ? sintetico(t) : cuadroEn(h, player.playbackState.value.position);
    final graves = (b[0] + b[1] + b[2]) / 3;
    final g = golpe(_historial, graves) && t - _ultimoGolpe > 0.2;
    if (g) _ultimoGolpe = t;
    _historial.add(graves);
    if (_historial.length > 24) _historial.removeAt(0); // ~0.4 s a 60 fps
    _cuadro.poner(b, t, golpe: g);
  }

  void _poner(int e) {
    _estilo = e % estilos.length;
    _pintor = estilos[_estilo].$2(_cuadro);
  }

  void _siguiente() {
    setState(() {
      _poner(_estilo + 1);
      _nombre = true;
    });
    _ocultar?.cancel();
    _ocultar = Timer(const Duration(milliseconds: 1200), () => mounted ? setState(() => _nombre = false) : null);
    SharedPreferences.getInstance().then((p) => p.setInt('visualizador', _estilo));
  }

  @override
  void dispose() {
    _ticker.dispose();
    _sub.cancel();
    _ocultar?.cancel();
    _cuadro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: fondoProfundo,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _siguiente,
          child: Stack(fit: StackFit.expand, children: [
            RepaintBoundary(child: CustomPaint(painter: _pintor)),
            SafeArea(
              child: Stack(children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    tooltip: 'Cerrar visualizador',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
                  ),
                ),
                Align(
                  alignment: const Alignment(0, -0.8),
                  child: AnimatedOpacity(
                    opacity: _nombre ? 1 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Text(estilos[_estilo].$1, style: const TextStyle(fontFamily: titulos, fontSize: 28, fontWeight: FontWeight.w700)),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: StreamBuilder<MediaItem?>(
                      stream: player.mediaItem,
                      builder: (context, snap) {
                        final m = snap.data;
                        if (m == null) return const SizedBox.shrink();
                        return Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, color: textoSuave)),
                          if (m.artist != null) Text(m.artist!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: textoApagado)),
                        ]);
                      },
                    ),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      );
}
