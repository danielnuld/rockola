import 'dart:async';

import 'package:flutter/material.dart';

import 'biblioteca.dart';
import 'jellyfin.dart';
import 'player.dart';
import 'tema.dart';

class Buscar extends StatefulWidget {
  const Buscar(this.jf, {super.key});

  final Jellyfin jf;

  @override
  State<Buscar> createState() => _BuscarState();
}

class _BuscarState extends State<Buscar> {
  Timer? _espera;
  String _texto = '';
  Future<List<Item>>? _resultados;

  // Un Timer que se reinicia en cada tecla: 300 ms sin escribir y se consulta.
  void _cambio(String t) {
    _espera?.cancel();
    t = t.trim();
    if (t.length < 2) {
      setState(() => _resultados = null);
      return;
    }
    _espera = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _texto = t;
        _resultados = widget.jf.buscar(t);
      });
    });
  }

  @override
  void dispose() {
    _espera?.cancel();
    super.dispose();
  }

  void _abrir(Widget pagina) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => pagina));

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          bottom: false,
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
            Text('Buscar', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 14),
            TextField(
              onChanged: _cambio,
              textInputAction: TextInputAction.search,
              autocorrect: false,
              style: const TextStyle(color: texto),
              decoration: InputDecoration(
                hintText: '¿Qué quieres escuchar?',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: superficie,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            if (_resultados != null)
              FutureBuilder(
                future: _resultados,
                builder: (context, snap) {
                  if (snap.hasError) return Text('${snap.error}', style: const TextStyle(color: textoSuave));
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  final r = snap.data!;
                  if (r.isEmpty) return Text('Nada con «$_texto» en tu biblioteca', style: const TextStyle(color: textoSuave));
                  List<Item> de(String tipo) => [for (final i in r) if (i['Type'] == tipo) i];
                  final artistas = de('MusicArtist'), albumes = de('MusicAlbum'), canciones = de('Audio');
                  final cola = [for (final c in canciones) cancion(widget.jf, c)];
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (artistas.isNotEmpty) ...[
                      _grupo('Artistas'),
                      for (final a in artistas)
                        Fila(jf: widget.jf, item: a, sub: 'Artista', redonda: true, alTocar: () => _abrir(ArtistaPage(widget.jf, a))),
                    ],
                    if (albumes.isNotEmpty) ...[
                      _grupo('Álbumes'),
                      for (final a in albumes)
                        Fila(jf: widget.jf, item: a, sub: 'Álbum · ${a['AlbumArtist'] ?? ''}', alTocar: () => _abrir(AlbumPage(widget.jf, a))),
                    ],
                    if (canciones.isNotEmpty) ...[
                      _grupo('Canciones'),
                      for (var i = 0; i < canciones.length; i++)
                        Fila(
                          jf: widget.jf,
                          // La portada de una cancion es la de su album.
                          item: {...canciones[i], 'Id': canciones[i]['AlbumId'] ?? canciones[i]['Id']},
                          sub: 'Canción · ${cola[i].artist ?? ''}',
                          alTocar: () => reproducir(cola, i),
                        ),
                    ],
                  ]);
                },
              ),
          ]),
        ),
      );

  Widget _grupo(String t) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 4),
        child: Text(t, style: Theme.of(context).textTheme.titleLarge),
      );
}
