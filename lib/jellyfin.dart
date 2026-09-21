import 'dart:convert';

import 'package:http/http.dart' as http;

typedef Item = Map<String, dynamic>;

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

  Future<List<Item>> _items(Map<String, String> query) async {
    final r = await _http.get(
      Uri.parse('$url/Users/$userId/Items').replace(queryParameters: query),
      headers: {'Authorization': '$_auth, Token="$token"'},
    );
    if (r.statusCode != 200) throw Exception('Jellyfin respondio ${r.statusCode}');
    return (jsonDecode(r.body)['Items'] as List).cast<Item>();
  }

  Future<List<Item>> albums() => _items({
        'IncludeItemTypes': 'MusicAlbum',
        'Recursive': 'true',
        'SortBy': 'SortName',
      });

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

  String image(String id) => '$url/Items/$id/Images/Primary?maxHeight=400&api_key=$token';

  // El archivo tal cual. La version comprimida para descargas llega con las descargas.
  String stream(String id) => '$url/Audio/$id/stream?static=true&api_key=$token';
}
