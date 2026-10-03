import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'locutor.dart';
import 'locutor_iphone.dart';
import 'tema.dart';
import 'visualizador.dart';

/// Ajustes: los servidores opcionales, el del locutor (docs/locutor.md) y el de
/// huellas (docs/huellas.md).
class AjustesPage extends StatelessWidget {
  const AjustesPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Ajustes')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          // En el iPhone habla la locutora del telefono: se elige su voz, no un servidor.
          if (locutoraDelIphone) ...[
            const VozLocutora(),
            const SizedBox(height: 32),
          ] else ...[
            CampoServidor(
              clave: 'locutor',
              titulo: 'SERVIDOR DEL LOCUTOR',
              ayuda: 'La voz de la radio en la web sale de aquí. Vacío, la radio suena solo con música.',
              ejemplo: 'http://tu-servidor:8787',
              vacio: 'Sin servidor: la radio sonará solo con música.',
              probar: (url) async {
                final nombre = await LocutorServidor(url).nombre();
                return nombre == null ? null : 'Responde: $nombre';
              },
            ),
            const SizedBox(height: 32),
          ],
          CampoServidor(
            clave: 'huellas',
            titulo: 'SERVIDOR DE HUELLAS',
            ayuda: 'Con él, el visualizador se mueve con la música. Vacío, se mueve a su aire.',
            ejemplo: 'http://tu-servidor:8788',
            vacio: 'Sin servidor: el visualizador no reaccionará a la música.',
            probar: (url) async => await probarHuellas(url) ? 'Responde.' : null,
          ),
        ]),
      );
}

/// Una URL guardada en `clave` al escribir, con un boton que la prueba.
/// `probar` devuelve lo que se lee si responde, o null.
class CampoServidor extends StatefulWidget {
  const CampoServidor(
      {super.key, required this.clave, required this.titulo, required this.ayuda, required this.ejemplo, required this.vacio, required this.probar});

  final String clave, titulo, ayuda, ejemplo, vacio;
  final Future<String?> Function(String url) probar;

  @override
  State<CampoServidor> createState() => _CampoServidorState();
}

class _CampoServidorState extends State<CampoServidor> {
  final _url = TextEditingController();
  String? _resultado;
  bool _probando = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) => _url.text = p.getString(widget.clave) ?? '');
  }

  Future<void> _guardar(String v) async => (await SharedPreferences.getInstance()).setString(widget.clave, v.trim());

  Future<void> _probar() async {
    setState(() {
      _probando = true;
      _resultado = null;
    });
    final url = _url.text.trim();
    await _guardar(url);
    final r = url.isEmpty ? widget.vacio : await widget.probar(url) ?? 'No responde.';
    if (!mounted) return;
    setState(() {
      _probando = false;
      _resultado = r;
    });
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.titulo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1, color: textoSuave)),
        const SizedBox(height: 6),
        Text(widget.ayuda, style: const TextStyle(color: textoSuave)),
        const SizedBox(height: 12),
        TextField(
          controller: _url,
          decoration: InputDecoration(labelText: 'URL', hintText: widget.ejemplo),
          keyboardType: TextInputType.url,
          autocorrect: false,
          // Se guarda al escribir: salir sin pulsar el boton no lo pierde.
          onChanged: _guardar,
          onSubmitted: (_) => _probar(),
        ),
        const SizedBox(height: 12),
        Row(children: [
          FilledButton(onPressed: _probando ? null : _probar, child: const Text('Guardar y probar')),
          const SizedBox(width: 12),
          if (_resultado != null) Expanded(child: Text(_resultado!)),
        ]),
      ]);
}

/// La voz de la locutora del iPhone: las voces en español instaladas, con un ▶
/// para oirlas. "Automática" es la mejor instalada; la locutora se llama como la voz.
class VozLocutora extends StatefulWidget {
  const VozLocutora({super.key, this.locutor});

  /// Para los tests: uno sobre un canal falso.
  final LocutorIphone? locutor;

  @override
  State<VozLocutora> createState() => _VozLocutoraState();
}

class _VozLocutoraState extends State<VozLocutora> {
  late final _locutor = widget.locutor ?? LocutorIphone();
  late final _voces = _locutor.voces();
  String? _elegida;

  @override
  void initState() {
    super.initState();
    LocutorIphone.vozElegida().then((v) {
      if (mounted) setState(() => _elegida = v);
    });
  }

  Future<void> _elegir(String? id) async {
    final p = await SharedPreferences.getInstance();
    id == null ? await p.remove('voz') : await p.setString('voz', id);
    setState(() => _elegida = id);
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('VOZ DE LA LOCUTORA', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1, color: textoSuave)),
        const SizedBox(height: 4),
        const Text('Más voces en Ajustes del iPhone → Accesibilidad → Contenido leído → Voces → Español.',
            style: TextStyle(fontSize: 13, color: textoSuave)),
        FutureBuilder(
          future: _voces,
          builder: (context, snap) {
            if (snap.hasError) return Text('No pude leer las voces: ${snap.error}', style: const TextStyle(color: textoSuave));
            if (!snap.hasData) return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
            // Una elegida que ya no esta instalada cuenta como automatica, igual que en iOS.
            final elegida = snap.data!.any((v) => v.id == _elegida) ? _elegida : null;
            Widget fila(String? id, String nombre, String detalle) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(nombre),
                  subtitle: Text(detalle, style: const TextStyle(color: textoSuave)),
                  leading: IconButton(tooltip: 'Oír $nombre', onPressed: () => _locutor.probar(id), icon: const Icon(Icons.play_circle_outline_rounded)),
                  trailing: elegida == id ? const Icon(Icons.check_rounded, color: coral) : null,
                  onTap: () => _elegir(id),
                );
            return Column(children: [
              fila(null, 'Automática', 'La mejor voz en español que tengas'),
              for (final v in snap.data!) fila(v.id, v.nombre, v.detalle),
            ]);
          },
        ),
      ]);
}
