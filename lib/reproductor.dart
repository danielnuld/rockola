import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import 'biblioteca.dart';
import 'jellyfin.dart';
import 'listas.dart';
import 'player.dart';
import 'tema.dart';

/// Encima de todo (Navigator raiz): tapa pestañas o lateral igual en telefono y web.
void abrirReproductor(BuildContext context, Jellyfin jf) => Navigator.of(context, rootNavigator: true)
    .push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => Reproductor(jf)));

/// Posicion y duracion de lo que suena, cada medio segundo.
Stream<(Duration, Duration)> avance() => Stream.periodic(const Duration(milliseconds: 500), (_) {
      final dura = player.mediaItem.valueOrNull?.duration ?? Duration.zero;
      return (player.playbackState.value.position, dura);
    });

String tiempo(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

Widget botonAleatorio() => StreamBuilder<PlaybackState>(
      stream: player.playbackState,
      builder: (context, s) {
        final si = (s.data?.shuffleMode ?? AudioServiceShuffleMode.none) != AudioServiceShuffleMode.none;
        return IconButton(
          tooltip: si ? 'Quitar aleatorio' : 'Aleatorio',
          color: si ? coral : textoSuave,
          onPressed: () => player.setShuffleMode(si ? AudioServiceShuffleMode.none : AudioServiceShuffleMode.all),
          icon: const Icon(Icons.shuffle_rounded),
        );
      },
    );

Widget botonRepetir() => StreamBuilder<PlaybackState>(
      stream: player.playbackState,
      builder: (context, s) {
        final m = s.data?.repeatMode ?? AudioServiceRepeatMode.none;
        return IconButton(
          tooltip: switch (m) {
            AudioServiceRepeatMode.none => 'Repetir',
            AudioServiceRepeatMode.one => 'Repitiendo esta canción',
            _ => 'Repitiendo la cola',
          },
          color: m == AudioServiceRepeatMode.none ? textoSuave : coral,
          onPressed: () => player.setRepeatMode(siguienteRepeticion(m)),
          icon: Icon(m == AudioServiceRepeatMode.one ? Icons.repeat_one_rounded : Icons.repeat_rounded),
        );
      },
    );

/// La cola en una hoja: la actual en coral, tocar otra salta a ella.
void abrirCola(BuildContext context) => showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: panel,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (context, scroll) => StreamBuilder<List<MediaItem>>(
          stream: player.queue,
          builder: (context, q) => StreamBuilder<PlaybackState>(
            stream: player.playbackState,
            builder: (context, s) {
              final cola = q.data ?? const <MediaItem>[];
              final actual = s.data?.queueIndex;
              return ListView.builder(
                controller: scroll,
                itemCount: cola.length + 1,
                itemBuilder: (context, i) => i == 0
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                        child: Text('La cola', style: Theme.of(context).textTheme.titleLarge),
                      )
                    : ListTile(
                        title: Text(cola[i - 1].title, style: TextStyle(color: i - 1 == actual ? coral : texto)),
                        subtitle: Text(cola[i - 1].artist ?? '', style: const TextStyle(color: textoSuave)),
                        onTap: () {
                          player.skipToQueueItem(i - 1);
                          Navigator.of(context).pop();
                        },
                      ),
              );
            },
          ),
        ),
      ),
    );

class Reproductor extends StatelessWidget {
  const Reproductor(this.jf, {super.key});

