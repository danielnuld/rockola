import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import 'biblioteca.dart';
import 'buscar.dart';
import 'inicio.dart';
import 'jellyfin.dart';
import 'player.dart';
import 'reproductor.dart';
import 'tema.dart';

/// Desde este ancho, lateral y barra del reproductor completa en vez de pestañas.
const anchoWeb = 900.0;

typedef _Seccion = ({String nombre, IconData icono});

const List<_Seccion> _secciones = [
  (nombre: 'Inicio', icono: Icons.home_rounded),
  (nombre: 'Buscar', icono: Icons.search_rounded),
  (nombre: 'Biblioteca', icono: Icons.library_music_outlined),
  (nombre: 'Radio', icono: Icons.podcasts_rounded),
];

/// Cuatro secciones, cada una con su Navigator: guardan su recorrido al
/// cambiar de una a otra y al pasar de estrecho a ancho (GlobalKey).
class Armazon extends StatefulWidget {
  const Armazon(this.jf, {super.key});

  final Jellyfin jf;

  @override
  State<Armazon> createState() => _ArmazonState();
}

class _ArmazonState extends State<Armazon> {
  int _actual = 0;
  final _navs = List.generate(4, (_) => GlobalKey<NavigatorState>());
  // Aqui y no en el Lateral: su build corre en cada cambio de seccion.
  late final _albumes = widget.jf.albums();

  void _elegir(int i) {
    if (i == _actual) {
      _navs[i].currentState?.popUntil((r) => r.isFirst);
    } else {
      setState(() => _actual = i);
    }
  }

  void _abrirAlbum(Item album) {
    setState(() => _actual = 2);
    _navs[2].currentState?.push(MaterialPageRoute(builder: (_) => AlbumPage(widget.jf, album)));
  }

  Widget _raiz(int i) => switch (i) {
        0 => Inicio(widget.jf, sintonizar: () => _elegir(3)),
        1 => Buscar(widget.jf),
        2 => Biblioteca(widget.jf),
        _ => const Vacio(icono: Icons.podcasts_rounded, titulo: 'Rockola FM', texto: 'La radio con locutora llega pronto.'),
      };

  @override
  Widget build(BuildContext context) {
    final pila = IndexedStack(
      index: _actual,
      children: [
        for (var i = 0; i < 4; i++)
          Navigator(key: _navs[i], onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => _raiz(i))),
      ],
    );
    return LayoutBuilder(
      builder: (context, c) => c.maxWidth >= anchoWeb
          ? Scaffold(
              backgroundColor: fondoProfundo,
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(children: [
                    Expanded(
                      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        SizedBox(width: 320, child: Lateral(widget.jf, albumes: _albumes, actual: _actual, elegir: _elegir, abrirAlbum: _abrirAlbum)),
                        const SizedBox(width: 8),
                        Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(10), child: pila)),
                      ]),
                    ),
                    SizedBox(height: 88, child: BarraAncha(widget.jf)),
                  ]),
                ),
              ),
            )
          : Scaffold(
              body: pila,
              bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
                MiniPlayer(widget.jf),
                Pestanas(actual: _actual, elegir: _elegir),
              ]),
            ),
    );
  }
}

class Pestanas extends StatelessWidget {
  const Pestanas({super.key, required this.actual, required this.elegir});

