import 'dart:convert';

import 'package:http/http.dart' as http;

import 'jellyfin.dart';
import 'mezclas.dart';

/// Lo que el locutor necesita saber de una cancion (docs/locutor.md).
typedef Cancion = ({String titulo, String? artista, String? album, int? anio, int? escuchas});

/// La locutora de la radio. Dos motores: el servidor del locutor (web) y el propio
/// iPhone. Los errores vuelven como null: sin locutor, la radio suena igual.
abstract interface class Locutor {
  /// Su nombre, o null si no esta.
  Future<String?> nombre();

  /// Texto y audio (una URI: `data:` del servidor, `file:` del iPhone) de la
  /// entrada entre `antes` y `despues`.
  Future<({String texto, String audio})?> entrada(Cancion? antes, Cancion despues, {bool poca = false, bool dato = false});
}

/// Cliente del servidor del locutor (contrato en docs/locutor.md).
class LocutorServidor implements Locutor {
  LocutorServidor(String url, {http.Client? cliente})
      : url = url.trim().replaceAll(RegExp(r'/+$'), ''),
        _http = cliente ?? http.Client();

  final String url;
  final http.Client _http;

  @override
  Future<String?> nombre() async {
    try {
      final r = await _http.get(Uri.parse('$url/locutor')).timeout(const Duration(seconds: 8));
      return r.statusCode == 200 ? jsonDecode(r.body)['nombre'] as String? : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<({String texto, String audio})?> entrada(Cancion? antes, Cancion despues, {bool poca = false, bool dato = false}) async {
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

  static Map<String, Object?> _cancion(Cancion c) =>
      {'titulo': c.titulo, 'artista': c.artista, 'album': c.album, 'anio': c.anio, 'escuchas': c.escuchas};
}

/// Lo que se le pide al modelo del iPhone. Solo con los datos que da la app: el
/// modelo no sabe de musica y lo que no le dan, lo inventa.
({String instrucciones, String pedido}) pedidoLocutora(Cancion? antes, Cancion despues, {bool poca = false, required String nombre}) {
  String describe(Cancion c) => [
        '«${c.titulo}»',
        if (c.artista != null) 'de ${c.artista}',
        if (c.album != null) 'del álbum «${c.album}»',
        if (c.anio != null) '(${c.anio})',
        if (c.escuchas case final n?) n == 0 ? '— nunca la ha escuchado' : '— la ha escuchado $n ${n == 1 ? 'vez' : 'veces'}',
      ].join(' ');
  return (
    instrucciones: 'Eres $nombre, locutora de Rockola FM, la radio personal de quien escucha. '
        'Hablas en español, cálida y con chispa, en segunda persona. '
        'Empiezas con tu ánimo entre corchetes, una de: ${animos.keys.map((a) => '[$a]').join(', ')}. '
        'Después, solo lo que vas a decir al aire: sin comillas, sin emojis, sin más acotaciones. '
        'Escribes para ser oída: frases cortas, comas donde respirarías, exclamaciones o preguntas cuando vengan al caso. '
        'Usa solo los datos que te dan; no inventes nada sobre las canciones ni los artistas.',
    pedido: [
      if (antes == null) 'Abre la radio.' else 'Acaba de sonar ${describe(antes)}.',
      'Ahora presenta ${describe(despues)}.',
      poca ? 'Una sola frase corta.' : 'Una o dos frases cortas.',
    ].join(' '),
  );
}

/// Cómo suena cada ánimo: ritmo y tono en SSML, respecto a la voz normal.
/// ponytail: números puestos de oído; se afinan escuchando en el iPhone.
const animos = {
  'alegre': (ritmo: '105%', tono: '+6%'),
  'emocionada': (ritmo: '112%', tono: '+12%'),
  'tranquila': (ritmo: '92%', tono: '-3%'),
  'nostálgica': (ritmo: '88%', tono: '-8%'),
};

/// Lo que escribe el modelo, listo para mostrar y para decir: el texto sin la
/// etiqueta de ánimo, y el SSML con su ritmo y tono y una pausa entre frases.
({String texto, String ssml}) hablada(String salida) {
  final m = RegExp(r'^\s*\[([^\]]*)\]\s*').firstMatch(salida);
  final animo = animos[m?.group(1)?.trim().toLowerCase()] ?? (ritmo: '100%', tono: '+0%');
  final texto = salida.substring(m?.end ?? 0).trim();
  final xml = texto.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
  final cuerpo = xml
      .replaceAll(RegExp(r'\s*(\.\.\.|…)\s*'), '… <break time="400ms"/> ')
      .replaceAllMapped(RegExp(r'([.!?])\s+'), (f) => '${f[1]} <break time="300ms"/> ');
  return (
    texto: texto,
    ssml: '<speak><prosody rate="${animo.ritmo}" pitch="${animo.tono}">${cuerpo.trim()}</prosody></speak>',
  );
}

/// Una hora de radio: por turnos de las mezclas del dia, sin repetir. `rumbo`
/// rota por cual mezcla se empieza y sigue, en cada mezcla, donde se quedo el
/// rumbo anterior: solo rotar daba las mismas canciones en otro orden.
List<Item> horaDeRadio(List<Mezcla> mezclas, int rumbo, {int n = 16}) {
  if (mezclas.isEmpty) return const [];
  final m = mezclas.length;
  final orden = [for (var i = 0; i < m; i++) mezclas[(i + rumbo) % m]];
  final paso = (n / m).ceil(); // canciones que una hora toma de cada mezcla
  final tomadas = List.filled(m, 0);
  final vistas = <String>{};
  final hora = <Item>[];
  var sinAvance = 0;
  for (var i = 0; hora.length < n && sinAvance < m; i = (i + 1) % m) {
    final canciones = orden[i].canciones;
    Item? elegida;
    while (elegida == null && tomadas[i] < canciones.length) {
      final c = canciones[(rumbo * paso + tomadas[i]++) % canciones.length];
      if (vistas.add('${c['Id']}')) elegida = c;
    }
    if (elegida != null) {
      hora.add(elegida);
      sinAvance = 0;
    } else {
      sinAvance++;
    }
  }
  return hora;
}
