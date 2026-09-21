import 'dart:async';
import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'ajustes.dart';
import 'biblioteca.dart';
import 'jellyfin.dart';
import 'mezclas.dart';
import 'player.dart';
import 'tema.dart';

/// Cliente del servidor del locutor (contrato en docs/locutor.md). Los errores
/// vuelven como null: sin locutor, la radio suena igual.
class Locutor {
  Locutor(String url, {http.Client? cliente})
      : url = url.trim().replaceAll(RegExp(r'/+$'), ''),
        _http = cliente ?? http.Client();

  final String url;
  final http.Client _http;

  Future<String?> nombre() async {
    try {
      final r = await _http.get(Uri.parse('$url/locutor')).timeout(const Duration(seconds: 8));
      return r.statusCode == 200 ? jsonDecode(r.body)['nombre'] as String? : null;
    } catch (_) {
      return null;
    }
  }

  /// Texto y audio (como `data:` URI) de la entrada entre `antes` y `despues`.
  Future<({String texto, String audio})?> entrada(MediaItem? antes, MediaItem despues, {bool poca = false, bool dato = false}) async {
    try {
      final r = await _http
          .post(Uri.parse('$url/locutor'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'antes': antes == null ? null : _cancion(antes), 'despues': _cancion(despues), 'charla': poca ? 'poca' : 'normal', 'dato': dato}))
          // Medido: con la via rapida ~5 s; cuando cae al CLI, hasta ~50 s.
          .timeout(const Duration(seconds: 60));
      if (r.statusCode != 200) return null;
      final d = jsonDecode(utf8.decode(r.bodyBytes));
      final audio = d['audio'] as String?;
      if (audio == null) return null; // sin voz no hay entrada que sonar
      return (texto: d['texto'] as String, audio: 'data:${d['formato'] ?? 'audio/ogg'};base64,$audio');
    } catch (_) {
      return null;
    }
  }

  static Map<String, Object?> _cancion(MediaItem m) => {
        'titulo': m.title,
        'artista': m.artist,
        'album': m.album,
        'anio': m.extras?['anio'],
        'escuchas': m.extras?['escuchas'],
      };
}

/// Una hora de radio: por turnos de las mezclas del dia, sin repetir. `rumbo`
/// rota por cual mezcla se empieza.
List<Item> horaDeRadio(List<Mezcla> mezclas, int rumbo, {int n = 16}) {
  if (mezclas.isEmpty) return const [];
  final orden = [for (var i = 0; i < mezclas.length; i++) mezclas[(i + rumbo) % mezclas.length]];
  final pos = List.filled(orden.length, 0);
  final vistas = <String>{};
  final hora = <Item>[];
  var sinAvance = 0;
  for (var i = 0; hora.length < n && sinAvance < orden.length; i = (i + 1) % orden.length) {
    final canciones = orden[i].canciones;
    while (pos[i] < canciones.length && !vistas.add('${canciones[pos[i]]['Id']}')) {
      pos[i]++;
    }
    if (pos[i] < canciones.length) {
      hora.add(canciones[pos[i]++]);
      sinAvance = 0;
    } else {
      sinAvance++;
    }
  }
  return hora;
}

bool esLocutor(MediaItem? m) => m?.extras?['locutor'] == true;

/// La sesion de radio: arma la cola y mete las entradas del locutor cuando llegan.
class SesionRadio extends ChangeNotifier {
  SesionRadio(this.jf, {this.cliente});

  final Jellyfin jf;

  /// Cliente HTTP para el locutor; los tests pasan uno falso.
  final http.Client? cliente;
  Locutor? locutor;
  String? nombre;

  /// Canciones planeadas de la hora, sin entradas.
  var hora = <MediaItem>[];
  var pocaCharla = false;
  var rumbo = 0;
  bool locutorCaido = false;
  StreamSubscription<PlaybackState>? _sub;
  final _pedidas = <String>{};

  /// Entradas entre canciones pedidas en esta hora: una si y otra no llevan dato.
  var _entradas = 0;

  int get cada => pocaCharla ? 6 : 3;

