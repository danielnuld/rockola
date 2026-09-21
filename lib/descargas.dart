import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'jellyfin.dart';
import 'lrclib.dart';

/// El gestor de descargas. `null` en la web: ahi no se descarga, y la interfaz
/// se esconde mirando esto.
Descargas? descargas;

/// Reconstruye con cada cambio de las descargas; sin gestor, una sola vez.
Widget conDescargas(WidgetBuilder b) =>
    descargas == null ? Builder(builder: b) : ListenableBuilder(listenable: descargas!, builder: (c, _) => b(c));

/// Albumes descargados en `dir`, con un indice JSON al lado.
///
/// Entrada por album: sus datos, la calidad, la URL de la portada y, por cancion,
/// sus datos, la URL, el archivo y los bytes (0 = falta).
class Descargas extends ChangeNotifier {
  Descargas._(this.dir, this._http, this._hayWifi, this._prefs);

  final Directory dir;
  final http.Client _http;
  final Future<bool> Function() _hayWifi;
  final SharedPreferences? _prefs;

  var _indice = <String, Item>{};
  final _fallidos = <String>{};
  Future<void>? _trabajo;

  /// Sin Wi-Fi y con "solo con Wi-Fi": la cola espera.
  bool esperandoWifi = false;

  static Future<Descargas> abrir(Directory dir,
      {http.Client? cliente, Future<bool> Function()? hayWifi, SharedPreferences? prefs}) async {
    await dir.create(recursive: true);
    final d = Descargas._(dir, cliente ?? http.Client(), hayWifi ?? () async => true, prefs);
    final f = File('${dir.path}/descargas.json');
    if (await f.exists()) {
      d._indice = (jsonDecode(await f.readAsString()) as Map).cast<String, Item>();
      // El indice manda, pero una cancion sin su archivo vuelve a faltar.
      for (final id in d._indice.keys) {
        for (final p in d._pistas(id)) {
          if (p['bytes'] > 0 && !File(d._ruta(p['archivo'])).existsSync()) p['bytes'] = 0;
        }
      }
    }
    unawaited(d.reanudar());
    return d;
  }

  Calidad get calidad => Calidad.values.asNameMap()[_prefs?.getString('calidad')] ?? Calidad.normal;
  set calidad(Calidad c) {
    _prefs?.setString('calidad', c.name);
    notifyListeners();
  }

  bool get soloWifi => _prefs?.getBool('soloWifi') ?? true;
  set soloWifi(bool si) {
    _prefs?.setBool('soloWifi', si);
    notifyListeners();
    unawaited(reanudar());
  }

  String _ruta(String archivo) => '${dir.path}/$archivo';

  /// Las canciones de un album, con un solo tipo venga de memoria o del JSON.
  List<Item> _pistas(String albumId) => (_indice[albumId]?['pistas'] as List? ?? const []).cast<Item>();

  Item? entrada(String albumId) => _indice[albumId];
  bool completo(String albumId) => _indice.containsKey(albumId) && _pistas(albumId).every((p) => p['bytes'] > 0);

  /// (hechas, total) de un album pedido.
  (int, int)? avance(String albumId) {
    if (!_indice.containsKey(albumId)) return null;
    final pistas = _pistas(albumId);
    return (pistas.where((p) => p['bytes'] > 0).length, pistas.length);
  }

  Calidad calidadDe(String albumId) => Calidad.values.byName(_indice[albumId]!['calidad']);
  bool fallo(String albumId) => _fallidos.contains(albumId);

  int bytesDe(String albumId) => _pistas(albumId).fold(0, (s, p) => s + (p['bytes'] as int));
  int get usado => _indice.keys.fold(0, (s, id) => s + bytesDe(id));

  /// Los albumes completos, en el orden en que se pidieron.
  List<Item> get albumes => [for (final e in _indice.entries) if (completo(e.key)) e.value['album']];

  /// Archivo y calidad de una cancion descargada entera. La calidad sale de la
  /// entrada que la contiene: la cancion no siempre trae su AlbumId.
  ({String ruta, Calidad calidad})? archivo(String itemId) {
    for (final id in _indice.keys) {
      for (final p in _pistas(id)) {
        if (p['item']['Id'] == itemId && p['bytes'] > 0) return (ruta: _ruta(p['archivo']), calidad: calidadDe(id));
      }
    }
    return null;
  }

  String? portada(String albumId) {
    final f = _ruta('$albumId.jpg');
    return _indice.containsKey(albumId) && File(f).existsSync() ? f : null;
  }

  /// Pide un album con la calidad actual. Devuelve cuando la cola se vacia (o espera).
  Future<void> pedir(Jellyfin jf, Item album, List<Item> pistas) async {
    final c = calidad;
    _indice[album['Id']] = {
      // Type distingue una lista descargada de un album.
      'album': {for (final k in ['Id', 'Name', 'Type', 'AlbumArtist', 'ProductionYear', 'AlbumArtists']) k: album[k]},
      'calidad': c.name,
      'portada': jf.image(album['Id']),
      'pistas': [for (final t in pistas) _pista(jf, t, c)],
    };
    _fallidos.remove(album['Id']);
    await _guardar();
    notifyListeners();
    return reanudar();
  }

