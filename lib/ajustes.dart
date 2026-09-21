import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'radio.dart';
import 'tema.dart';

/// Ajustes de la web: por ahora, el servidor del locutor (docs/locutor.md).
class AjustesPage extends StatefulWidget {
  const AjustesPage({super.key});

  @override
  State<AjustesPage> createState() => _AjustesPageState();
}

class _AjustesPageState extends State<AjustesPage> {
  final _url = TextEditingController();
  String? _resultado;
  bool _probando = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) => _url.text = p.getString('locutor') ?? '');
  }

  Future<void> _probar() async {
    setState(() {
      _probando = true;
      _resultado = null;
    });
    final url = _url.text.trim();
    await (await SharedPreferences.getInstance()).setString('locutor', url);
    final nombre = url.isEmpty ? null : await Locutor(url).nombre();
    if (!mounted) return;
    setState(() {
      _probando = false;
      _resultado = url.isEmpty ? 'Sin servidor: la radio sonará solo con música.' : nombre == null ? 'No responde.' : 'Responde: $nombre';
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Ajustes')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('SERVIDOR DEL LOCUTOR', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1, color: textoSuave)),
          const SizedBox(height: 6),
          const Text('La voz de la radio en la web sale de aquí. Vacío, la radio suena solo con música.',
              style: TextStyle(color: textoSuave)),
          const SizedBox(height: 12),
          TextField(
            controller: _url,
            decoration: const InputDecoration(labelText: 'URL', hintText: 'http://100.102.40.65:8787'),
            keyboardType: TextInputType.url,
            autocorrect: false,
            // Se guarda al escribir: salir sin pulsar el boton no lo pierde.
            onChanged: (v) async => (await SharedPreferences.getInstance()).setString('locutor', v.trim()),
            onSubmitted: (_) => _probar(),
          ),
          const SizedBox(height: 12),
          Row(children: [
            FilledButton(onPressed: _probando ? null : _probar, child: const Text('Guardar y probar')),
            const SizedBox(width: 12),
            if (_resultado != null) Expanded(child: Text(_resultado!)),
          ]),
        ]),
      );
}
