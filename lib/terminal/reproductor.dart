import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../huella.dart';
import '../jellyfin.dart';
import '../locutor.dart';
import '../lrclib.dart';
import 'mpv.dart';
import 'texto.dart';

/// Una entrada de la cola: una cancion de Jellyfin o la voz de la locutora.
typedef Entrada = ({Item? cancion, String? texto, String url});

Entrada deCancion(Jellyfin jf, Item c) => (cancion: c, texto: null, url: jf.stream('${c['Id']}'));

/// Lo que el locutor pide saber de una cancion de Jellyfin.
Cancion datosDeItem(Item c) => (
      titulo: '${c['Name']}',
      artista: ((c['Artists'] as List?)?.firstOrNull ?? c['AlbumArtist']) as String?,
      album: c['Album'] as String?,
      anio: c['ProductionYear'] as int?,
      escuchas: c['UserData']?['PlayCount'] as int?,
    );

/// La radio de la terminal: el locutor y cada cuantas canciones habla.
typedef Radio = ({Locutor locutor, String nombre, int cada});

/// Maneja mpv: la cola, las escuchas, la huella y la letra de lo que suena, y las
/// entradas de la locutora. No pinta ni lee teclas: eso es de la interfaz.
class Reproductor {
  Reproductor(this.jf, this.mpv, {this.huellas, http.Client? cliente}) : _http = cliente ?? http.Client();

  final Jellyfin jf;
  final Mpv mpv;
  final String? huellas;
  final http.Client _http;

  /// Espejo de la lista de mpv: mismo orden, mismos indices.
  var cola = <Entrada>[];
  Radio? radio;
  int? indice;
  var _pos = Duration.zero;
  var _t = 0.0;
  var _picos = List<double>.filled(16, 0);
  final _huellas = <String, Huella?>{};
  final _letras = <String, List<Linea>?>{};
  final _pedidas = <String>{};
  var _entradas = 0;

  /// Sube con cada cola nueva: una entrada pedida para la anterior no se mete aqui.
  var _generacion = 0;
  String? aviso;

  Entrada? get actual => indice == null || indice! >= cola.length ? null : cola[indice!];

  /// Pone a sonar una cola nueva desde `desde`; con `radio`, la locutora habla.
  Future<void> tocar(List<Entrada> nueva, {int desde = 0, Radio? radio}) async {
    _termina();
    _generacion++;
    _pedidas.clear();
    _entradas = 0;
    aviso = null;
    this.radio = radio;
    cola = [...nueva];
    indice = null;
    await mpv.cargar([for (final e in cola) e.url], desde: desde);
  }

  Future<void> pausa() => mpv.pausa();
  Future<void> siguiente() => mpv.siguiente();
  Future<void> anterior() => mpv.anterior();
  Future<void> adelantar(int s) => mpv.adelantar(s);
  Future<void> saltar(int i) => mpv.pedir(['set_property', 'playlist-pos', i]);

  /// Un tic: pregunta a mpv, atiende el cambio de cancion y devuelve lo que se
  /// pinta, o null si no suena nada. `t` son los segundos de la interfaz.
  Future<Vista?> tic(double t) async {
    final e = await mpv.estado();
    final dt = min(0.1, max(0.0, t - _t));
    _t = t;
    if (e.indice != indice) _cambio(e.indice);
    _pos = e.posicion ?? Duration.zero;
    final entrada = actual;
    if (entrada == null || e.parado) return null;
    final c = entrada.cancion;
    final id = '${c?['Id']}';
    final h = c == null ? null : _huellas[id];
    final bandas = h == null ? sintetico(t) : cuadroEn(h, _pos);
    // Picos que caen despacio, como en las Barras de la app.
    _picos = [for (var k = 0; k < bandas.length; k++) max(bandas[k], (k < _picos.length ? _picos[k] : 0) - dt * 0.45)];
    String? linea, siguiente;
    if (entrada.texto != null) {
      linea = entrada.texto;
    } else if (_letras[id] case final l? when l.isNotEmpty) {
      // Sin marcas de tiempo no hay linea actual: se muestran las dos primeras.
      final j = l.first.inicio == null ? 0 : lineaActual(l, _pos);
      linea = j >= 0 ? l[j].texto : null;
      siguiente = j + 1 < l.length ? l[j + 1].texto : null;
    }
    return (
      titulo: c == null ? '${radio?.nombre ?? 'La locutora'} habla' : '${c['Name']}',
      detalle: c == null
          ? 'Rockola FM'
          : [((c['Artists'] as List?)?.join(', ') ?? c['AlbumArtist']), c['Album']].whereType<String>().join(' — '),
      posicion: _pos,
      duracion: e.duracion,
      pausa: e.pausa,
      bandas: bandas,
      picos: _picos,
      linea: linea,
      siguienteLinea: siguiente,
      aviso: aviso,
    );
  }

  /// Al salir: cuenta la escucha a medias, cierra mpv y borra las voces.
  Future<void> cerrar() async {
    _termina();
    await mpv.cerrar();
    try {
      if (carpetaVoces.existsSync()) await carpetaVoces.delete(recursive: true);
    } catch (_) {}
  }