  static Item _pista(Jellyfin jf, Item t, Calidad c) {
    final (url, ext) = jf.descarga(t, c);
    return {
      'item': t,
      'url': url,
      'archivo': '${t['Id']}.$ext',
      'bytes': 0,
      // La letra viaja con la cancion para verla sin red: de Jellyfin si la
      // tiene, si no se busca en lrclib al descargar.
      if (t['HasLyrics'] == true)
        'letra': jf.urlLetra(t['Id'])
      else
        'buscarLetra': {
          'titulo': t['Name'],
          'artista': (t['Artists'] as List?)?.firstOrNull ?? t['AlbumArtist'],
          'album': t['Album'],
          'seg': t['RunTimeTicks'] == null ? null : (t['RunTimeTicks'] as int) ~/ 10000000,
        },
    };
  }

  /// La letra guardada de una cancion descargada, tal como la dio Jellyfin.
  String? letraGuardada(String itemId) {
    final f = File(_ruta('$itemId.letra.json'));
    return f.existsSync() ? f.readAsStringSync() : null;
  }

  Future<void> borrar(String albumId) async {
    final pistas = _pistas(albumId);
    if (_indice.remove(albumId) == null) return;
    for (final p in pistas) {
      await _borrarSiEsta(_ruta(p['archivo']));
      await _borrarSiEsta(_ruta('${p['archivo']}.parte'));
      await _borrarSiEsta(_ruta('${p['item']['Id']}.letra.json'));
    }
    await _borrarSiEsta(_ruta('$albumId.jpg'));
    await _guardar();
    notifyListeners();
  }

  /// Arranca la cola si no esta corriendo. Se llama al abrir, al pedir, al
  /// cambiar la conectividad y al cambiar "solo con Wi-Fi".
  Future<void> reanudar() {
    _fallidos.clear();
    return _trabajo ??= _trabajar().whenComplete(() => _trabajo = null);
  }

  // ponytail: descarga con la app abierta; iOS la suspende en segundo plano y se
  // retoma al volver. Si molesta, background_downloader (URLSession en segundo plano).
  Future<void> _trabajar() async {
    while (true) {
      final siguiente = _siguiente();
      if (siguiente == null) break;
      if (soloWifi && !await _hayWifi()) {
        esperandoWifi = true;
        notifyListeners();
        return;
      }
      esperandoWifi = false;
      final (albumId, p) = siguiente;
      try {
        await _portada(albumId);
        p['bytes'] = await _bajar(p['url'], _ruta(p['archivo']));
        await _guardarLetra(p);
        // Borrado mientras bajaba: el archivo recien llegado sobra.
        if (!_indice.containsKey(albumId)) await _borrarSiEsta(_ruta(p['archivo']));
        await _guardar();
      } catch (_) {
        // Se salta ese album en esta vuelta; el siguiente reanudar() lo reintenta.
        _fallidos.add(albumId);
      }
      notifyListeners();
    }
    esperandoWifi = false;
    notifyListeners();
  }

  /// Sin letra la cancion sigue descargada: un fallo aqui no es motivo de fallo.
  Future<void> _guardarLetra(Item p) async {
    final destino = _ruta('${p['item']['Id']}.letra.json');
    try {
      if (p['letra'] != null) {
        await _bajar(p['letra'], destino);
        return;
      }
      final b = p['buscarLetra'];
      if (b == null || b['titulo'] == null || b['artista'] == null) return;
      final l = await Lrclib(cliente: _http).buscar(
        titulo: b['titulo'],
        artista: b['artista'],
        album: b['album'],
        dura: b['seg'] == null ? null : Duration(seconds: b['seg']),
      );
      if (l != null && l.isNotEmpty) await File(destino).writeAsString(jsonEncode(comoJellyfin(l)));
    } catch (_) {}
  }

  (String, Item)? _siguiente() {
    for (final e in _indice.entries) {
      if (_fallidos.contains(e.key)) continue;
      for (final p in _pistas(e.key)) {
        if (p['bytes'] == 0) return (e.key, p);
      }
    }
    return null;
  }

  Future<void> _portada(String albumId) async {
    final f = _ruta('$albumId.jpg');
    if (File(f).existsSync()) return;
    try {
      await _bajar(_indice[albumId]!['portada'], f);
    } catch (_) {
      // Sin portada se ve el bloque de color: no vale la pena parar la musica.
    }
  }

  /// Baja a `.parte` y renombra al acabar: una a medias nunca parece terminada.
  Future<int> _bajar(String url, String ruta) async {
    final r = await _http.send(http.Request('GET', Uri.parse(url)));
    if (r.statusCode != 200) throw HttpException('Jellyfin respondio ${r.statusCode}', uri: Uri.parse(url));
    final parte = File('$ruta.parte');
    await r.stream.pipe(parte.openWrite());
    await parte.rename(ruta);
    return File(ruta).lengthSync();
  }

  /// Temporal y renombrado: un cierre a medias no deja el indice roto.
  Future<void> _guardar() async {
    final tmp = File('${dir.path}/descargas.json.tmp');
    await tmp.writeAsString(jsonEncode(_indice));
    await tmp.rename('${dir.path}/descargas.json');
  }

  static Future<void> _borrarSiEsta(String ruta) async {
    final f = File(ruta);
    if (await f.exists()) await f.delete();
  }
}
