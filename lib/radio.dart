import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'ajustes.dart';
import 'biblioteca.dart';
import 'jellyfin.dart';
import 'locutor.dart';
import 'mezclas.dart';
import 'player.dart';
import 'tema.dart';

/// Los datos de un `MediaItem` que pide el locutor.
Cancion datosDe(MediaItem m) =>
    (titulo: m.title, artista: m.artist, album: m.album, anio: m.extras?['anio'] as int?, escuchas: m.extras?['escuchas'] as int?);

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

  /// Entre tocar Sintonizar y que suene: mezclas y apertura pueden tardar ~8 s.
  var sintonizando = false;
  bool locutorCaido = false;
  StreamSubscription<PlaybackState>? _sub;
  final _pedidas = <String>{};

  /// Entradas entre canciones pedidas en esta hora: una si y otra no llevan dato.
  var _entradas = 0;

  /// Sube con cada hora nueva: una entrada pedida para la anterior no se mete en esta.
  var _hora = 0;

  int get cada => pocaCharla ? 6 : 3;

  /// Lee el servidor guardado en Ajustes y le pregunta el nombre.
  Future<void> configurar([String? url]) async {
    url ??= (await SharedPreferences.getInstance()).getString('locutor');
    locutor = (url == null || url.trim().isEmpty) ? null : Locutor(url, cliente: cliente);
    nombre = await locutor?.nombre();
    locutorCaido = locutor != null && nombre == null;
    notifyListeners();
  }

  /// Acepta las mezclas aun sin resolver: el aviso de "sintonizando" sale antes
  /// de esperarlas, que tambien cuenta.
  Future<void> sintonizar(FutureOr<List<Mezcla>> mezclas) async {
    if (sintonizando) return;
    sintonizando = true;
    notifyListeners();
    try {
      hora = [for (final c in horaDeRadio(await mezclas, rumbo)) cancion(jf, c)];
      if (hora.isEmpty) return;
      _pedidas.clear();
      _entradas = 0;
      _hora++;
      await _sub?.cancel();
      // La apertura espera poco: mejor empezar sin locutor que con silencio.
      final apertura = await _pedir(null, hora.first).timeout(const Duration(seconds: 8), onTimeout: () => null);
      await reproducir([?apertura, ...hora], 0);
      _sub = player.playbackState.listen(_estado);
    } finally {
      sintonizando = false;
      notifyListeners();
    }
  }

  Future<void> cambiarRumbo(FutureOr<List<Mezcla>> mezclas) {
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
    final e = await locutor!.entrada(antes == null ? null : datosDe(antes), datosDe(despues), poca: pocaCharla, dato: dato);
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
    final hora = _hora;
    final e = await _pedir(antes, despues);
    if (e == null || hora != _hora) return;
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
        if (!enRadio || radio.sintonizando)
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: ambar,
              foregroundColor: tinta,
              disabledBackgroundColor: ambar.withValues(alpha: 0.6),
              disabledForegroundColor: tinta,
              minimumSize: const Size(0, 48),
            ),
            onPressed: radio.sintonizando ? null : () => radio.sintonizar(widget.mezclas),
            icon: radio.sintonizando
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: tinta))
                : const Icon(Icons.play_arrow_rounded),
            label: Text(radio.sintonizando ? 'Sintonizando…' : 'Sintonizar', style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        FilterChip(
          label: const Text('Menos charla'),
          selected: radio.pocaCharla,
          onSelected: radio.menosCharla,
        ),
        OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
          onPressed: radio.sintonizando ? null : () => radio.cambiarRumbo(widget.mezclas),
          child: const Text('Cambiar el rumbo'),
        ),
      ]),
      if (radio.sintonizando)
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Text(radio.locutor == null ? 'Armando la hora…' : '$nombre prepara la apertura…',
              style: const TextStyle(color: textoSuave)),
        ),
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
