import 'dart:math';

import '../jellyfin.dart';

/// Lo que suena al elegir un resultado de la busqueda: una cancion sigue con el
/// resto de su album, un album suena entero y un artista suena mezclado.
Future<({List<Item> canciones, int desde})> colaDe(Jellyfin jf, Item elegido, {Random? azar}) async {
  switch (elegido['Type']) {
    case 'Audio':
      final album = elegido['AlbumId'] as String?;
      final pistas = album == null ? <Item>[] : await jf.tracks(album);
      final i = pistas.indexWhere((t) => t['Id'] == elegido['Id']);
      return i < 0 ? (canciones: [elegido], desde: 0) : (canciones: pistas, desde: i);
    case 'MusicAlbum':
      return (canciones: await jf.tracks('${elegido['Id']}'), desde: 0);
    case 'MusicArtist':
      final canciones = [for (final a in await jf.albumesDe('${elegido['Id']}')) ...await jf.tracks('${a['Id']}')];
      return (canciones: canciones..shuffle(azar), desde: 0);
    default:
      return (canciones: <Item>[], desde: 0);
  }
}

/// Como se ve un resultado en la lista numerada.
String describir(Item r) => switch (r['Type']) {
      'Audio' => '♪ ${r['Name']} — ${r['AlbumArtist'] ?? ''}',
      'MusicAlbum' => '◉ ${r['Name']} — ${r['AlbumArtist'] ?? ''}',
      'MusicArtist' => '☺ ${r['Name']}',
      _ => '${r['Name']}',
    };
