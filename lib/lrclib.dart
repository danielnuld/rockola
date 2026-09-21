import 'dart:convert';

import 'package:http/http.dart' as http;

import 'jellyfin.dart';

/// lrclib.net: letras libres, sin clave y con CORS abierto.
///
/// Rockola le pregunta directamente cuando Jellyfin no tiene la letra. El plugin
/// LrcLib de Jellyfin no encontraba nada (ni con busqueda estricta desactivada ni
/// como proveedor de la biblioteca), aunque lrclib si tenia las canciones: medido.
class Lrclib {
  Lrclib({http.Client? cliente}) : _http = cliente ?? http.Client();

  final http.Client _http;
  static const _base = 'https://lrclib.net/api';

  /// La letra de una cancion, o null si lrclib no la tiene. Si lrclib falla (le
  /// pasa: 503 cuando esta saturado) lanza, para no darla por "sin letra".
  Future<List<Linea>?> buscar({required String titulo, required String artista, String? album, Duration? dura}) async {
    final exacta = await _get('/get', {
      'track_name': titulo,
      'artist_name': artista,
      if (album != null && album.isNotEmpty) 'album_name': album,
      if (dura != null) 'duration': '${dura.inSeconds}',
    });
    if (exacta is Map) return lineasDeLrclib(exacta);
    // La exacta pide la duracion casi igual; la busqueda amplia no, y se elige.
    final candidatos = await _get('/search', {'track_name': titulo, 'artist_name': artista});
    final mejor = mejorCandidato(candidatos is List ? candidatos : const [], artista, dura);
    return mejor == null ? null : lineasDeLrclib(mejor);
  }

  /// El JSON de la respuesta, null en 404, y una excepcion en cualquier otro error.
  Future<Object?> _get(String ruta, Map<String, String> query) async {
    final r = await _http.get(Uri.parse('$_base$ruta').replace(queryParameters: query)).timeout(const Duration(seconds: 10));
    if (r.statusCode == 404) return null;
    if (r.statusCode != 200) throw Exception('lrclib respondio ${r.statusCode}');
    return jsonDecode(utf8.decode(r.bodyBytes));
  }
}

/// De los resultados de la busqueda amplia, el del mismo artista con la duracion
/// mas parecida (a 5 s como mucho, si se sabe), sincronizado si puede ser.
Map? mejorCandidato(List candidatos, String artista, Duration? dura) {
  double distancia(Map c) => dura == null ? 0 : ((c['duration'] as num? ?? 0) - dura.inMilliseconds / 1000).abs();
  final validos = [
    for (final Map c in candidatos)
      if ('${c['artistName']}'.toLowerCase() == artista.toLowerCase() &&
          c['instrumental'] != true &&
          (c['syncedLyrics'] != null || c['plainLyrics'] != null) &&
          distancia(c) <= 5)
        c,
  ]..sort((a, b) {
      final porSincronia = (b['syncedLyrics'] != null ? 1 : 0) - (a['syncedLyrics'] != null ? 1 : 0);
      return porSincronia != 0 ? porSincronia : distancia(a).compareTo(distancia(b));
    });
  return validos.firstOrNull;
}

/// Las lineas de una respuesta de lrclib: la sincronizada (formato LRC) si hay,
/// si no la letra plana sin tiempos. Instrumental: sin lineas.
List<Linea> lineasDeLrclib(Map d) {
  final lrc = d['syncedLyrics'] as String?;
  if (lrc != null && lrc.trim().isNotEmpty) return lineasDeLrc(lrc);
  final plana = d['plainLyrics'] as String?;
  if (plana == null) return const [];
  return [for (final l in plana.split('\n')) (inicio: null, texto: l.trim())];
}

/// LRC: "[mm:ss.xx] texto", a veces con varias marcas por linea. Las etiquetas
/// ([ar:], [ti:]...) no son lineas.
List<Linea> lineasDeLrc(String lrc) {
  final marca = RegExp(r'\[(\d+):(\d+(?:\.\d+)?)\]');
  final lineas = <Linea>[];
  for (final fila in lrc.split('\n')) {
    final marcas = marca.allMatches(fila).toList();
    if (marcas.isEmpty) continue;
    final texto = fila.substring(marcas.last.end).trim();
    for (final m in marcas) {
      final ms = (int.parse(m[1]!) * 60000 + double.parse(m[2]!) * 1000).round();
      lineas.add((inicio: Duration(milliseconds: ms), texto: texto));
    }
  }
  return lineas..sort((a, b) => a.inicio!.compareTo(b.inicio!));
}

/// Una letra en el formato de Jellyfin, para guardarla con la descarga igual
/// venga de donde venga.
Map<String, Object> comoJellyfin(List<Linea> lineas) => {
      'Lyrics': [
        for (final l in lineas) {'Text': l.texto, if (l.inicio != null) 'Start': l.inicio!.inMicroseconds * 10},
      ],
    };
