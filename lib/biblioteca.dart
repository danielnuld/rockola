import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import 'descargas.dart';
import 'descargas_pantalla.dart';
import 'jellyfin.dart';
import 'mezclas.dart';
import 'player.dart';
import 'tema.dart';

/// El MediaItem de una cancion. El `id` es la URL de stream; los ids de
/// Jellyfin van en `extras`, que son los que usan el favorito y la portada.
MediaItem cancion(Jellyfin jf, Item t) {
  final albumId = (t['AlbumId'] ?? t['Id']) as String;
  // Descargada: suena del archivo, haya red o no.
  final local = descargas?.archivo(t['Id']);
  final portada = descargas?.portada(albumId);
  return MediaItem(
    id: local != null ? Uri.file(local.ruta).toString() : jf.stream(t['Id']),
    title: t['Name'] ?? '',
    artist: (t['Artists'] as List?)?.join(', ') ?? t['AlbumArtist'],
    album: t['Album'],
    artUri: portada != null ? Uri.file(portada) : Uri.parse(jf.image(albumId)),
    duration: t['RunTimeTicks'] == null ? null : Duration(microseconds: (t['RunTimeTicks'] as int) ~/ 10),
    extras: {
      'itemId': t['Id'],
      'albumId': albumId,
      'fav': t['UserData']?['IsFavorite'] ?? false,
      // Para la locutora: lo que dice sale de aqui, sin volver a pedir nada.
      'anio': t['ProductionYear'],
      'escuchas': t['UserData']?['PlayCount'],
      if (local != null) 'local': local.calidad.detalle,
    },
  );
}

/// Primero lo que esta en el historial, en ese orden; despues el resto por nombre.
List<Item> porRecientes(List<Item> items, List<String> historial, String Function(Item) clave) {
  final pos = {for (var i = historial.length - 1; i >= 0; i--) historial[i]: i};
  int nombre(Item a, Item b) => '${a['Name']}'.toLowerCase().compareTo('${b['Name']}'.toLowerCase());
  return [...items]..sort((a, b) {
      final pa = pos[clave(a)], pb = pos[clave(b)];
      if (pa != null && pb != null) return pa.compareTo(pb);
      if (pa != null) return -1;
      if (pb != null) return 1;
      return nombre(a, b);
    });
}

String lineaAlbum(int? anio, int canciones, Duration dura) => [
      'Álbum',
      if (anio != null) '$anio',
      '$canciones ${canciones == 1 ? 'canción' : 'canciones'}',
      '${dura.inMinutes} min',
    ].join(' · ');

enum _Filtro { albumes, artistas, mezclas, descargado }

class Biblioteca extends StatefulWidget {
  const Biblioteca(this.jf, {super.key, required this.mezclas});

  final Jellyfin jf;
  final Future<List<Mezcla>> mezclas;

  @override
  State<Biblioteca> createState() => _BibliotecaState();
}

