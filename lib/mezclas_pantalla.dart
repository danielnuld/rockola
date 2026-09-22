import 'package:flutter/material.dart';

import 'biblioteca.dart';
import 'jellyfin.dart';
import 'listas.dart';
import 'mezclas.dart';
import 'player.dart';
import 'tema.dart';

/// Portada de cuatro albumes distintos de la mezcla.
class Mosaico extends StatelessWidget {
  const Mosaico(this.jf, this.mezcla, {super.key, this.radio = 8});

  final Jellyfin jf;
  final Mezcla mezcla;
  final double radio;

  @override
  Widget build(BuildContext context) {
    final albumes = {for (final c in mezcla.canciones) '${c['AlbumId'] ?? c['Id']}'}.take(4).toList();
    return ClipRRect(
      borderRadius: BorderRadius.circular(radio),
      child: GridView.count(
        crossAxisCount: 2,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          for (var i = 0; i < 4; i++)
            Portada(
              url: jf.image(albumes[i % albumes.length]),
              id: albumes[i % albumes.length],
              nombre: mezcla.nombre,
              radio: 0,
            ),
        ],
      ),
    );
  }
}

/// Tarjeta de "Mezclas para ti".
class TarjetaMezcla extends StatelessWidget {
  const TarjetaMezcla(this.jf, this.mezcla, {super.key});

  final Jellyfin jf;
  final Mezcla mezcla;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MezclaPage(jf, mezcla))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AspectRatio(aspectRatio: 1, child: Mosaico(jf, mezcla)),
          const SizedBox(height: 6),
          Text(mezcla.nombre, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          Text(artistasDe(mezcla), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: textoSuave, height: 1.3)),
        ]),
      );
}

class MezclaPage extends StatelessWidget {
  const MezclaPage(this.jf, this.mezcla, {super.key});

  final Jellyfin jf;
  final Mezcla mezcla;

  @override
  Widget build(BuildContext context) {
    final items = [for (final c in mezcla.canciones) cancion(jf, c)];
    return Scaffold(
      appBar: AppBar(),
      body: ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [
        Center(child: SizedBox.square(dimension: 200, child: Mosaico(jf, mezcla))),
        const SizedBox(height: 16),
        Text(mezcla.nombre, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 26)),
        const SizedBox(height: 6),
        Text(mezcla.descripcion, style: const TextStyle(fontSize: 13, color: textoSuave)),
        Row(children: [
          Text('${items.length} canciones', style: const TextStyle(fontSize: 13, color: textoSuave)),
          const Spacer(),
          IconButton(tooltip: 'Aleatorio', color: textoSuave, onPressed: () => reproducirAleatorio(items), icon: const Icon(Icons.shuffle_rounded)),
          const SizedBox(width: 4),
          IconButton.filled(
            tooltip: 'Reproducir mezcla',
            style: IconButton.styleFrom(backgroundColor: coral, foregroundColor: tinta, fixedSize: const Size.square(56)),
            onPressed: () => reproducir(items, 0),
            icon: const Icon(Icons.play_arrow_rounded, size: 30),
          ),
        ]),
        for (var i = 0; i < items.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            onTap: () => reproducir(items, i),
            title: Text(items[i].title, style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(items[i].artist ?? '', style: const TextStyle(color: textoSuave)),
            trailing: MenuCancion(jf, items[i]),
          ),
      ]),
    );
  }
}