  final int actual;
  final ValueChanged<int> elegir;

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(children: [
            for (var i = 0; i < _secciones.length; i++)
              Expanded(
                child: Semantics(
                  selected: i == actual,
                  child: InkResponse(
                    onTap: () => elegir(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(_secciones[i].icono, size: 26, color: i == actual ? texto : textoApagado),
                        const SizedBox(height: 4),
                        Text(_secciones[i].nombre, style: TextStyle(fontSize: 11, color: i == actual ? texto : textoApagado)),
                      ]),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      );
}

class Lateral extends StatelessWidget {
  const Lateral(this.jf, {super.key, required this.albumes, required this.actual, required this.elegir, required this.abrirAlbum});

  final Jellyfin jf;
  final Future<List<Item>> albumes;
  final int actual;
  final ValueChanged<int> elegir;
  final ValueChanged<Item> abrirAlbum;

  @override
  Widget build(BuildContext context) => Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text('Rockola',
                  style: TextStyle(fontFamily: titulos, fontWeight: FontWeight.w800, fontSize: 28, letterSpacing: -0.8, color: coral)),
            ),
            for (var i = 0; i < _secciones.length; i++)
              InkWell(
                onTap: () => elegir(i),
                child: SizedBox(
                  height: 44,
                  child: Row(children: [
                    Icon(_secciones[i].icono, color: i == actual ? texto : textoSuave),
                    const SizedBox(width: 14),
                    Text(_secciones[i].nombre,
                        style: TextStyle(
                            fontSize: 15,
                            color: i == actual ? texto : textoSuave,
                            fontWeight: i == actual ? FontWeight.w700 : FontWeight.w400)),
                  ]),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
            decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(10)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Row(children: [
                  Icon(Icons.library_music_outlined, color: textoSuave, size: 22),
                  SizedBox(width: 10),
                  Text('Tu biblioteca', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textoSuave)),
                ]),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder(
                  future: albumes,
                  builder: (context, snap) => ListView(children: [
                    for (final a in snap.data ?? const <Item>[])
                      InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () => abrirAlbum(a),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: Row(children: [
                            SizedBox.square(
                              dimension: 48,
                              child: Portada(url: jf.image(a['Id']), id: a['Id'], nombre: a['Name'] ?? '', radio: 4),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(a['Name'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
                                Text('Álbum · ${a['AlbumArtist'] ?? ''}',
                                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: textoSuave)),
                              ]),
                            ),
                          ]),
                        ),
                      ),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ]);
}

/// Estado de una seccion que todavia no existe.
class Vacio extends StatelessWidget {
  const Vacio({super.key, required this.icono, required this.titulo, required this.texto});

  final IconData icono;
  final String titulo, texto;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icono, size: 48, color: textoApagado),
            const SizedBox(height: 12),
            Text(titulo, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(texto, textAlign: TextAlign.center, style: const TextStyle(color: textoSuave)),
          ]),
        ),
      );
}

// --- el reproductor en la barra -------------------------------------------

Widget _portadaDe(MediaItem m, double lado) => SizedBox.square(
      dimension: lado,
      child: Portada(url: '${m.artUri}', id: '${m.extras?['albumId'] ?? m.id}', nombre: m.album ?? m.title, radio: 5),
    );

Widget _botonPlay({double lado = 44, Color? fondo, Color color = texto}) => StreamBuilder<PlaybackState>(
      stream: player.playbackState,
      builder: (context, s) {
        final sonando = s.data?.playing ?? false;
        return IconButton(
          tooltip: sonando ? 'Pausar' : 'Reproducir',
          onPressed: sonando ? player.pause : player.play,
          style: IconButton.styleFrom(backgroundColor: fondo, foregroundColor: color, fixedSize: Size.square(lado)),
          icon: Icon(sonando ? Icons.pause_rounded : Icons.play_arrow_rounded, size: lado * 0.6),
        );
      },
    );

class Progreso extends StatelessWidget {
  const Progreso({super.key, this.alto = 2, this.conTiempos = false});

  final double alto;
  final bool conTiempos;

