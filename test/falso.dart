import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rockola/jellyfin.dart';

/// Un Jellyfin de mentira con Room on Fire, Rumours y The Strokes.
/// Apunta lo que se busca y deja elegir cómo responde el favorito.
class Falso {
  final busquedas = <String>[];
  int estadoFavorito = 200;

  late final jf = Jellyfin('http://jf', 'tk', 'u', cliente: MockClient(_responder));

  static const _roomOnFire = {
    'Id': 'a1',
    'Name': 'Room on Fire',
    'AlbumArtist': 'The Strokes',
    'ProductionYear': 2003,
    'AlbumArtists': [{'Id': 'ar1', 'Name': 'The Strokes'}],
    'UserData': {'IsFavorite': false},
  };

  static http.Response _json(Object o) =>
      http.Response(jsonEncode(o), 200, headers: {'content-type': 'application/json; charset=utf-8'});

  Future<http.Response> _responder(http.Request r) async {
    final q = r.url.queryParameters;
    final ruta = r.url.path;
    if (ruta.startsWith('/Users/u/FavoriteItems/')) {
      // Una red de verdad tarda: deja ver el estado optimista antes de la respuesta.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return estadoFavorito == 200 ? _json({'IsFavorite': r.method == 'POST'}) : http.Response('no', estadoFavorito);
    }
    if (ruta == '/Search/Hints') {
      busquedas.add(q['searchTerm']!);
      return _json({
        'SearchHints': q['searchTerm'] == 'cartel'
            ? [
                {'Id': 'ar2', 'Name': 'Cartel de Santa', 'Type': 'MusicArtist'},
                {'Id': 't9', 'Name': 'La ranfla del Cartel', 'Type': 'Audio', 'AlbumId': 'a3', 'AlbumArtist': 'Cartel de Santa'},
              ]
            : [],
      });
    }
    if (ruta == '/Artists/AlbumArtists') {
      return _json({'Items': [{'Id': 'ar1', 'Name': 'The Strokes'}], 'TotalRecordCount': 0});
    }
    if (ruta == '/Users/u/Items/a1') return _json(_roomOnFire);
    if (ruta == '/Users/u/Items') {
      final items = switch (q) {
        {'AlbumArtistIds': 'ar1'} => [_roomOnFire],
        {'IncludeItemTypes': 'MusicAlbum'} => [
            _roomOnFire,
            {'Id': 'a2', 'Name': 'Rumours', 'AlbumArtist': 'Fleetwood Mac', 'ProductionYear': 1977},
          ],
        {'ParentId': 'a1'} => [
            {'Id': 't1', 'Name': 'What Ever Happened?', 'AlbumId': 'a1', 'AlbumArtist': 'The Strokes', 'RunTimeTicks': 1740000000},
            {'Id': 't2', 'Name': 'Reptilia', 'AlbumId': 'a1', 'AlbumArtist': 'The Strokes', 'RunTimeTicks': 2200000000},
          ],
        _ => [],
      };
      return _json({'Items': items});
    }
    return http.Response('ruta desconocida: $ruta', 404);
  }
}
