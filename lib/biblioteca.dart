import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import 'jellyfin.dart';
import 'player.dart';
import 'tema.dart';

// ponytail: la cuadricula y el album de antes, con el tema nuevo. La fase 2
// (issue #2) los rehace como en el lienzo.

class Biblioteca extends StatelessWidget {
  const Biblioteca(this.jf, {super.key});

  final Jellyfin jf;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Tu biblioteca')),
        body: FutureBuilder(
          future: jf.albums(),
          builder: (context, snap) {
            if (snap.hasError) return Center(child: Text('${snap.error}'));
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final albums = snap.data!;
            return GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                childAspectRatio: 0.78,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: albums.length,
              itemBuilder: (context, i) {
                final a = albums[i];
                return InkWell(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AlbumPage(jf, a))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(aspectRatio: 1, child: Portada(url: jf.image(a['Id']), id: a['Id'], nombre: a['Name'] ?? '')),
                      const SizedBox(height: 6),
                      Text(a['Name'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(a['AlbumArtist'] ?? '',
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: textoSuave, fontSize: 12)),
                    ],
                  ),
                );
              },
            );
          },
        ),
      );
}

class AlbumPage extends StatelessWidget {
  const AlbumPage(this.jf, this.album, {super.key});

  final Jellyfin jf;
  final Item album;

  MediaItem _media(Item t) => MediaItem(
        id: jf.stream(t['Id']),
        title: t['Name'] ?? '',
        artist: (t['Artists'] as List?)?.join(', ') ?? t['AlbumArtist'],
        album: t['Album'],
        artUri: Uri.parse(jf.image(album['Id'])),
        // El id del album viaja para la portada de reemplazo del reproductor.
        extras: {'albumId': album['Id']},
        duration: t['RunTimeTicks'] == null ? null : Duration(microseconds: (t['RunTimeTicks'] as int) ~/ 10),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(album['Name'] ?? '')),
        body: FutureBuilder(
          future: jf.tracks(album['Id']),
          builder: (context, snap) {
            if (snap.hasError) return Center(child: Text('${snap.error}'));
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final items = snap.data!.map(_media).toList();
            return ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, i) => ListTile(
                leading: Text('${i + 1}', style: const TextStyle(color: textoSuave)),
                title: Text(items[i].title),
                subtitle: Text(items[i].artist ?? '', style: const TextStyle(color: textoSuave)),
                onTap: () => reproducir(items, i),
              ),
            );
          },
        ),
      );
}
