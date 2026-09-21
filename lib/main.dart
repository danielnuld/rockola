import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'jellyfin.dart';
import 'player.dart';

late final Player player;
late final SharedPreferences prefs;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  prefs = await SharedPreferences.getInstance();
  player = await AudioService.init(
    builder: Player.new,
    config: const AudioServiceConfig(androidNotificationChannelName: 'Rockola'),
  );
  runApp(const Rockola());
}

// ponytail: el token va en SharedPreferences. Pasa al llavero de iOS junto con
// la clave de API del locutor.
Jellyfin? savedSession() {
  final s = prefs.getStringList('session');
  return s == null ? null : Jellyfin(s[0], s[1], s[2]);
}

class Rockola extends StatelessWidget {
  const Rockola({super.key});

  @override
  Widget build(BuildContext context) {
    final jf = savedSession();
    return MaterialApp(
      title: 'Rockola',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF1DB954),
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: jf == null ? const LoginPage() : AlbumsPage(jf),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _url = TextEditingController(text: 'http://');
  final _user = TextEditingController();
  final _pass = TextEditingController();
  String? _error;
  bool _busy = false;

  Future<void> _login() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final jf = await Jellyfin.login(_url.text, _user.text, _pass.text);
      await prefs.setStringList('session', [jf.url, jf.token, jf.userId]);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => AlbumsPage(jf)));
    } catch (e) {
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('Rockola', style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: 32),
              TextField(
                controller: _url,
                decoration: const InputDecoration(labelText: 'Servidor Jellyfin'),
                keyboardType: TextInputType.url,
                autocorrect: false,
              ),
              TextField(
                controller: _user,
                decoration: const InputDecoration(labelText: 'Usuario'),
                autocorrect: false,
              ),
              TextField(
                controller: _pass,
                decoration: const InputDecoration(labelText: 'Contrasena'),
                obscureText: true,
                onSubmitted: (_) => _login(),
              ),
              const SizedBox(height: 24),
              if (_error != null)
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              FilledButton(onPressed: _busy ? null : _login, child: const Text('Entrar')),
            ],
          ),
        ),
      );
}

class AlbumsPage extends StatelessWidget {
  const AlbumsPage(this.jf, {super.key});

  final Jellyfin jf;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Albumes')),
        bottomNavigationBar: const MiniPlayer(),
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
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => AlbumPage(jf, a))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(aspectRatio: 1, child: Cover(jf.image(a['Id']))),
                      const SizedBox(height: 6),
                      Text(a['Name'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(
                        a['AlbumArtist'] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                      ),
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
        duration: t['RunTimeTicks'] == null
            ? null
            : Duration(microseconds: (t['RunTimeTicks'] as int) ~/ 10),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(album['Name'] ?? '')),
        bottomNavigationBar: const MiniPlayer(),
        body: FutureBuilder(
          future: jf.tracks(album['Id']),
          builder: (context, snap) {
            if (snap.hasError) return Center(child: Text('${snap.error}'));
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final items = snap.data!.map(_media).toList();
            return ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, i) => ListTile(
                leading: Text('${i + 1}'),
                title: Text(items[i].title),
                subtitle: Text(items[i].artist ?? ''),
                onTap: () => player.playAll(items, i),
              ),
            );
          },
        ),
      );
}

class Cover extends StatelessWidget {
  const Cover(this.url, {super.key});

  final String url;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              const ColoredBox(color: Colors.white10, child: Icon(Icons.album, size: 48)),
        ),
      );
}

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) => StreamBuilder<MediaItem?>(
        stream: player.mediaItem,
        builder: (context, snap) {
          final m = snap.data;
          if (m == null) return const SizedBox.shrink();
          return SafeArea(
            child: ListTile(
              tileColor: const Color(0xFF282828),
              leading: SizedBox(width: 48, child: Cover(m.artUri.toString())),
              title: Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(m.artist ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: StreamBuilder<PlaybackState>(
                stream: player.playbackState,
                builder: (context, s) {
                  final playing = s.data?.playing ?? false;
                  return Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                      onPressed: playing ? player.pause : player.play,
                    ),
                    IconButton(icon: const Icon(Icons.skip_next), onPressed: player.skipToNext),
                  ]);
                },
              ),
            ),
          );
        },
      );
}
