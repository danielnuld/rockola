import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import 'biblioteca.dart';
import 'descargas.dart';
import 'descargas_pantalla.dart';
import 'jellyfin.dart';
import 'player.dart';
import 'tema.dart';

/// Pide un nombre de lista. Vacio o cancelado: null.
Future<String?> pedirNombre(BuildContext context, {String titulo = 'Nueva lista', String inicial = '', String boton = 'Crear'}) async {
  final campo = TextEditingController(text: inicial);
  final nombre = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(titulo),
      content: TextField(
        controller: campo,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Nombre'),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        TextButton(onPressed: () => Navigator.pop(context, campo.text), child: Text(boton)),
      ],
    ),
  );
  final limpio = nombre?.trim() ?? '';
  return limpio.isEmpty ? null : limpio;
}

/// La hoja de "Añadir a una lista": "Nueva lista…" y las listas del usuario,
/// pedidas al abrir para no ofrecer una vieja.
Future<void> anadirALista(BuildContext context, Jellyfin jf, List<String> ids) async {
  final avisos = ScaffoldMessenger.of(context);
  final elegida = await showModalBottomSheet<Item>(
    context: context,
    useRootNavigator: true,
    backgroundColor: panel,
    builder: (context) => SafeArea(
      child: FutureBuilder(
        future: jf.listas(),
        builder: (context, snap) => ListView(shrinkWrap: true, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text('Añadir a una lista', style: Theme.of(context).textTheme.titleLarge),
          ),
          ListTile(
            leading: const Icon(Icons.add_rounded),
            title: const Text('Nueva lista…'),
            onTap: () => Navigator.pop(context, const <String, dynamic>{}),
          ),
          if (snap.hasError) ListTile(title: Text('${snap.error}', style: const TextStyle(color: textoSuave))),
          if (!snap.hasData && !snap.hasError) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
          for (final l in snap.data ?? const <Item>[])
            ListTile(
              leading: const Icon(Icons.queue_music_rounded),
              title: Text(l['Name'] ?? ''),
              subtitle: Text('${l['ChildCount'] ?? 0} canciones', style: const TextStyle(color: textoSuave)),
              onTap: () => Navigator.pop(context, l),
            ),
        ]),
      ),
    ),
  );
  if (elegida == null || !context.mounted) return;
  try {
    var nombre = elegida['Name'] as String?;
    if (elegida.isEmpty) {
      nombre = await pedirNombre(context);
      if (nombre == null) return;
      await jf.crearLista(nombre, ids);
    } else {
      await jf.anadirALista(elegida['Id'], ids);
    }
    avisos.showSnackBar(SnackBar(content: Text(ids.length == 1 ? 'Añadida a $nombre' : 'Añadidas a $nombre')));
  } catch (_) {
    avisos.showSnackBar(const SnackBar(content: Text('No pude añadirla a la lista')));
  }
}

/// El menu de cada cancion: añadir a una lista y, dentro de una lista, quitarla.
class MenuCancion extends StatelessWidget {
  const MenuCancion(this.jf, this.cancion, {super.key, this.quitar});

  final Jellyfin jf;
  final MediaItem cancion;
  final VoidCallback? quitar;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
        tooltip: 'Más opciones de ${cancion.title}',
        icon: const Icon(Icons.more_vert_rounded, color: textoSuave),
        onSelected: (op) => op == 'quitar' ? quitar!() : anadirALista(context, jf, ['${cancion.extras?['itemId']}']),
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'anadir', child: Text('Añadir a una lista')),
          if (quitar != null) const PopupMenuItem(value: 'quitar', child: Text('Quitar de la lista')),
        ],
      );
}

class ListaPage extends StatefulWidget {
  const ListaPage(this.jf, this.lista, {super.key});

  final Jellyfin jf;

  /// Basta con Id y Name.
  final Item lista;

  @override
  State<ListaPage> createState() => _ListaPageState();
}

class _ListaPageState extends State<ListaPage> {
  Jellyfin get jf => widget.jf;
  String get id => widget.lista['Id'];
  late String _nombre = widget.lista['Name'] ?? '';
  List<Item>? _canciones;
  Object? _error;

  @override
  void initState() {
    super.initState();
    jf.cancionesDeLista(id).then((c) => setState(() => _canciones = c)).catchError((Object e) {
      // Sin red, una lista descargada se abre con lo que se guardo.
      final d = descargas?.entrada(id);
      setState(() => d == null ? _error = e : _canciones = [for (final p in d['pistas']) p['item'] as Item]);
    });
  }

