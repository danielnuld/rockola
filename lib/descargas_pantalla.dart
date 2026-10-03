import 'package:flutter/material.dart';

import 'descargas.dart';
import 'jellyfin.dart';
import 'tema.dart';

/// Descargar, ver el avance o quitar un album. Solo existe con gestor (no en la web).
class BotonDescarga extends StatelessWidget {
  const BotonDescarga(this.jf, this.album, this.pistas, {super.key});

  final Jellyfin jf;
  final Item album;
  final List<Item> pistas;

  Future<void> _quitar(BuildContext context) async {
    final si = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Quitar la descarga?'),
        content: Text('Se borran las canciones de ${album['Name']} de este iPhone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Quitar')),
        ],
      ),
    );
    if (si == true) await descargas!.borrar(album['Id']);
  }

  @override
  Widget build(BuildContext context) => conDescargas((context) {
        final d = descargas!;
        final id = album['Id'] as String;
        final avance = d.avance(id);
        const nota = TextStyle(fontSize: 12, color: textoSuave);

        if (avance == null) {
          return IconButton(
            tooltip: 'Descargar álbum',
            color: textoSuave,
            onPressed: () => d.pedir(jf, album, pistas),
            icon: const Icon(Icons.download_for_offline_outlined),
          );
        }
        if (d.completo(id)) {
          return Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
              tooltip: 'Descargado. Quitar la descarga',
              color: coral,
              onPressed: () => _quitar(context),
              icon: const Icon(Icons.download_for_offline_rounded),
            ),
            Text(tamano(d.bytesDe(id)), style: nota),
          ]);
        }
        final (hechas, total) = avance;
        final (etiqueta, nota2) = d.esperandoWifi
            ? ('Esperando Wi-Fi', 'Esperando Wi-Fi')
            : d.fallo(id)
                ? ('La descarga falló. Reintentar', 'Falló')
                : ('Descargando $hechas de $total. Quitar la descarga', '$hechas/$total');
        return Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            tooltip: etiqueta,
            onPressed: d.fallo(id) ? d.reanudar : () => _quitar(context),
            icon: d.esperandoWifi
                ? const Icon(Icons.wifi_off_rounded, color: textoSuave)
                : SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(value: hechas / total, strokeWidth: 2.5, color: coral, backgroundColor: superficie),
                  ),
          ),
          Text(nota2, style: nota),
        ]);
      });
}

/// La pantalla del artboard "iPhone · Descargas y calidad".
class DescargasPage extends StatefulWidget {
  const DescargasPage(this.jf, {super.key});

  final Jellyfin jf;

  @override
  State<DescargasPage> createState() => _DescargasPageState();
}

class _DescargasPageState extends State<DescargasPage> {
  late final _totales = widget.jf.totales();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Descargas')),
        body: conDescargas((context) {
          final d = descargas!;
          final n = d.albumes.length;
          return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFF221C19), borderRadius: BorderRadius.circular(12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${tamano(d.usado)} en este iPhone', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                Text('Música · $n ${n == 1 ? 'álbum' : 'álbumes'}', style: const TextStyle(fontSize: 13, color: textoSuave)),
                if (d.esperandoWifi) ...[
                  const SizedBox(height: 6),
                  const Text('Hay descargas esperando Wi-Fi', style: TextStyle(fontSize: 13, color: textoSuave)),
                ],
              ]),
            ),
            const SizedBox(height: 22),
            const Text('CALIDAD AL DESCARGAR', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1, color: textoSuave)),
            FutureBuilder(
              future: _totales,
              builder: (context, snap) => RadioGroup<Calidad>(
                groupValue: d.calidad,
                onChanged: (c) => d.calidad = c!,
                child: Column(children: [
                  for (final c in Calidad.values)
                    RadioListTile<Calidad>(
                      value: c,
                      contentPadding: EdgeInsets.zero,
                      title: Text(c.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(c.detalle, style: const TextStyle(color: textoSuave)),
                      secondary: snap.hasData ? Text(tamano(estimar(snap.data!, c)), style: const TextStyle(color: Color(0xFFD9CBBF))) : null,
                    ),
                ]),
              ),
            ),
            const Text(
              'Lo que se ve al lado es lo que ocuparía toda tu biblioteca. Jellyfin comprime en tu servidor antes de bajar; '
              'lo ya descargado se queda en la calidad que tenía.',
              style: TextStyle(fontSize: 13, color: Color(0xFFD9CBBF), height: 1.4),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Descargar solo con Wi-Fi'),
              value: d.soloWifi,
              onChanged: (si) => d.soloWifi = si,
            ),
          ]);
        }),
      );
}
