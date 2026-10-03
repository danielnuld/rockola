import 'dart:convert';
import 'dart:io';

import '../jellyfin.dart';

/// La configuracion de la terminal, un JSON que se escribe a mano: `url` y
/// `usuario` de Jellyfin, y si se quieren, `huellas`, `locutor` y `mpv`. Rockola
/// solo le añade la sesion (`token` y `usuarioId`), nunca la contraseña.
class Config {
  Config(this.archivo) : datos = jsonDecode(archivo.readAsStringSync()) as Map<String, dynamic>;

  /// `rockola.json` junto al ejecutable (para llevarlo en una memoria) o, si no
  /// hay, `%APPDATA%\Rockola\config.json`. Null si no existe ninguno.
  static File? encontrar({String? ejecutable, Map<String, String>? entorno}) =>
      lugares(ejecutable: ejecutable, entorno: entorno).where((f) => f.existsSync()).firstOrNull;

  /// Donde se busca, en orden.
  static List<File> lugares({String? ejecutable, Map<String, String>? entorno}) {
    final e = entorno ?? Platform.environment;
    final s = Platform.pathSeparator;
    final exe = File(ejecutable ?? Platform.resolvedExecutable);
    return [
      File('${exe.parent.path}${s}rockola.json'),
      if (e['APPDATA'] != null) File('${e['APPDATA']}${s}Rockola${s}config.json') else File('${e['HOME']}$s.config${s}rockola${s}config.json'),
    ];
  }

  final File archivo;
  final Map<String, dynamic> datos;

  /// Sin barra final: las URLs se escriben a mano y se les pega la ruta.
  String? operator [](String clave) {
    final v = datos[clave];
    return v is String && v.trim().isNotEmpty ? v.trim().replaceAll(RegExp(r'/+$'), '') : null;
  }

  /// La sesion guardada, o null si falta el token.
  Jellyfin? get jellyfin {
    final (url, token, id) = (this['url'], this['token'], this['usuarioId']);
    return url == null || token == null || id == null ? null : Jellyfin(url, token, id);
  }

  /// Guarda la sesion en el mismo archivo, respetando lo que escribio el usuario.
  void guardarSesion(Jellyfin? jf) {
    if (jf == null) {
      datos
        ..remove('token')
        ..remove('usuarioId');
    } else {
      datos['token'] = jf.token;
      datos['usuarioId'] = jf.userId;
    }
    archivo.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(datos));
  }
}