class _BibliotecaState extends State<Biblioteca> {
  var _filtro = _Filtro.albumes;
  var _aZ = false;
  late final _datos = Future.wait([
    widget.jf.albums(),
    widget.jf.artistas(),
    // Sin historial la lista sigue: solo se pierde el orden por recientes.
    widget.jf.recientes().catchError((_) => <Item>[]),
  ]);

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          bottom: false,
          // conDescargas: el indicador de cada fila sigue a las descargas en curso.
          child: conDescargas((context) => FutureBuilder(
            future: _datos,
            builder: (context, snap) {
              final cabecera = <Widget>[
                Text('Tu biblioteca', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 14),
                // Cuatro chips no caben siempre en un telefono: se desplazan, como en el lienzo.
                SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
                  Chip2('Álbumes', activo: _filtro == _Filtro.albumes, alTocar: () => setState(() => _filtro = _Filtro.albumes)),
                  const SizedBox(width: 8),
                  Chip2('Artistas', activo: _filtro == _Filtro.artistas, alTocar: () => setState(() => _filtro = _Filtro.artistas)),
                  const SizedBox(width: 8),
                  Chip2('Mezclas', activo: _filtro == _Filtro.mezclas, alTocar: () => setState(() => _filtro = _Filtro.mezclas)),
                  if (descargas != null) ...[
                    const SizedBox(width: 8),
                    Chip2('Descargado', activo: _filtro == _Filtro.descargado, alTocar: () => setState(() => _filtro = _Filtro.descargado)),
                  ],
                ])),
              ];
              if (_filtro == _Filtro.mezclas) {
                return FutureBuilder(
                  future: widget.mezclas,
                  builder: (context, m) => _lista([
                    ...cabecera,
                    const SizedBox(height: 12),
                    for (final mezcla in m.data ?? const <Mezcla>[])
                      InkWell(
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MezclaPage(widget.jf, mezcla))),
                        child: SizedBox(
                          height: 64,
                          child: Row(children: [
                            SizedBox.square(dimension: 56, child: Mosaico(widget.jf, mezcla, radio: 4)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(mezcla.nombre, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                                const SizedBox(height: 3),
                                Text('Mezcla · ${artistasDe(mezcla)}',
                                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: textoSuave)),
                              ]),
                            ),
                          ]),
                        ),
                      ),
                  ]),
                );
              }
              // Descargado no depende de Jellyfin: sin red es lo unico que funciona.
              if (_filtro != _Filtro.descargado) {
                if (snap.hasError) return _lista([...cabecera, const SizedBox(height: 24), Text('${snap.error}')]);
                if (!snap.hasData) return _lista([...cabecera, const SizedBox(height: 48), const Center(child: CircularProgressIndicator())]);
              }

              final [albumes, artistas, historial] = snap.data ?? const [<Item>[], <Item>[], <Item>[]];
              final esAlbum = _filtro != _Filtro.artistas;
              var items = switch (_filtro) {
                _Filtro.albumes => albumes,
                _Filtro.artistas => artistas,
                _Filtro.descargado => descargas!.albumes,
                _Filtro.mezclas => const <Item>[], // resuelto arriba
              };
              if (!_aZ) {
                items = esAlbum
                    ? porRecientes(items, [for (final c in historial) '${c['AlbumId']}'], (a) => '${a['Id']}')
                    : porRecientes(items, [for (final c in historial) '${c['AlbumArtist']}'], (a) => '${a['Name']}');
              }
              return _lista([
                ...cabecera,
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setState(() => _aZ = !_aZ),
                        style: TextButton.styleFrom(foregroundColor: const Color(0xFFD9CBBF), padding: EdgeInsets.zero, minimumSize: const Size(0, 44)),
                        icon: const Icon(Icons.swap_vert_rounded, size: 18),
                        label: Text(_aZ ? 'A–Z' : 'Escuchados hace poco', overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ),
                  Text('${items.length} ${esAlbum ? 'álbumes' : 'artistas'}', style: const TextStyle(fontSize: 13, color: Color(0xFFD9CBBF))),
                ]),
                for (final a in items)
                  esAlbum
                      ? Fila(
                          jf: widget.jf,
                          item: a,
                          sub: 'Álbum · ${a['AlbumArtist'] ?? ''}',
                          descargado: descargas?.completo(a['Id']) ?? false,
                          alTocar: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AlbumPage(widget.jf, a))),
                        )
                      : Fila(
                          jf: widget.jf,
                          item: a,
                          sub: 'Artista',
                          redonda: true,
                          alTocar: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ArtistaPage(widget.jf, a))),
                        ),
              ]);
            },
          )),
        ),
      );

  Widget _lista(List<Widget> hijos) => ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: hijos);
}

/// Chip de filtro del lienzo: coral cuando esta elegido.
class Chip2 extends StatelessWidget {
  const Chip2(this.etiqueta, {super.key, required this.activo, required this.alTocar});

  final String etiqueta;
  final bool activo;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: activo,
        button: true,
        child: Material(
          color: activo ? coral : superficie,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: alTocar,
            child: Container(
              constraints: const BoxConstraints(minHeight: 36),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(etiqueta,
                  style: TextStyle(fontSize: 13, color: activo ? tinta : texto, fontWeight: activo ? FontWeight.w700 : FontWeight.w400)),
            ),
          ),
        ),
      );
}

/// Una fila de 64 px con portada de 56: album o artista.
class Fila extends StatelessWidget {
  const Fila({
    super.key,
    required this.jf,
    required this.item,
    required this.sub,
    required this.alTocar,
    this.redonda = false,
    this.descargado = false,
  });

  final Jellyfin jf;
  final Item item;
  final String sub;
  final VoidCallback alTocar;
  final bool redonda, descargado;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: alTocar,
        child: SizedBox(
          height: 64,
          child: Row(children: [
            SizedBox.square(
              dimension: 56,
              child: Portada(url: jf.image(item['Id']), id: item['Id'], nombre: item['Name'] ?? '', radio: redonda ? 28 : 4),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item['Name'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                const SizedBox(height: 3),
                Row(children: [
                  if (descargado) ...[
                    const Icon(Icons.download_for_offline_rounded, size: 14, color: coral, semanticLabel: 'Descargado'),
                    const SizedBox(width: 5),
                  ],
                  Flexible(child: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: textoSuave))),
                ]),
              ]),
            ),
          ]),
        ),
      );
}

class ArtistaPage extends StatefulWidget {
  const ArtistaPage(this.jf, this.artista, {super.key});

  final Jellyfin jf;
  final Item artista;

  @override
  State<ArtistaPage> createState() => _ArtistaPageState();
}

class _ArtistaPageState extends State<ArtistaPage> {
  Jellyfin get jf => widget.jf;
  late final _albumes = jf.albumesDe(widget.artista['Id']);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.artista['Name'] ?? '')),
        body: FutureBuilder(
          future: _albumes,
          builder: (context, snap) {
            if (snap.hasError) return Center(child: Text('${snap.error}'));
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            return ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [
              for (final a in snap.data!)
                Fila(
                  jf: jf,
                  item: a,
                  sub: ['Álbum', if (a['ProductionYear'] != null) '${a['ProductionYear']}'].join(' · '),
                  alTocar: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AlbumPage(jf, a))),
                ),
            ]);
          },
        ),
      );
}

