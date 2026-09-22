import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// mpv se cerro o dejo de contestar.
class MpvCerrado implements Exception {
  const MpvCerrado(this.motivo);
  final String motivo;

  @override
  String toString() => 'mpv se cerró: $motivo';
}

/// Script de mpv: sin señales de Rockola en 5 s (se cerro la ventana, la mataron,
/// se cayo), mpv sale solo. Rockola las manda en cada tic de 50 ms.
const _vigia = '''
local ultimo = mp.get_time()
mp.register_script_message('rockola-vivo', function() ultimo = mp.get_time() end)
mp.add_periodic_timer(1, function()
  if mp.get_time() - ultimo > 5 then mp.command('quit') end
end)
''';

/// Lo que se le pregunta a mpv en cada tic.
typedef EstadoMpv = ({Duration? posicion, Duration? duracion, int? indice, bool pausa, bool parado});

/// mpv como proceso aparte, manejado por su tuberia de comandos (JSON IPC).
/// Solo peticion y respuesta, de una en una: en una tuberia de Windows sin
/// "overlapped", una lectura esperando bloquearia la escritura.
class Mpv {
  Mpv.conCanal(this._escribir, this._leer, {this.alCerrar});

  final Future<void> Function(String linea) _escribir;
  final Future<List<int>> Function() _leer;
  final Future<void> Function()? alCerrar;
  final _resto = <int>[];
  var _id = 0;
  Future<void> _turno = Future.value();

  /// mpv.exe: el de los ajustes, el del PATH o donde lo deja winget (que no lo
  /// pone en el PATH de las sesiones ya abiertas).
  static String? buscar({String? ajuste, Map<String, String>? entorno}) {
    final env = entorno ?? Platform.environment;
    final candidatos = [
      ?ajuste,
      for (final d in (env['PATH'] ?? env['Path'] ?? '').split(';')) if (d.isNotEmpty) '$d\\mpv.exe',
      r'C:\Program Files\MPV Player\mpv.exe',
      r'C:\Program Files\mpv\mpv.exe',
    ];
    for (final c in candidatos) {
      if (File(c).existsSync()) return c;
    }
    return null;
  }

  /// Arranca mpv sin video y en espera, y abre su tuberia.
  static Future<Mpv> abrir(String exe) async {
    final nombre = 'rockola-$pid';
    // En Windows mpv no muere con quien lo lanzo: cerrar la ventana dejaba la
    // musica sonando. Este vigia lo cierra si Rockola deja de dar señales.
    final vigia = File('${Directory.systemTemp.path}${Platform.pathSeparator}$nombre-vigia.lua');
    await vigia.writeAsString(_vigia);
    final p = await Process.start(exe, [
      '--no-video',
      '--no-terminal',
      '--idle=yes',
      '--audio-display=no',
      '--script=${vigia.path}',
      '--input-ipc-server=\\\\.\\pipe\\$nombre',
    ]);
    unawaited(p.stdout.drain<void>());
    unawaited(p.stderr.drain<void>());
    // Dart toma \\.\pipe\ por una ruta de red (errno 53); \\?\pipe\ llega a la
    // misma tuberia. Medido con mpv 0.41 en Windows 11.
    final ruta = '\\\\?\\pipe\\$nombre';
    final inicio = DateTime.now();
    while (true) {
      try {
        final f = await File(ruta).open(mode: FileMode.append);
        return Mpv.conCanal(
          (l) => f.writeString(l),
          () => f.read(4096),
          alCerrar: () async {
            await f.close();
            p.kill();
            try {
              await vigia.delete();
            } catch (_) {}
          },
        );
      } on FileSystemException {
        if (DateTime.now().difference(inicio) > const Duration(seconds: 10)) {
          p.kill();
          throw const MpvCerrado('no abrió su tubería en 10 s');
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
  }

  /// Manda un comando y espera su respuesta; null si mpv no tiene ese dato
  /// (por ejemplo, la posicion sin nada sonando).
  Future<Object?> pedir(List<Object> comando) {
    final r = _turno.then((_) => _pedir(comando));
    _turno = r.then((_) {}, onError: (_) {});
    return r;
  }

  Future<Object?> _pedir(List<Object> comando) async {
    final id = ++_id;
    await _escribir('${jsonEncode({'command': comando, 'request_id': id})}\n');
    while (true) {
      final i = _resto.indexOf(10);
      if (i < 0) {
        final b = await _leer().timeout(const Duration(seconds: 5), onTimeout: () => throw const MpvCerrado('no contesta'));
        if (b.isEmpty) throw const MpvCerrado('tubería cerrada');
        _resto.addAll(b);
        continue;
      }
      final linea = utf8.decode(_resto.sublist(0, i));
      _resto.removeRange(0, i + 1);
      if (linea.trim().isEmpty) continue;
      final m = jsonDecode(linea) as Map;
      if (m['request_id'] != id) continue; // eventos de mpv, que aqui no se usan
      return m['error'] == 'success' ? m['data'] : null;
    }
  }

  /// Lo que se ve en cada tic; de paso le dice al vigia que Rockola sigue viva.
  Future<EstadoMpv> estado() async {
    Duration? dur(Object? s) => s is num ? Duration(microseconds: (s * 1e6).round()) : null;
    await pedir(['script-message', 'rockola-vivo']);
    final pos = await pedir(['get_property', 'time-pos']);
    final duracion = await pedir(['get_property', 'duration']);
    final indice = await pedir(['get_property', 'playlist-pos']);
    final pausa = await pedir(['get_property', 'pause']);
    final parado = await pedir(['get_property', 'idle-active']);
    return (
      posicion: dur(pos),
      duracion: dur(duracion),
      indice: indice is int && indice >= 0 ? indice : null,
      pausa: pausa == true,
      parado: parado == true,
    );
  }

  /// La cola entera, empezando por `desde`.
  Future<void> cargar(List<String> urls, {int desde = 0}) async {
    for (var i = 0; i < urls.length; i++) {
      await pedir(['loadfile', urls[i], i == 0 ? 'replace' : 'append']);
    }
    if (desde > 0) await pedir(['set_property', 'playlist-pos', desde]);
  }

  /// Mete un archivo en la cola, antes del que hoy ocupa `indice`.
  Future<void> insertar(int indice, String url) => pedir(['loadfile', url, 'insert-at', indice]);

  Future<void> siguiente() => pedir(['playlist-next']);
  Future<void> anterior() => pedir(['playlist-prev']);
  Future<void> pausa() => pedir(['cycle', 'pause']);
  Future<void> adelantar(int segundos) => pedir(['seek', segundos, 'relative']);

  Future<void> cerrar() async {
    try {
      await pedir(['quit']).timeout(const Duration(seconds: 1));
    } catch (_) {}
    await alCerrar?.call();
  }
}