  @override
  Widget build(BuildContext context) => StreamBuilder(
        stream: avance(),
        builder: (context, s) {
          final (pos, dura) = s.data ?? (Duration.zero, Duration.zero);
          final f = dura.inMilliseconds == 0 ? 0.0 : (pos.inMilliseconds / dura.inMilliseconds).clamp(0.0, 1.0);
          final linea = ClipRRect(
            borderRadius: BorderRadius.circular(alto),
            child: LinearProgressIndicator(value: f, minHeight: alto, color: texto, backgroundColor: const Color(0xFF7A4A3A)),
          );
          if (!conTiempos) return linea;
          const estilo = TextStyle(fontSize: 12, color: textoSuave);
          return Row(children: [
            Text(tiempo(pos), style: estilo),
            const SizedBox(width: 10),
            Expanded(child: linea),
            const SizedBox(width: 10),
            Text(tiempo(dura), style: estilo),
          ]);
        },
      );
}

/// El mini reproductor del telefono. Sin cola no se pinta.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer(this.jf, {super.key});

  final Jellyfin jf;

  @override
  Widget build(BuildContext context) => StreamBuilder<MediaItem?>(
        stream: player.mediaItem,
        builder: (context, snap) {
          final m = snap.data;
          if (m == null) return const SizedBox.shrink();
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.fromLTRB(8, 8, 4, 6),
            decoration: BoxDecoration(color: barraMini, borderRadius: BorderRadius.circular(10)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Tocar la fila abre el Reproductor; el boton de pausa se queda su toque.
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => abrirReproductor(context, jf),
                    child: Row(children: [
                _portadaDe(m, 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    Text(m.artist ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFFE3CFC3))),
                  ]),
                ),
                    ]),
                  ),
                ),
                _botonPlay(),
              ]),
              const SizedBox(height: 4),
              const Padding(padding: EdgeInsets.only(right: 4), child: Progreso()),
            ]),
          );
        },
      );
}

/// La barra del reproductor de la web, a todo lo ancho.
class BarraAncha extends StatefulWidget {
  const BarraAncha(this.jf, {super.key});

  final Jellyfin jf;

  @override
  State<BarraAncha> createState() => _BarraAnchaState();
}

class _BarraAnchaState extends State<BarraAncha> {
  double _volumen = 1;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: [
          Expanded(
            child: StreamBuilder<MediaItem?>(
              stream: player.mediaItem,
              builder: (context, snap) {
                final m = snap.data;
                if (m == null) return const Text('Nada sonando', style: TextStyle(color: textoSuave));
                return InkWell(
                  onTap: () => abrirReproductor(context, widget.jf),
                  child: Row(children: [
                  _portadaDe(m, 56),
                  const SizedBox(width: 14),
                  Flexible(
                    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      Text(m.artist ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: textoSuave)),
                    ]),
                  ),
                ]),
                );
              },
            ),
          ),
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                botonAleatorio(),
                const SizedBox(width: 8),
                IconButton(tooltip: 'Anterior', onPressed: player.skipToPrevious, icon: const Icon(Icons.skip_previous_rounded), color: textoSuave),
                const SizedBox(width: 12),
                _botonPlay(lado: 40, fondo: texto, color: tinta),
                const SizedBox(width: 12),
                IconButton(tooltip: 'Siguiente', onPressed: player.skipToNext, icon: const Icon(Icons.skip_next_rounded), color: textoSuave),
                const SizedBox(width: 8),
                botonRepetir(),
              ]),
              const Progreso(alto: 4, conTiempos: true),
            ]),
          ),
          Expanded(
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              IconButton(tooltip: 'Cola de reproducción', color: textoSuave, onPressed: () => abrirCola(context), icon: const Icon(Icons.queue_music_rounded)),
              const SizedBox(width: 8),
              const Icon(Icons.volume_up_rounded, color: textoSuave, size: 20),
              SizedBox(
                width: 120,
                child: Slider(
                  value: _volumen,
                  label: 'Volumen',
                  activeColor: const Color(0xFFD9CBBF),
                  inactiveColor: const Color(0xFF3A302B),
                  onChanged: (v) {
                    setState(() => _volumen = v);
                    unawaited(player.customAction('volumen', {'v': v}));
                  },
                ),
              ),
            ]),
          ),
        ]),
      );
}
