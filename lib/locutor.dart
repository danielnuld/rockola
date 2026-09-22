import 'dart:convert';

import 'package:http/http.dart' as http;

import 'jellyfin.dart';
import 'mezclas.dart';

/// Lo que el locutor necesita saber de una cancion (docs/locutor.md).
typedef Cancion = ({String titulo, String? artista, String? album, int? anio, int? escuchas});

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
