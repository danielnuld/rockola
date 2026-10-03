import 'dart:math';

import 'jellyfin.dart';

typedef Mezcla = ({String nombre, String descripcion, List<Item> canciones});

// Palabras clave → familia. El orden es la prioridad: "Pop Rap" es Rap.
// ponytail: tabla a mano; si crece a cada rato, generos de MusicBrainz.
const _familias = [
  (['rap', 'hip'], 'Rap'),
  (['rock', 'alternative', 'grunge', 'punk'], 'Rock'),
  (['pop'], 'Pop'),
  (['electr', 'house', 'techno'], 'Electrónica'),
  (['regional', 'banda', 'norteñ', 'cumbia'], 'Regional mexicano'),
];

/// La familia de un genero de Jellyfin; lo que no encaja se queda con su nombre.
String familia(String genero) {
  final g = genero.toLowerCase();
  for (final (claves, nombre) in _familias) {
    if (claves.any(g.contains)) return nombre;
  }
  return genero;
}

// Nombre de la mezcla y como se dice la decada.
const _decadas = {
  1960: ('Sesentera', 'los sesenta'),
  1970: ('Setentera', 'los setenta'),
  1980: ('Ochentera', 'los ochenta'),
  1990: ('Noventera', 'los noventa'),
  2000: ('Dosmilera', 'los dos mil'),
  2010: ('De los 2010', 'los 2010'),
  2020: ('De ahora', 'estos años'),
};

int _escuchas(Item c) => (c['UserData']?['PlayCount'] as int?) ?? 0;
bool _favorita(Item c) => c['UserData']?['IsFavorite'] == true;
String _artista(Item c) => '${c['AlbumArtist'] ?? ''}';
int? _decada(Item c) {
  final y = c['ProductionYear'] as int?;
  return y == null || y <= 0 ? null : y ~/ 10 * 10;
}

Set<String> _familiasDe(Item c) => {for (final g in (c['Genres'] as List? ?? const [])) familia('$g')};

/// Las mezclas del dia. Misma fecha, mismas mezclas; con el historial vacio salen
/// de generos y decadas, y con escuchas se inclinan hacia lo que mas suena.
List<Mezcla> mezclas(List<Item> canciones, Map<String, int> saltos, DateTime fecha) {
  final rnd = Random(fecha.year * 10000 + fecha.month * 100 + fecha.day);
  final hayHistorial = canciones.any((c) => _escuchas(c) > 0);
  // La misma cancion en dos discos (un recopilatorio) cuenta una vez: la mas escuchada.
  final unicas = <String, Item>{};
  for (final c in canciones) {
    final k = '${c['Name']}|${_artista(c)}'.toLowerCase();
    if (unicas[k] == null || _escuchas(c) > _escuchas(unicas[k]!)) unicas[k] = c;
  }
  final validas = [
    for (final c in unicas.values)
      if (!((saltos[c['Id']] ?? 0) >= 3 && _escuchas(c) == 0)) c,
  ];
  double peso(Item c) => max(0.2, 1 + 2.0 * _escuchas(c) + (_favorita(c) ? 3 : 0) - 2.0 * (saltos[c['Id']] ?? 0));
  // Peso de un grupo: cuantas canciones tiene mas 5 por cada escucha. El tamaño
  // es la base y el historial inclina; con pocas escuchas, solo, seria azar
  // (medido: 15 escuchas ponian "Ochentera" por delante de "Dosmilera").
  List<K> top<K>(Iterable<K> Function(Item) claves, int n, {bool soloEscuchas = false}) {
    final suma = <K, int>{};
    for (final c in validas) {
      for (final k in claves(c)) {
        suma[k] = (suma[k] ?? 0) + (soloEscuchas ? 0 : 1) + 5 * _escuchas(c);
      }
    }
    final orden = suma.entries.where((e) => e.value > 0).toList()..sort((a, b) => b.value.compareTo(a.value));
    return [for (final e in orden.take(n)) e.key];
  }

  final resultado = <Mezcla>[];
  void agregar(String nombre, String descripcion, Iterable<Item> pool) {
    final lista = pool.toList();
    // Tope por artista: 3, o lo necesario para llegar a 25 si hay pocos artistas.
    final artistas = {for (final c in lista) _artista(c)}.length;
    final elegidas = _elegir(lista, peso, rnd, max(3, (25 / max(1, artistas)).ceil()));
    if (elegidas.length >= 5) resultado.add((nombre: nombre, descripcion: descripcion, canciones: elegidas));
  }

  final familias = top(_familiasDe, 2);
  final masEscuchado = hayHistorial ? ', sobre todo lo que más escuchas' : '';
  for (final f in familias) {
    agregar('Mezcla de ${f.toLowerCase()}', '$f de tu biblioteca$masEscuchado', validas.where((c) => _familiasDe(c).contains(f)));
  }
  for (final d in top((c) => [if (_decada(c) != null) _decada(c)!], 2)) {
    final (nombre, dicho) = _decadas[d] ?? ('De los $d', 'los $d');
    agregar(nombre, 'Lo que tienes de $dicho$masEscuchado', validas.where((c) => _decada(c) == d));
  }
  if (hayHistorial) {
    // Aqui si, solo escuchas: es "lo mas tuyo", no "lo que mas tienes".
    final a = top((c) => [_artista(c)], 1, soloEscuchas: true).first;
    agregar('Lo más tuyo: $a', 'Lo que más escuchas de $a', validas.where((c) => _artista(c) == a));
  }
  agregar(
    'Lo que casi no tocas',
    'Canciones que no has puesto, de lo que sí te gusta',
    validas.where((c) => _escuchas(c) == 0 && (familias.isEmpty || _familiasDe(c).any(familias.contains))),
  );
  return resultado;
}

/// Al azar ponderado sin repetir, `tope` por artista y 25 en total, y despues sin dos
/// del mismo artista seguidas cuando se puede.
// ponytail: O(n²) al recalcular el total en cada eleccion; con miles de
// canciones por mezcla, Efraimidis–Spirakis (una pasada con claves aleatorias).
List<Item> _elegir(List<Item> pool, double Function(Item) peso, Random rnd, int tope) {
  final elegidas = <Item>[];
  final porArtista = <String, int>{};
  while (elegidas.length < 25) {
    final quedan = [for (final c in pool) if ((porArtista[_artista(c)] ?? 0) < tope) c];
    if (quedan.isEmpty) break;
    var r = rnd.nextDouble() * quedan.fold(0.0, (s, c) => s + peso(c));
    final c = quedan.firstWhere((c) => (r -= peso(c)) <= 0, orElse: () => quedan.last);
    pool.remove(c);
    elegidas.add(c);
    porArtista[_artista(c)] = (porArtista[_artista(c)] ?? 0) + 1;
  }
  final orden = <Item>[];
  while (elegidas.isNotEmpty) {
    final ultimo = orden.isEmpty ? null : _artista(orden.last);
    final i = elegidas.indexWhere((c) => _artista(c) != ultimo);
    orden.add(elegidas.removeAt(i < 0 ? 0 : i));
  }
  return orden;
}

/// Hasta tres artistas de la mezcla, para la tarjeta.
String artistasDe(Mezcla m) => {for (final c in m.canciones) _artista(c)}.take(3).join(', ');
