// Programa de consola: print es su salida.
// ignore_for_file: avoid_print

import 'dart:io';

import 'package:rockola/jellyfin.dart';
import 'package:rockola/terminal/config.dart';
import 'package:rockola/terminal/interfaz.dart';
import 'package:rockola/terminal/mpv.dart';
import 'package:rockola/terminal/reproductor.dart';

const _ayuda = '''
Rockola en la terminal.

  rockola                  la interfaz, en Inicio
  rockola <búsqueda>       la interfaz, buscando eso
  rockola mezclas          la interfaz, en las mezclas del día
  rockola radio            la interfaz, sintonizando la radio

  --ascii                  sin color ni Unicode, para consolas viejas

Teclas: ↑↓ mover · Enter tocar/abrir · Tab barra lateral · Esc atrás · / buscar
        espacio pausa · n/p siguiente/anterior · ←/→ 10 s · v visualizador
        a color/ascii · q salir

La configuración se lee de rockola.json junto a rockola.exe o, si no hay, de
%APPDATA%\\Rockola\\config.json. La primera vez pide la contraseña y guarda solo el token.''';

/// Lo que se escribe en el archivo de configuracion.
const _ejemplo = '''{
  "url": "http://100.102.40.65:8096",
  "usuario": "daniel",
  "huellas": "http://100.102.40.65:8788",
  "locutor": "http://100.102.40.65:8787"
}''';

Future<void> main(List<String> argumentos) async {
  final args = [...argumentos];
  final ascii = args.remove('--ascii');
  if (args case ['-h'] || ['--help'] || ['ayuda']) {
    print(_ayuda);
    exit(0);
  }
  final archivo = Config.encontrar();
  if (archivo == null) {
    print('Falta la configuración. Crea uno de estos archivos:');
    for (final f in Config.lugares()) {
      print('  ${f.path}');
    }
    print('con algo así ("huellas" y "locutor" son opcionales):\n$_ejemplo');
    exit(1);
  }
  final Config cfg;
  try {
    cfg = Config(archivo);
  } on FormatException catch (e) {
    print('${archivo.path} no es un JSON válido: ${e.message}');
    exit(1);
  }
  try {
    exit(await _correr(args, cfg, ascii));
  } on MpvCerrado catch (e) {
    stderr.writeln(e);
    exit(1);
  } catch (e) {
    // El token dejo de valer (se cerro la sesion en Jellyfin): se olvida.
    if (!'$e'.contains('respondio 401')) rethrow;
    cfg.guardarSesion(null);
    print('La sesión caducó. Vuelve a correr rockola y te pedirá la contraseña.');
    exit(1);
  }
}

Future<int> _correr(List<String> args, Config cfg, bool ascii) async {
  final jf = cfg.jellyfin ?? await _entrar(cfg);
  if (jf == null) return 1;
  // Antes de la pantalla completa: si el token caduco, que el aviso se lea.
  try {
    await jf.listas();
  } catch (e) {
    if ('$e'.contains('respondio 401')) rethrow;
  }
  final exe = Mpv.buscar(ajuste: cfg['mpv']);
  if (exe == null) {
    print('Falta mpv. Instálalo con: winget install shinchiro.mpv (o pon su ruta en "mpv" de ${cfg.archivo.path})');
    return 1;
  }
  final rep = Reproductor(jf, await Mpv.abrir(exe), huellas: cfg['huellas']);
  final comando = args.join(' ');
  await Interfaz(jf, rep, locutor: cfg['locutor'], ascii: ascii).correr(
    buscar: const ['', 'radio', 'mezclas'].contains(comando) ? null : comando,
    radio: comando == 'radio',
    mezclasDelDia: comando == 'mezclas',
  );
  return 0;
}

/// Primera vez, o sesion olvidada: pide la contraseña y guarda solo el token.
Future<Jellyfin?> _entrar(Config cfg) async {
  final (url, usuario) = (cfg['url'], cfg['usuario']);
  if (url == null || usuario == null) {
    print('Faltan "url" y "usuario" de Jellyfin en ${cfg.archivo.path}:\n$_ejemplo');
    return null;
  }
  stdout.write('Contraseña de $usuario en $url: ');
  if (stdin.hasTerminal) stdin.echoMode = false;
  final pass = stdin.readLineSync() ?? '';
  if (stdin.hasTerminal) stdin.echoMode = true;
  print('');
  try {
    final jf = await Jellyfin.login(url, usuario, pass);
    cfg.guardarSesion(jf);
    return jf;
  } catch (e) {
    print('$e'.contains('respondio 401') ? 'Usuario o contraseña incorrectos.' : 'No se pudo entrar: $e');
    return null;
  }
}
