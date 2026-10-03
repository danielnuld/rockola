import 'dart:async';
import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'jellyfin.dart';
import 'player.dart';

/// El observador activo, para leer los saltos al armar mezclas. `null` sin sesion.
Escuchas? escuchas;

/// Avisa a Jellyfin de lo que suena y lleva la cuenta local de saltos.
///
/// Sigue `playbackState` por el indice de la cola: al cambiar de indice, la
/// cancion anterior termino (natural o saltada) en la ultima posicion que se le
/// vio, extrapolada al momento del cambio.
class Escuchas {
  Escuchas(this.jf, this.prefs);

  final Jellyfin jf;
  final SharedPreferences prefs;

  static const salto = Duration(seconds: 30);

  int? _indice;
  PlaybackState? _ultimo;
  StreamSubscription<PlaybackState>? _sub;

  Map<String, int> get saltos => (jsonDecode(prefs.getString('saltos') ?? '{}') as Map).cast<String, int>();

  void iniciar() {
    unawaited(_vaciar());
    _sub = player.playbackState.listen(_estado);
  }

  Future<void> cerrar() async => _sub?.cancel();

  void _estado(PlaybackState s) {
    final antes = _ultimo;
    final cambio = s.queueIndex != _indice;
    // Repetir una: mismo indice, pero la posicion vuelve al principio desde el final.
    final vuelta = !cambio && antes != null && _cerca(antes) && s.position < const Duration(seconds: 3);
    final fin = s.processingState == AudioProcessingState.completed && antes?.processingState != AudioProcessingState.completed;

    if ((cambio || vuelta || fin) && _indice != null && antes != null) _termina(_indice!, antes.position);
    if ((cambio || vuelta) && s.queueIndex != null && !fin) _empieza(s.queueIndex!);
    _indice = fin ? null : s.queueIndex;
    _ultimo = fin ? null : s;
  }

  MediaItem? _item(int i) => i < player.queue.value.length ? player.queue.value[i] : null;

  bool _cerca(PlaybackState s) {
    final dura = _item(_indice ?? -1)?.duration;
    return dura != null && s.position >= dura - const Duration(seconds: 3);
  }

  void _empieza(int i) {
    final id = _item(i)?.extras?['itemId'];
    // El inicio no cuenta nada por si solo: si falla, no se guarda.
    if (id != null) unawaited(jf.empieza('$id').catchError((_) {}));
  }

  void _termina(int i, Duration pos) {
    final m = _item(i);
    final id = m?.extras?['itemId'];
    if (id == null) return;
    final dura = m!.duration;
    if (dura != null && pos > dura) pos = dura;
    if (pos < salto && (dura == null || pos < dura - const Duration(seconds: 1))) {
      prefs.setString('saltos', jsonEncode({...saltos, '$id': (saltos['$id'] ?? 0) + 1}));
    }
    final pendientes = [...?prefs.getStringList('fines'), jsonEncode({'id': '$id', 'us': pos.inMicroseconds})];
    prefs.setStringList('fines', pendientes);
    unawaited(_vaciar());
  }

  bool _enviando = false;

  /// Manda los fines pendientes en orden; al primero que falle, para y lo deja
  /// para la siguiente vez. Uno a la vez, para no mandar dos veces el mismo.
  Future<void> _vaciar() async {
    if (_enviando) return;
    _enviando = true;
    try {
      while (true) {
        final pendientes = prefs.getStringList('fines') ?? const [];
        if (pendientes.isEmpty) return;
        final f = jsonDecode(pendientes.first);
        await jf.termina(f['id'], Duration(microseconds: f['us']));
        await prefs.setStringList('fines', (prefs.getStringList('fines') ?? const []).skip(1).toList());
      }
    } catch (_) {
      // Sin red: se reintenta en el siguiente aviso o al abrir la app.
    } finally {
      _enviando = false;
    }
  }
}
