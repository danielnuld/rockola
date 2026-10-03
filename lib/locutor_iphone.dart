// Aparte de locutor.dart, que usa tambien la terminal: esto necesita Flutter.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'locutor.dart';

/// En el iPhone la locutora es siempre la del telefono: el audio del servidor
/// (OGG en `data:`) no lo reproduce AVPlayer.
bool get locutoraDelIphone => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// La locutora en el propio iPhone: el texto lo escribe Foundation Models y la voz
/// la pone el sintetizador del sistema (ios/Runner/AppDelegate.swift). Sin Apple
/// Intelligence, `nombre()` es null y la radio suena sin ella.
class LocutorIphone implements Locutor {
  LocutorIphone([this._canal = const MethodChannel('rockola/locutor')]);

  final MethodChannel _canal;

  /// La voz elegida en Ajustes (su identificador en iOS); null, la mejor instalada.
  /// Se lee en cada entrada: cambiarla vale desde la siguiente.
  static Future<String?> vozElegida() async => (await SharedPreferences.getInstance()).getString('voz');

  /// El nombre de la voz en español que va a hablar.
  @override
  Future<String?> nombre() async {
    try {
      return await _canal.invokeMethod<String>('voz', {'voz': await vozElegida()});
    } catch (_) {
      return null;
    }
  }

  /// Las voces en español instaladas, de mejor a peor calidad.
  Future<List<({String id, String nombre, String detalle})>> voces() async => [
        for (final v in await _canal.invokeListMethod<Map>('voces') ?? const <Map>[])
          (id: '${v['id']}', nombre: '${v['nombre']}', detalle: '${v['detalle']}'),
      ];

  /// Dice una frase de muestra con la voz `id`, para elegir de oido.
  Future<void> probar(String? id) => _canal.invokeMethod('probar', {'voz': id});

  /// Sin dato: el modelo del telefono es pequeño y lo inventaria. Como mucho 60 s,
  /// lo mismo que se espera al servidor.
  @override
  Future<({String texto, String audio})?> entrada(Cancion? antes, Cancion despues, {bool poca = false, bool dato = false}) =>
      _entrada(antes, despues, poca).timeout(const Duration(seconds: 60), onTimeout: () => null);

  Future<({String texto, String audio})?> _entrada(Cancion? antes, Cancion despues, bool poca) async {
    try {
      final p = pedidoLocutora(antes, despues, poca: poca, nombre: await nombre() ?? 'la locutora');
      final salida = await _canal.invokeMethod<String>('escribir', {'instrucciones': p.instrucciones, 'pedido': p.pedido});
      final (:texto, :ssml) = hablada(salida ?? '');
      if (texto.isEmpty) return null;
      final archivo = await _canal.invokeMethod<String>('decir', {'texto': texto, 'ssml': ssml, 'voz': await vozElegida()});
      return archivo == null ? null : (texto: texto, audio: Uri.file(archivo, windows: false).toString());
    } catch (_) {
      return null;
    }
  }
}