class AlbumPage extends StatefulWidget {
  const AlbumPage(this.jf, this.album, {super.key});

  final Jellyfin jf;

  /// Basta con Id y Name: el resto se pide al abrir.
  final Item album;

  @override
  State<AlbumPage> createState() => _AlbumPageState();
}

class _AlbumPageState extends State<AlbumPage> {
  static const _tinte = Color(0xFF3A1A12);

  Jellyfin get jf => widget.jf;
  // Sin red, un album descargado se abre con lo que se guardo al descargarlo.
  late final _datos = Future.wait([jf.item(widget.album['Id']), jf.tracks(widget.album['Id'])]).catchError((Object e) {
    final d = descargas?.entrada(widget.album['Id']);
    if (d == null) throw e;
    return <Object>[d['album'], <Item>[for (final p in d['pistas']) p['item']]];
  });

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(backgroundColor: _tinte),
        body: FutureBuilder(
          future: _datos,
          builder: (context, snap) {
            if (snap.hasError) return Center(child: Text('${snap.error}'));
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final a = snap.data![0] as Item;
            final pistas = snap.data![1] as List<Item>;
            final items = [for (final t in pistas) cancion(jf, t)];
            final dura = items.fold(Duration.zero, (s, m) => s + (m.duration ?? Duration.zero));
            final artista = (a['AlbumArtists'] as List?)?.cast<Item>().firstOrNull;
            return ListView(children: [
              Container(
                color: _tinte,
                padding: const EdgeInsets.only(bottom: 16),
                alignment: Alignment.center,
                child: SizedBox.square(dimension: 210, child: Portada(url: jf.image(a['Id']), id: a['Id'], nombre: a['Name'] ?? '')),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a['Name'] ?? '', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 26)),
                  const SizedBox(height: 6),
                  if (artista != null)
                    InkWell(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ArtistaPage(jf, artista))),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(artista['Name'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  Text(lineaAlbum(a['ProductionYear'] as int?, items.length, dura), style: const TextStyle(fontSize: 13, color: textoSuave)),
                  Row(children: [
                    Corazon(jf, a['Id'], inicial: a['UserData']?['IsFavorite'] ?? false),
                    if (descargas != null) BotonDescarga(jf, a, pistas),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Aleatorio',
                      color: textoSuave,
                      onPressed: items.isEmpty ? null : () => reproducirAleatorio(items),
                      icon: const Icon(Icons.shuffle_rounded),
                    ),
                    const SizedBox(width: 4),
                    IconButton.filled(
                      tooltip: 'Reproducir álbum',
                      style: IconButton.styleFrom(backgroundColor: coral, foregroundColor: tinta, fixedSize: const Size.square(56)),
                      onPressed: items.isEmpty ? null : () => reproducir(items, 0),
                      icon: const Icon(Icons.play_arrow_rounded, size: 30),
                    ),
                  ]),
                ]),
              ),
              StreamBuilder<MediaItem?>(
                stream: player.mediaItem,
                builder: (context, s) {
                  final sonando = s.data?.extras?['itemId'];
                  return Column(children: [
                    for (var i = 0; i < items.length; i++)
                      ListTile(
                        onTap: () => reproducir(items, i),
                        title: Text(items[i].title,
                            style: TextStyle(fontWeight: FontWeight.w500, color: items[i].extras?['itemId'] == sonando ? coral : texto)),
                        subtitle: Text(items[i].artist ?? '', style: const TextStyle(color: textoSuave)),
                        trailing: Text(_tiempo(items[i].duration), style: const TextStyle(fontSize: 12, color: textoApagado)),
                      ),
                  ]);
                },
              ),
            ]);
          },
        ),
      );
}

String _tiempo(Duration? d) => d == null ? '' : '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

/// Favorito en Jellyfin, optimista: cambia al tocar y vuelve atras si falla.
class Corazon extends StatefulWidget {
  const Corazon(this.jf, this.id, {super.key, required this.inicial});

  final Jellyfin jf;
  final String id;
  final bool inicial;

  @override
  State<Corazon> createState() => _CorazonState();
}

class _CorazonState extends State<Corazon> {
  late bool _si = widget.inicial;

  Future<void> _tocar() async {
    final antes = _si;
    setState(() => _si = !antes);
    try {
      final guardado = await widget.jf.favorito(widget.id, !antes);
      if (mounted) setState(() => _si = guardado);
    } catch (_) {
      if (!mounted) return;
      setState(() => _si = antes);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No pude guardar el favorito')));
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: _si ? 'Quitar de favoritos' : 'Marcar como favorito',
        onPressed: _tocar,
        color: _si ? coral : textoSuave,
        icon: Icon(_si ? Icons.favorite_rounded : Icons.favorite_border_rounded),
      );
}
