import 'dart:convert';

import 'package:http/http.dart' as http;

typedef Item = Map<String, dynamic>;

/// Calidad de descarga. Las AAC las comprime Jellyfin en el servidor.
enum Calidad {
  original('Original', 'El archivo tal cual', 0),
  alta('Alta', 'AAC 256 kbps', 256000),
  normal('Normal', 'AAC 160 kbps', 160000),
  ahorro('Ahorro', 'AAC 96 kbps', 96000);

  const Calidad(this.nombre, this.detalle, this.bps);
  final String nombre, detalle;
  final int bps;
}

/// Lo que ocuparia toda la biblioteca. Medido: las AAC de Jellyfin quedan a 1–2 %
/// de la tasa nominal, asi que duracion × tasa basta.
int estimar(({int bytes, Duration dura}) total, Calidad c) =>
    c == Calidad.original ? total.bytes : total.dura.inSeconds * c.bps ~/ 8;

/// Unidades decimales, como las que da el sistema: "190 MB", "2.8 GB".
String tamano(int bytes) => bytes < 1e9 ? '${(bytes / 1e6).round()} MB' : '${(bytes / 1e9).toStringAsFixed(1)} GB';

class Jellyfin {
  Jellyfin(this.url, this.token, this.userId, {http.Client? cliente}) : _http = cliente ?? http.Client();

  final String url, token, userId;
  final http.Client _http;

  // ponytail: DeviceId fijo, con dos dispositivos del mismo usuario Jellyfin
  // cierra la sesion del otro. Generar uno por instalacion cuando pase.
  static const _auth =
      'MediaBrowser Client="Rockola", Device="iPhone", DeviceId="rockola", Version="0.1.0"';

  static Future<Jellyfin> login(String url, String user, String pass) async {
    url = url.trim().replaceAll(RegExp(r'/+$'), '');
    final r = await http.post(
      Uri.parse('$url/Users/AuthenticateByName'),
      headers: {'Authorization': _auth, 'Content-Type': 'application/json'},
      body: jsonEncode({'Username': user, 'Pw': pass}),
    );
    if (r.statusCode != 200) throw Exception('Jellyfin respondio ${r.statusCode}');
    final j = jsonDecode(r.body);
    return Jellyfin(url, j['AccessToken'], j['User']['Id']);
  }

  Map<String, String> get _cabeceras => {'Authorization': '$_auth, Token="$token"'};

  Future<dynamic> _get(String ruta, [Map<String, String>? query]) async {
    final r = await _http.get(Uri.parse('$url$ruta').replace(queryParameters: query), headers: _cabeceras);
    if (r.statusCode != 200) throw Exception('Jellyfin respondio ${r.statusCode}');
    return jsonDecode(r.body);
  }

  Future<List<Item>> _items(Map<String, String> query) async =>
      ((await _get('/Users/$userId/Items', query))['Items'] as List).cast<Item>();

  Future<List<Item>> albums() => _items({
        'IncludeItemTypes': 'MusicAlbum',
        'Recursive': 'true',
        'SortBy': 'SortName',
        'Fields': 'ProductionYear',
      });

  /// Un item suelto, con su UserData (favorito).
  Future<Item> item(String id) async => (await _get('/Users/$userId/Items/$id')) as Item;

  // TotalRecordCount viene en 0 aunque haya artistas: se cuenta la lista.
  Future<List<Item>> artistas() async =>
      ((await _get('/Artists/AlbumArtists', {'userId': userId, 'SortBy': 'SortName'}))['Items'] as List).cast<Item>();

  Future<List<Item>> albumesDe(String artistaId) => _items({
        'AlbumArtistIds': artistaId,
        'IncludeItemTypes': 'MusicAlbum',
        'Recursive': 'true',
        'SortBy': 'ProductionYear,SortName',
        'SortOrder': 'Descending',
      });

  /// Por /Search/Hints y no /Items?searchTerm: ese solo compara con el nombre del
  /// item, asi que "strokes" no encuentra nada de The Strokes.
  Future<List<Item>> buscar(String texto) async {
    final r = await _get('/Search/Hints', {
      'userId': userId,
      'searchTerm': texto,
      'includeItemTypes': 'MusicArtist,MusicAlbum,Audio',
      'limit': '40',
    });
    return [for (final Item h in r['SearchHints']) {...h, 'Id': h['Id'] ?? h['ItemId']}];
  }

  /// Marca o desmarca. Devuelve lo que quedo guardado.
  Future<bool> favorito(String id, bool si) async {
    final u = Uri.parse('$url/Users/$userId/FavoriteItems/$id');
    final r = await (si ? _http.post(u, headers: _cabeceras) : _http.delete(u, headers: _cabeceras));
    if (r.statusCode != 200) throw Exception('Jellyfin respondio ${r.statusCode}');
    return jsonDecode(r.body)['IsFavorite'] as bool;
  }

  Future<List<Item>> tracks(String albumId) => _items({
        'ParentId': albumId,
        'IncludeItemTypes': 'Audio',
        'Recursive': 'true',
        'SortBy': 'ParentIndexNumber,IndexNumber',
      });

  /// Las ultimas canciones escuchadas. Jellyfin guarda la fecha de reproduccion
  /// de canciones, no de albumes: los albumes salen de aqui.
  Future<List<Item>> recientes() => _items({
        'IncludeItemTypes': 'Audio',
        'Recursive': 'true',
        'SortBy': 'DatePlayed',
        'SortOrder': 'Descending',
        'Filters': 'IsPlayed',
        'Limit': '60',
      });

  /// Tamano original y duracion de toda la biblioteca, para estimar descargas.
  Future<({int bytes, Duration dura})> totales() async {
    final canciones = await _items({'IncludeItemTypes': 'Audio', 'Recursive': 'true', 'Fields': 'MediaSources'});
    var bytes = 0, ticks = 0;
    for (final c in canciones) {
      bytes += ((c['MediaSources'] as List?)?.firstOrNull?['Size'] as int?) ?? 0;
      ticks += (c['RunTimeTicks'] as int?) ?? 0;
    }
    return (bytes: bytes, dura: Duration(microseconds: ticks ~/ 10));
  }

  /// URL y extension de una descarga. La extension importa: AVPlayer reconoce el
  /// formato de un archivo local por ella.
  (String, String) descarga(Item cancion, Calidad c) {
    final id = cancion['Id'];
    if (c == Calidad.original) {
      final ext = '${cancion['Container'] ?? 'mp3'}'.split(',').first;
      return ('$url/Items/$id/Download?api_key=$token', ext);
    }
    // Container=m4a: fuerza la conversion salvo que el original ya sea AAC por
    // debajo de la tasa pedida.
    return (
      '$url/Audio/$id/universal?UserId=$userId&DeviceId=rockola&api_key=$token'
          '&MaxStreamingBitrate=${c.bps}&Container=m4a&TranscodingContainer=m4a'
          '&TranscodingProtocol=http&AudioCodec=aac',
      'm4a',
    );
  }

  String image(String id) => '$url/Items/$id/Images/Primary?maxHeight=400&api_key=$token';

  // El archivo tal cual. La version comprimida para descargas llega con las descargas.
  String stream(String id) => '$url/Audio/$id/stream?static=true&api_key=$token';
}