  void _termina() {
    final c = actual?.cancion;
    if (c != null) unawaited(jf.termina('${c['Id']}', _pos).catchError((_) {}));
  }

  /// Empieza otra entrada: escuchas, su huella y su letra, y la radio pide lo que
  /// dira antes de la cancion que toca.
  void _cambio(int? i) {
    _termina();
    indice = i;
    final c = actual?.cancion;
    if (c == null) return;
    final id = '${c['Id']}';
    unawaited(jf.empieza(id).catchError((_) {}));
    if (!_huellas.containsKey(id)) {
      _huellas[id] = null;
      unawaited(_huella(id).then((h) => _huellas[id] = h));
    }
    if (!_letras.containsKey(id)) {
      _letras[id] = null;
      unawaited(_letra(c).then((l) => _letras[id] = l));
    }
    _radio(i!);
  }

  Future<Huella?> _huella(String id) async {
    if (huellas == null) return null;
    try {
      final r = await _http.get(Uri.parse('$huellas/huella/$id')).timeout(const Duration(seconds: 15));
      return r.statusCode == 200 ? Huella.deJson(jsonDecode(r.body)) : null;
    } catch (_) {
      return null;
    }
  }

  /// La de Jellyfin si la tiene; si no, lrclib, como la app.
  Future<List<Linea>?> _letra(Item c) async {
    try {
      final l = await jf.letra('${c['Id']}');
      if (l != null && l.isNotEmpty) return l;
    } catch (_) {}
    final d = datosDeItem(c);
    if (d.artista == null) return null;
    try {
      final ticks = c['RunTimeTicks'] as int?;
      return await Lrclib(cliente: _http)
          .buscar(titulo: d.titulo, artista: d.artista!, album: d.album, dura: ticks == null ? null : Duration(microseconds: ticks ~/ 10));
    } catch (_) {
      return null;
    }
  }

  /// Al empezar la cancion k de la hora, si la siguiente toca con entrada, se pide
  /// ya: asi tiene toda la cancion k para llegar.
  void _radio(int i) {
    final r = radio;
    if (r == null) return;
    final canciones = [for (final e in cola) if (e.cancion != null) e];
    final k = canciones.indexOf(cola[i]);
    if (k < 0 || k + 1 >= canciones.length || (k + 1) % r.cada != 0) return;
    final despues = canciones[k + 1];
    if (!_pedidas.add('${despues.cancion!['Id']}')) return;
    unawaited(_entrada(r, cola[i].cancion!, despues));
  }

  Future<void> _entrada(Radio r, Item antes, Entrada despues) async {
    final generacion = _generacion;
    // Un dato una entrada si y otra no, como en la web.
    final e = await r.locutor.entrada(datosDeItem(antes), datosDeItem(despues.cancion!), dato: _entradas++ % 2 == 0);
    if (generacion != _generacion) return;
    aviso = e == null ? '${r.nombre} no responde: sigue la música' : null;
    if (e == null) return;
    final archivo = await guardarVoz(e.audio);
    final pos = cola.indexOf(despues);
    // Llego tarde: la cancion que debia presentar ya empezo.
    if (generacion != _generacion || pos <= (indice ?? 0)) return;
    await mpv.insertar(pos, archivo);
    cola.insert(pos, (cancion: null, texto: e.texto, url: archivo));
  }
}

/// Pregunta al locutor su nombre y la apertura. Null si no hay servidor o no
/// responde: la radio suena solo con musica.
Future<(Radio?, List<Entrada>)> sintonizar(String? url, List<Entrada> cola) async {
  if (url == null || cola.isEmpty) return (null, cola);
  final locutor = Locutor(url);
  final nombre = await locutor.nombre();
  if (nombre == null) return (null, cola);
  final radio = (locutor: locutor, nombre: nombre, cada: 3);
  // La apertura espera poco: mejor empezar sin locutor que con silencio.
  final e = await locutor.entrada(null, datosDeItem(cola.first.cancion!)).timeout(const Duration(seconds: 8), onTimeout: () => null);
  if (e == null) return (radio, cola);
  return (radio, [(cancion: null, texto: e.texto, url: await guardarVoz(e.audio)), ...cola]);
}

var _voces = 0;

/// Donde van las voces del locutor; se borra al salir.
final carpetaVoces = Directory('${Directory.systemTemp.path}${Platform.pathSeparator}rockola-$pid');

/// El audio del locutor llega como `data:` URI; mpv lo toma de un archivo.
Future<String> guardarVoz(String dataUri) async {
  await carpetaVoces.create(recursive: true);
  final coma = dataUri.indexOf(',');
  final ext = dataUri.startsWith('data:audio/mpeg') ? 'mp3' : 'ogg';
  final f = File('${carpetaVoces.path}${Platform.pathSeparator}voz-${++_voces}.$ext');
  await f.writeAsBytes(base64Decode(dataUri.substring(coma + 1)));
  return f.path;
}
