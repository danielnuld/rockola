import 'package:flutter/material.dart';

import 'biblioteca.dart';
import 'descargas.dart';
import 'descargas_pantalla.dart';
import 'jellyfin.dart';
import 'mezclas.dart';
import 'tema.dart';

String saludo(DateTime t) => switch (t.hour) {
      >= 6 && < 12 => 'Buenos días',
      >= 12 && < 19 => 'Buenas tardes',
      _ => 'Buenas noches',
    };

/// Los albumes de las canciones escuchadas, en orden y sin repetir.
List<Item> albumesRecientes(List<Item> canciones, {int max = 6}) {
  final vistos = <String>{};
  final albumes = <Item>[];
  for (final c in canciones) {
    final id = c['AlbumId'] as String?;
    if (id == null || !vistos.add(id)) continue;
    albumes.add({'Id': id, 'Name': c['Album'] ?? '', 'AlbumArtist': c['AlbumArtist'] ?? ''});
    if (albumes.length == max) break;
  }
  return albumes;
}

class Inicio extends StatefulWidget {
  const Inicio(this.jf, {super.key, required this.sintonizar, required this.mezclas});

  final Jellyfin jf;
  final VoidCallback sintonizar;
  final Future<List<Mezcla>> mezclas;

  @override
  State<Inicio> createState() => _InicioState();
}

class _InicioState extends State<Inicio> {
  late Future<List<Item>> _recientes = widget.jf.recientes();
  var _soloDescargado = false;

  @override
  Widget build(BuildContext context) => SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Row(children: [
              Expanded(child: Text(saludo(DateTime.now()), style: Theme.of(context).textTheme.headlineMedium)),
              if (descargas != null)
                IconButton(
                  tooltip: 'Descargas',
                  style: IconButton.styleFrom(backgroundColor: superficie, fixedSize: const Size.square(44)),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DescargasPage(widget.jf))),
                  icon: const Icon(Icons.download_for_offline_outlined),
                ),
            ]),
            if (descargas != null) ...[
              const SizedBox(height: 16),
              Row(children: [
                Chip2('Todo', activo: !_soloDescargado, alTocar: () => setState(() => _soloDescargado = false)),
                const SizedBox(width: 8),
                Chip2('Descargado', activo: _soloDescargado, alTocar: () => setState(() => _soloDescargado = true)),
              ]),
            ],
            const SizedBox(height: 20),
            _TarjetaRadio(widget.sintonizar),
            const SizedBox(height: 24),
            FutureBuilder(
              future: _recientes,
              builder: (context, snap) => conDescargas((context) {
                if (_soloDescargado) {
                  final bajados = descargas!.albumes;
                  if (bajados.isEmpty) return const Text('Todavía no has descargado nada', style: TextStyle(color: textoSuave));
                  final ids = {for (final b in bajados) b['Id']};
                  final recientes = [for (final a in albumesRecientes(snap.data ?? [], max: 1000)) if (ids.contains(a['Id'])) a];
                  // Sin historial (o sin red) se ven todos los descargados.
                  return _volver(recientes.isEmpty ? bajados : recientes.take(6).toList());
                }
                if (snap.hasError) {
                  return Row(children: [
                    Expanded(child: Text('No pude traer tu historial: ${snap.error}', style: const TextStyle(color: textoSuave))),
                    TextButton(onPressed: () => setState(() { _recientes = widget.jf.recientes(); }), child: const Text('Reintentar')),
                  ]);
                }
                return _volver(albumesRecientes(snap.data ?? []));
              }),
            ),
            FutureBuilder(
              future: widget.mezclas,
              // Sin canciones (sin red o con error) la seccion no se pinta.
              builder: (context, snap) => (snap.data ?? const []).isEmpty ? const SizedBox.shrink() : _mezclasParaTi(snap.data!),
            ),
          ],
        ),
      );

  Widget _mezclasParaTi(List<Mezcla> ms) => Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Mezclas para ti', style: Theme.of(context).textTheme.titleLarge),
          const Text('Armadas en tu equipo con lo que escuchas', style: TextStyle(fontSize: 13, color: textoSuave)),
          const SizedBox(height: 12),
          LayoutBuilder(
            // Fila en el telefono, cuadricula cuando hay ancho (web).
            builder: (context, c) => c.maxWidth >= 700
                ? GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 220,
                      childAspectRatio: 0.72,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                    ),
                    itemCount: ms.length,
                    itemBuilder: (context, i) => TarjetaMezcla(widget.jf, ms[i]),
                  )
                : SizedBox(
                    height: 210,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: ms.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, i) => SizedBox(width: 140, child: TarjetaMezcla(widget.jf, ms[i])),
                    ),
                  ),
          ),
        ]),
      );

  Widget _volver(List<Item> albumes) => albumes.isEmpty
      ? const SizedBox.shrink()
      : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Volver a escuchar', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 320,
              mainAxisExtent: 56,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: albumes.length,
            itemBuilder: (context, i) => _Reciente(widget.jf, albumes[i]),
          ),
        ]);
}

class _TarjetaRadio extends StatelessWidget {
  const _TarjetaRadio(this.sintonizar);

  final VoidCallback sintonizar;

  @override
  Widget build(BuildContext context) => Material(
        color: ambar,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: sintonizar,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: DefaultTextStyle(
              style: const TextStyle(color: tinta, fontSize: 14, height: 1.4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    CircleAvatar(radius: 4, backgroundColor: Color(0xFFC2261A)),
                    SizedBox(width: 8),
                    Text('EN EL AIRE · ROCKOLA FM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                  ]),
                  const SizedBox(height: 10),
                  const Text('Una hora con tu música',
                      style: TextStyle(fontFamily: titulos, fontWeight: FontWeight.w800, fontSize: 24, height: 1.05)),
                  const SizedBox(height: 10),
                  const Text('Empieza con lo que más pusiste esta semana y se va hacia lo que casi no tocas.'),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: sintonizar,
                    style: FilledButton.styleFrom(backgroundColor: tinta, foregroundColor: ambar, minimumSize: const Size(0, 44)),
                    child: const Text('Sintonizar', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _Reciente extends StatelessWidget {
  const _Reciente(this.jf, this.album);

  final Jellyfin jf;
  final Item album;

  @override
  Widget build(BuildContext context) => Material(
        color: superficie,
        borderRadius: BorderRadius.circular(6),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AlbumPage(jf, album))),
          child: Row(children: [
            SizedBox.square(
              dimension: 56,
              child: Portada(url: jf.image(album['Id']), id: album['Id'], nombre: album['Name'], radio: 0),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(album['Name'], maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, height: 1.2)),
            ),
            const SizedBox(width: 8),
          ]),
        ),
      );
}
