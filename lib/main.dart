import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'armazon.dart';
import 'descargas.dart';
import 'escuchas.dart';
import 'jellyfin.dart';
import 'player.dart';
import 'tema.dart';

late final SharedPreferences prefs;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  prefs = await SharedPreferences.getInstance();
  player = await AudioService.init(
    builder: Player.new,
    config: const AudioServiceConfig(androidNotificationChannelName: 'Rockola'),
  );
  if (!kIsWeb) {
    final red = Connectivity();
    final d = descargas = await Descargas.abrir(
      Directory('${(await getApplicationDocumentsDirectory()).path}/descargas'),
      prefs: prefs,
      hayWifi: () async {
        final r = await red.checkConnectivity();
        return r.contains(ConnectivityResult.wifi) || r.contains(ConnectivityResult.ethernet);
      },
    );
    red.onConnectivityChanged.listen((_) => d.reanudar());
  }
  final jf = savedSession();
  if (jf != null) escuchar(jf);
  runApp(Rockola(jf));
}

/// Empieza a avisar a Jellyfin de lo que suena, con esta sesion.
void escuchar(Jellyfin jf) {
  escuchas?.cerrar();
  escuchas = Escuchas(jf, prefs)..iniciar();
}

// ponytail: el token va en SharedPreferences. Pasa al llavero de iOS junto con
// la clave de API del locutor.
Jellyfin? savedSession() {
  final s = prefs.getStringList('session');
  return s == null ? null : Jellyfin(s[0], s[1], s[2]);
}

class Rockola extends StatelessWidget {
  const Rockola(this.jf, {super.key});

  final Jellyfin? jf;

  @override
  Widget build(BuildContext context) {
    final jf = this.jf;
    return MaterialApp(
      title: 'Rockola',
      theme: tema,
      home: jf == null ? const LoginPage() : Armazon(jf),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _url = TextEditingController(text: 'http://');
  final _user = TextEditingController();
  final _pass = TextEditingController();
  String? _error;
  bool _busy = false;

  Future<void> _login() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final jf = await Jellyfin.login(_url.text, _user.text, _pass.text);
      await prefs.setStringList('session', [jf.url, jf.token, jf.userId]);
      escuchar(jf);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => Armazon(jf)));
    } catch (e) {
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('Rockola', style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: 32),
              TextField(
                controller: _url,
                decoration: const InputDecoration(labelText: 'Servidor Jellyfin'),
                keyboardType: TextInputType.url,
                autocorrect: false,
              ),
              TextField(
                controller: _user,
                decoration: const InputDecoration(labelText: 'Usuario'),
                autocorrect: false,
              ),
              TextField(
                controller: _pass,
                decoration: const InputDecoration(labelText: 'Contrasena'),
                obscureText: true,
                onSubmitted: (_) => _login(),
              ),
              const SizedBox(height: 24),
              if (_error != null)
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              FilledButton(onPressed: _busy ? null : _login, child: const Text('Entrar')),
            ],
          ),
        ),
      );
}
