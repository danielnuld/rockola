import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import 'descargas.dart';
import 'jellyfin.dart';
import 'lrclib.dart';
import 'player.dart';
import 'reproductor.dart';
import 'tema.dart';

/// El cliente de lrclib; los tests ponen uno falso.
Lrclib lrclib = Lrclib();

// Letras ya pedidas en esta sesion: se piden al abrirlas, no por cada cancion
// que suena. Un fallo no se guarda, para reintentar la siguiente vez.
final _letras = <String, Future<List<Linea>?>>{};

/// La letra de Jellyfin si la tiene; si no, la de lrclib; sin red, la guardada
/// con la descarga.
Future<List<Linea>?> letraDe(Jellyfin jf, MediaItem m) {
  final id = '${m.extras?['itemId']}';
  return _letras[id] ??= () async {
    try {
      if (m.extras?['letra'] == true) {
        final l = await jf.letra(id);
        if (l != null && l.isNotEmpty) return l;
      }
      // Artists viene unido con comas: lrclib quiere el principal.
      return await lrclib.buscar(titulo: m.title, artista: (m.artist ?? '').split(', ').first, album: m.album, dura: m.duration);
    } catch (e) {
      _letras.remove(id);
      final guardada = descargas?.letraGuardada(id);
      if (guardada == null) rethrow;
      return lineasDeLetra(jsonDecode(guardada));
    }
  }();
}

/// La letra de la cancion que suena. Sincronizada: la linea actual en coral y
/// centrada, las cantadas atenuadas, y tocar una salta a su tiempo.
class VistaLetra extends StatefulWidget {
  const VistaLetra(this.jf, this.cancion, {super.key});

  final Jellyfin jf;
  final MediaItem cancion;

  @override
  State<VistaLetra> createState() => _VistaLetraState();
}

class _VistaLetraState extends State<VistaLetra> {
  late final _letra = letraDe(widget.jf, widget.cancion);
  List<GlobalKey> _claves = const [];
  var _ultima = -1;

  /// Centra la linea solo cuando cambia, no en cada tic del progreso.
  void _seguir(int actual) {
    if (actual == _ultima || actual < 0 || actual >= _claves.length) return;
    _ultima = actual;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _claves[actual].currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx, alignment: 0.4, duration: const Duration(milliseconds: 300));
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
        future: _letra,
        builder: (context, snap) {
          if (snap.hasError) return const Center(child: Text('No pude traer la letra', style: TextStyle(color: textoSuave)));
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          final lineas = snap.data;
          if (lineas == null || lineas.isEmpty) {
            return const Center(child: Text('Esta canción no tiene letra', style: TextStyle(color: textoSuave)));
          }
          if (_claves.length != lineas.length) _claves = List.generate(lineas.length, (_) => GlobalKey());
          final sincronizada = lineas.any((l) => l.inicio != null);
          if (!sincronizada) return _lista(lineas, (_) => texto, null);
          return StreamBuilder(
            stream: avance(),
            builder: (context, s) {
              final actual = lineaActual(lineas, s.data?.$1 ?? Duration.zero);
              _seguir(actual);
              return _lista(
                lineas,
                (i) => i == actual ? coral : (i < actual ? textoApagado : texto),
                (i) => lineas[i].inicio == null ? null : () => player.seek(lineas[i].inicio!),
              );
            },
          );
        },
      );

  Widget _lista(List<Linea> lineas, Color Function(int) color, VoidCallback? Function(int)? alTocar) => ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 24),
        itemCount: lineas.length,
        itemBuilder: (context, i) => InkWell(
          key: _claves[i],
          onTap: alTocar?.call(i),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Text(
              lineas[i].texto.isEmpty ? '♪' : lineas[i].texto,
              style: TextStyle(fontFamily: titulos, fontWeight: FontWeight.w800, fontSize: 22, height: 1.25, color: color(i)),
            ),
          ),
        ),
      );
}