  /// Lee el servidor guardado en Ajustes y le pregunta el nombre.
  Future<void> configurar([String? url]) async {
    url ??= (await SharedPreferences.getInstance()).getString('locutor');
    locutor = (url == null || url.trim().isEmpty) ? null : Locutor(url, cliente: cliente);
    nombre = await locutor?.nombre();
    locutorCaido = locutor != null && nombre == null;
    notifyListeners();
  }

  Future<void> sintonizar(List<Mezcla> mezclas) async {
    hora = [for (final c in horaDeRadio(mezclas, rumbo)) cancion(jf, c)];
    if (hora.isEmpty) return;
    _pedidas.clear();
    _entradas = 0;
    await _sub?.cancel();
    // La apertura espera poco: mejor empezar sin locutor que con silencio.
    final apertura = await _pedir(null, hora.first).timeout(const Duration(seconds: 8), onTimeout: () => null);
    await reproducir([?apertura, ...hora], 0);
    _sub = player.playbackState.listen(_estado);
    notifyListeners();
  }

  Future<void> cambiarRumbo(List<Mezcla> mezclas) {
    rumbo++;
    return sintonizar(mezclas);
  }

  void menosCharla(bool si) {
    pocaCharla = si;
    notifyListeners();
  }

  Future<MediaItem?> _pedir(MediaItem? antes, MediaItem despues) async {
    if (locutor == null) return null;
    // "De repente" un dato: una entrada si y otra no, nunca al abrir (no hay
    // cancion de la que hablar) ni con menos charla.
    final dato = antes != null && !pocaCharla && _entradas++ % 2 == 0;
    final e = await locutor!.entrada(antes, despues, poca: pocaCharla, dato: dato);
    locutorCaido = e == null;
    notifyListeners();
    if (e == null) return null;
    return MediaItem(
      id: e.audio,
      title: '${nombre ?? 'El locutor'} habla',
      artist: 'Rockola FM',
      extras: {'locutor': true, 'texto': e.texto},
    );
  }

  /// Al empezar la cancion k de la hora, si la siguiente toca con entrada, se
  /// pide ya: asi tiene toda la cancion k para llegar.
  void _estado(PlaybackState s) {
    final cola = player.queue.value;
    final i = s.queueIndex;
    if (i == null || i >= cola.length || esLocutor(cola[i])) return;
    final k = hora.indexWhere((m) => m.id == cola[i].id);
    if (k < 0 || k + 1 >= hora.length || (k + 1) % cada != 0) return;
    final siguiente = hora[k + 1];
    if (!_pedidas.add(siguiente.id)) return;
    unawaited(_insertar(hora[k], siguiente));
  }