  final Jellyfin jf;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: barraMini,
        body: SafeArea(
          child: StreamBuilder<MediaItem?>(
            stream: player.mediaItem,
            builder: (context, snap) {
              final m = snap.data;
              if (m == null) return const SizedBox.shrink();
              final albumId = '${m.extras?['albumId'] ?? m.id}';
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [
                    Row(children: [
                      IconButton(
                        tooltip: 'Cerrar reproductor',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
                      ),
                      Expanded(
                        child: Column(children: [
                          const Text('DE ÁLBUM', style: TextStyle(fontSize: 11, letterSpacing: 1.2, color: Color(0xFFE3CFC3))),
                          Text(m.album ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                      IconButton(tooltip: 'Cola de reproducción', onPressed: () => abrirCola(context), icon: const Icon(Icons.queue_music_rounded)),
                    ]),
                    const SizedBox(height: 22),
                    AspectRatio(aspectRatio: 1, child: Portada(url: '${m.artUri}', id: albumId, nombre: m.album ?? m.title, radio: 10)),
                    const SizedBox(height: 30),
                    Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(m.title, style: const TextStyle(fontFamily: titulos, fontWeight: FontWeight.w800, fontSize: 26)),
                          const SizedBox(height: 4),
                          Text(m.artist ?? '', style: const TextStyle(fontSize: 16, color: Color(0xFFE3CFC3))),
                        ]),
                      ),
                      // key: al cambiar de cancion, el corazon arranca con el estado de la nueva.
                      if (m.extras?['itemId'] != null)
                        IconButton(
                          tooltip: 'Añadir a una lista',
                          onPressed: () => anadirALista(context, jf, ['${m.extras!['itemId']}']),
                          icon: const Icon(Icons.playlist_add_rounded),
                        ),
                      Corazon(jf, '${m.extras?['itemId']}', key: ValueKey(m.id), inicial: m.extras?['fav'] == true),
                    ]),
                    const SizedBox(height: 12),
                    const Barra(),
                    const SizedBox(height: 8),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      botonAleatorio(),
                      IconButton(tooltip: 'Anterior', iconSize: 36, onPressed: player.skipToPrevious, icon: const Icon(Icons.skip_previous_rounded)),
                      StreamBuilder<PlaybackState>(
                        stream: player.playbackState,
                        builder: (context, s) {
                          final sonando = s.data?.playing ?? false;
                          return IconButton.filled(
                            tooltip: sonando ? 'Pausar' : 'Reproducir',
                            style: IconButton.styleFrom(backgroundColor: texto, foregroundColor: tinta, fixedSize: const Size.square(72)),
                            onPressed: sonando ? player.pause : player.play,
                            icon: Icon(sonando ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 40),
                          );
                        },
                      ),
                      IconButton(tooltip: 'Siguiente', iconSize: 36, onPressed: player.skipToNext, icon: const Icon(Icons.skip_next_rounded)),
                      botonRepetir(),
                    ]),
                    if (m.extras?['local'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(color: const Color(0xFF5E3226), borderRadius: BorderRadius.circular(16)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.download_done_rounded, size: 16, color: coral),
                              const SizedBox(width: 6),
                              Text('En el iPhone · ${m.extras!['local']}', style: const TextStyle(fontSize: 12)),
                            ]),
                          ),
                        ),
                      ),
                  ]),
                ),
              );
            },
          ),
        ),
      );
}

/// Progreso arrastrable: mientras se arrastra manda el valor local, y el
/// seek va al soltar (en cada movimiento el audio tartamudea).
class Barra extends StatefulWidget {
  const Barra({super.key});

  @override
  State<Barra> createState() => _BarraState();
}

class _BarraState extends State<Barra> {
  double? _arrastre;

  @override
  Widget build(BuildContext context) => StreamBuilder(
        stream: avance(),
        builder: (context, s) {
          final (pos, dura) = s.data ?? (Duration.zero, Duration.zero);
          final max = dura.inMilliseconds.toDouble();
          final valor = (_arrastre ?? pos.inMilliseconds.toDouble()).clamp(0.0, max > 0 ? max : 1.0);
          const estilo = TextStyle(fontSize: 12, color: Color(0xFFE3CFC3));
          return Column(children: [
            Slider(
              value: valor,
              max: max > 0 ? max : 1,
              activeColor: texto,
              inactiveColor: const Color(0xFF7A4A3A),
              onChanged: max > 0 ? (v) => setState(() => _arrastre = v) : null,
              onChangeEnd: (v) {
                player.seek(Duration(milliseconds: v.round()));
                setState(() => _arrastre = null);
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(tiempo(Duration(milliseconds: valor.round())), style: estilo),
                Text('-${tiempo(dura - Duration(milliseconds: valor.round()))}', style: estilo),
              ]),
            ),
          ]);
        },
      );
}
