import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'radio.dart';
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
          CampoServidor(
            clave: 'locutor',
            titulo: 'SERVIDOR DEL LOCUTOR',
            ayuda: 'La voz de la radio en la web sale de aquí. Vacío, la radio suena solo con música.',
            ejemplo: 'http://100.102.40.65:8787',
            vacio: 'Sin servidor: la radio sonará solo con música.',
            probar: (url) async {
              final nombre = await Locutor(url).nombre();
              return nombre == null ? null : 'Responde: $nombre';
            },
          ),
          const SizedBox(height: 32),
          CampoServidor(
            clave: 'huellas',
            titulo: 'SERVIDOR DE HUELLAS',
            ayuda: 'Con él, el visualizador se mueve con la música. Vacío, se mueve a su aire.',
            ejemplo: 'http://100.102.40.65:8788',
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