  /// Cambio optimista: se ve ya y, si Jellyfin lo rechaza, vuelve a como estaba.
  Future<void> _cambiar(List<Item> nuevas, Future<void> Function() guardar, String error) async {
    final antes = _canciones;
    setState(() => _canciones = nuevas);
    try {
      await guardar();
    } catch (_) {
      if (!mounted) return;
      setState(() => _canciones = antes);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  /// `hasta` ya viene corregido por onReorderItem (sin contar el hueco que deja).
  void _mover(int desde, int hasta) {
    final nuevas = [..._canciones!];
    final c = nuevas.removeAt(desde);
    nuevas.insert(hasta, c);
    _cambiar(nuevas, () => jf.moverEnLista(id, c['PlaylistItemId'], hasta), 'No pude moverla');
  }

  void _quitar(Item c) => _cambiar([..._canciones!]..remove(c), () => jf.quitarDeLista(id, [c['PlaylistItemId']]), 'No pude quitarla');

  Future<void> _renombrar() async {
    final nombre = await pedirNombre(context, titulo: 'Renombrar lista', inicial: _nombre, boton: 'Guardar');
    if (nombre == null || nombre == _nombre) return;
    final antes = _nombre;
    setState(() => _nombre = nombre);
    try {
      await jf.renombrarLista(id, nombre);
    } catch (_) {
      if (!mounted) return;
      setState(() => _nombre = antes);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No pude renombrarla')));
    }
  }

  Future<void> _borrar() async {
    final si = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Borrar la lista?'),
        content: Text('Se borra «$_nombre» de Jellyfin. Las canciones siguen en tu biblioteca.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Borrar')),
        ],
      ),
    );
    if (si != true || !mounted) return;
    try {
      await jf.borrarLista(id);
      await descargas?.borrar(id);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No pude borrarla')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final canciones = _canciones;
    return Scaffold(
      appBar: AppBar(actions: [
        PopupMenuButton<String>(
          tooltip: 'Opciones de la lista',
          onSelected: (op) => op == 'renombrar' ? _renombrar() : _borrar(),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'renombrar', child: Text('Renombrar')),
            PopupMenuItem(value: 'borrar', child: Text('Borrar lista')),
          ],
        ),
      ]),
      body: _error != null
          ? Center(child: Text('$_error'))
          : canciones == null
              ? const Center(child: CircularProgressIndicator())
              : StreamBuilder<MediaItem?>(
                  stream: player.mediaItem,
                  builder: (context, s) {
                    final items = [for (final c in canciones) cancion(jf, c)];
                    final dura = items.fold(Duration.zero, (t, m) => t + (m.duration ?? Duration.zero));
                    final sonando = s.data?.extras?['itemId'];
                    return ReorderableListView(
                      padding: const EdgeInsets.only(bottom: 24),
                      onReorderItem: _mover,
                      header: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Center(child: SizedBox.square(dimension: 200, child: Portada(url: jf.image(id), id: id, nombre: _nombre))),
                          const SizedBox(height: 16),
                          Text(_nombre, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 26)),
                          const SizedBox(height: 6),
                          Text(lineaAlbum(null, items.length, dura, tipo: 'Lista'), style: const TextStyle(fontSize: 13, color: textoSuave)),
                          Row(children: [
                            if (descargas != null) BotonDescarga(jf, {...widget.lista, 'Name': _nombre, 'Type': 'Playlist'}, canciones),
                            const Spacer(),
                            IconButton(
                              tooltip: 'Aleatorio',
                              color: textoSuave,
                              onPressed: items.isEmpty ? null : () => reproducirAleatorio(items),
                              icon: const Icon(Icons.shuffle_rounded),
                            ),
                            const SizedBox(width: 4),
                            IconButton.filled(
                              tooltip: 'Reproducir lista',
                              style: IconButton.styleFrom(backgroundColor: coral, foregroundColor: tinta, fixedSize: const Size.square(56)),
                              onPressed: items.isEmpty ? null : () => reproducir(items, 0),
                              icon: const Icon(Icons.play_arrow_rounded, size: 30),
                            ),
                          ]),
                          if (items.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(top: 16),
                              child: Text('Lista vacía. Añade canciones desde el menú de cada una.', style: TextStyle(color: textoSuave)),
                            ),
                        ]),
                      ),
                      children: [
                        for (var i = 0; i < items.length; i++)
                          ListTile(
                            key: ValueKey(canciones[i]['PlaylistItemId'] ?? '${canciones[i]['Id']}-$i'),
                            onTap: () => reproducir(items, i),
                            title: Text(items[i].title,
                                style: TextStyle(fontWeight: FontWeight.w500, color: items[i].extras?['itemId'] == sonando ? coral : texto)),
                            subtitle: Text(items[i].artist ?? '', style: const TextStyle(color: textoSuave)),
                            trailing: Padding(
                              // Deja sitio al asa de arrastre que pinta ReorderableListView.
                              padding: const EdgeInsets.only(right: 32),
                              child: MenuCancion(jf, items[i], quitar: () => _quitar(canciones[i])),
                            ),
                          ),
                      ],
                    );
                  },
                ),
    );
  }
}
