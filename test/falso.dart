import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rockola/jellyfin.dart';

/// Un Jellyfin de mentira con Room on Fire, Rumours y The Strokes.
/// Apunta lo que se busca y deja elegir cómo responde el favorito.
class Falso {
  final busquedas = <String>[];
  int estadoFavorito = 200;

  /// Listas de reproduccion: viven mientras dura el test.
  final listas = <String, ({String nombre, List<Map<String, dynamic>> entradas})>{};
  final movimientos = <(String, int)>[];
  bool listasCaidas = false;
  var _n = 0;

  static const _nombres = {'t1': 'What Ever Happened?', 't2': 'Reptilia', 't3': 'Automatic Stop'};
  Map<String, dynamic> _entrada(String id) =>
      {'Id': id, 'Name': _nombres[id] ?? id, 'AlbumArtist': 'The Strokes', 'AlbumId': 'a1', 'PlaylistItemId': 'e${++_n}'};

  /// Crea una lista sin pasar por la app, para preparar un test.
  String nuevaLista(String nombre, List<String> ids) {
    final id = 'l${++_n}';
    listas[id] = (nombre: nombre, entradas: [for (final i in ids) _entrada(i)]);
    return id;
  }

  /// Avisos de reproduccion recibidos: "inicio:t1", "fin:t1@120".
  final avisos = <String>[];
  bool sesionesCaidas = false;

  /// Canciones para las mezclas: 12 de rock (2000s, cuatro artistas) y 6 de rap (1970s, dos).
  static final canciones = [
    for (var i = 0; i < 12; i++)
      {
        'Id': 'r$i',
        'Name': 'Rock $i',
        'AlbumId': 'ra${i % 4}',
        'AlbumArtist': 'Artista ${i % 4}',
        'Genres': [i.isEven ? 'Rock' : 'Alternative'],
        'ProductionYear': 2001 + i % 9,
        'UserData': {'PlayCount': 0},
      },
    for (var i = 0; i < 6; i++)
      {
        'Id': 'h$i',
        'Name': 'Rap $i',
        'AlbumId': 'ha${i % 2}',
        'AlbumArtist': 'Rapero ${i % 2}',
        'Genres': [i.isEven ? 'Hip Hop' : 'Pop Rap'],
        'ProductionYear': 1975,
        'UserData': {'PlayCount': 0},
      },
  ];

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
    if (ruta == '/Playlists' && r.method == 'POST') {
      final b = jsonDecode(r.body);
      return _json({'Id': nuevaLista(b['Name'], [...b['Ids']])});
    }
    final lista = RegExp(r'^/Playlists/(\w+)(/Items)?(?:/(\w+)/Move/(\d+))?$').firstMatch(ruta);
    if (lista != null) {
      final l = listas[lista[1]];
      if (l == null) return http.Response('no existe', 404);
      if (listasCaidas && r.method != 'GET') return http.Response('no', 500);
      if (lista[3] != null) {
        final i = l.entradas.indexWhere((e) => e['PlaylistItemId'] == lista[3]);
        l.entradas.insert(int.parse(lista[4]!), l.entradas.removeAt(i));
        movimientos.add((lista[3]!, int.parse(lista[4]!)));
        return http.Response('', 204);
      }
      if (lista[2] == null) {
        listas[lista[1]!] = (nombre: jsonDecode(r.body)['Name'], entradas: l.entradas);
        return http.Response('', 204);
      }
      switch (r.method) {
        case 'GET':
          return _json({'Items': l.entradas});
        case 'POST':
          l.entradas.addAll([for (final i in q['ids']!.split(',')) _entrada(i)]);
          return http.Response('', 204);
        case 'DELETE':
          final quitar = q['entryIds']!.split(',');
          l.entradas.removeWhere((e) => quitar.contains(e['PlaylistItemId']));
          return http.Response('', 204);
      }
    }
    if (ruta.startsWith('/Items/') && r.method == 'DELETE') {
      if (listasCaidas) return http.Response('no', 500);
      listas.remove(ruta.substring('/Items/'.length));
      return http.Response('', 204);
    }
    if (ruta.startsWith('/Sessions/Playing')) {
      if (sesionesCaidas) return http.Response('caído', 503);
      final b = jsonDecode(r.body);
      avisos.add(ruta.endsWith('Stopped') ? 'fin:${b['ItemId']}@${b['PositionTicks'] ~/ 10000000}' : 'inicio:${b['ItemId']}');
      return http.Response('', 204);
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
        {'Fields': 'Genres,ProductionYear'} => canciones,
        {'IncludeItemTypes': 'Playlist'} => [
            for (final e in listas.entries)
              {'Id': e.key, 'Name': e.value.nombre, 'Type': 'Playlist', 'ChildCount': e.value.entradas.length},
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