  Future<void> _insertar(MediaItem antes, MediaItem despues) async {
    final e = await _pedir(antes, despues);
    if (e == null) return;
    final cola = player.queue.value;
    final pos = cola.indexWhere((m) => m.id == despues.id);
    final actual = player.playbackState.value.queueIndex ?? 0;
    // Llego tarde: la cancion que debia presentar ya empezo.
    if (pos <= actual) return;
    await player.insertQueueItem(pos, e);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// La pantalla del artboard "Web · Radio con locutora".
class RadioPage extends StatefulWidget {
  const RadioPage(this.radio, {super.key, required this.mezclas});

  final SesionRadio radio;
  final Future<List<Mezcla>> mezclas;

  @override
  State<RadioPage> createState() => _RadioPageState();
}

class _RadioPageState extends State<RadioPage> {
  SesionRadio get radio => widget.radio;

  @override
  void initState() {
    super.initState();
    radio.configurar();
  }

  Future<void> _ajustes() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AjustesPage()));
    await radio.configurar();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF1A1310),
        body: SafeArea(
          child: ListenableBuilder(
            listenable: radio,
            builder: (context, _) => StreamBuilder<MediaItem?>(
              stream: player.mediaItem,
              builder: (context, m) => StreamBuilder<List<MediaItem>>(
                stream: player.queue,
                builder: (context, q) => _contenido(m.data, q.data ?? const []),
              ),
            ),
          ),
        ),
      );

  Widget _contenido(MediaItem? actual, List<MediaItem> cola) {
    final hablando = esLocutor(actual);
    final enRadio = radio.hora.isNotEmpty && actual != null && (hablando || radio.hora.any((h) => h.id == actual.id));
    final i = actual == null ? -1 : cola.indexOf(actual);
    final despues = i < 0 ? const <MediaItem>[] : cola.skip(i + 1).take(8).toList();
    // hablando = esLocutor(actual): actual y sus extras existen.
    final ultimoTexto = hablando ? actual!.extras!['texto'] as String : null;
    final sigue = despues.where((m) => !esLocutor(m)).firstOrNull;
    final nombre = radio.nombre ?? 'Tu locutora';

    return ListView(padding: const EdgeInsets.fromLTRB(24, 20, 24, 24), children: [
      Row(children: [
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(color: ambar, shape: BoxShape.circle),
          child: const Icon(Icons.podcasts_rounded, color: tinta, size: 34),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(hablando ? 'ROCKOLA FM · HABLANDO' : 'ROCKOLA FM',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.4, color: ambar)),
            Text(nombre, style: const TextStyle(fontFamily: titulos, fontWeight: FontWeight.w800, fontSize: 36, letterSpacing: -0.8)),
          ]),
        ),
        IconButton(tooltip: 'Ajustes', onPressed: _ajustes, icon: const Icon(Icons.settings_rounded)),
      ]),
      const SizedBox(height: 20),
      if (radio.locutor == null)
        _aviso('Sin servidor del locutor la radio suena solo con música.', 'Configurarlo')
      else if (radio.locutorCaido)
        _aviso('El locutor no responde: la música sigue sin él.', 'Revisar'),
      if (ultimoTexto != null)
        Text('«$ultimoTexto»',
            style: const TextStyle(fontFamily: titulos, fontWeight: FontWeight.w600, fontSize: 30, height: 1.22, letterSpacing: -0.4)),
      if (sigue != null) ...[
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFF2A2020), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            SizedBox.square(
              dimension: 56,
              child: Portada(url: '${sigue.artUri}', id: '${sigue.extras?['albumId'] ?? sigue.id}', nombre: sigue.album ?? sigue.title),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('SIGUE', style: TextStyle(fontSize: 11, letterSpacing: 1, color: textoSuave)),
                Text(sigue.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                Text(sigue.artist ?? '', style: const TextStyle(color: textoSuave)),
              ]),
            ),
          ]),
        ),
      ],
      const SizedBox(height: 20),
      Wrap(spacing: 12, runSpacing: 12, children: [
        if (!enRadio)
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: ambar, foregroundColor: tinta, minimumSize: const Size(0, 48)),
            onPressed: () async => radio.sintonizar(await widget.mezclas),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Sintonizar', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        FilterChip(
          label: const Text('Menos charla'),
          selected: radio.pocaCharla,
          onSelected: radio.menosCharla,
        ),
        OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
          onPressed: () async => radio.cambiarRumbo(await widget.mezclas),
          child: const Text('Cambiar el rumbo'),
        ),
      ]),
      if (enRadio && despues.isNotEmpty) ...[
        const SizedBox(height: 28),
        const Text('EN LA ROTACIÓN', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1, color: textoSuave)),
        const SizedBox(height: 8),
        for (final m in despues)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: esLocutor(m)
                ? const CircleAvatar(backgroundColor: ambar, child: Icon(Icons.podcasts_rounded, color: tinta, size: 20))
                : SizedBox.square(
                    dimension: 40,
                    child: Portada(url: '${m.artUri}', id: '${m.extras?['albumId'] ?? m.id}', nombre: m.album ?? m.title, radio: 4),
                  ),
            title: Text(esLocutor(m) ? nombre : m.title, style: TextStyle(color: esLocutor(m) ? ambar : texto)),
            subtitle: Text(esLocutor(m) ? 'Entre canciones' : m.artist ?? '', style: const TextStyle(color: textoSuave)),
          ),
      ],
    ]);
  }

  Widget _aviso(String texto, String accion) => Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
        decoration: BoxDecoration(color: superficie, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Expanded(child: Text(texto, style: const TextStyle(color: Color(0xFFD9CBBF)))),
          TextButton(onPressed: _ajustes, child: Text(accion)),
        ]),
      );
}
