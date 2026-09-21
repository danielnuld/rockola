import 'package:flutter/material.dart';

// Los colores del lienzo. El ambar es solo de la radio y la locutora.
const fondo = Color(0xFF141110);
const fondoProfundo = Color(0xFF0B0908);
const panel = Color(0xFF1B1715);
const superficie = Color(0xFF2A2421);
const texto = Color(0xFFF4EDE6);
const textoSuave = Color(0xFFB3A79C);
const textoApagado = Color(0xFF9C9086);
const coral = Color(0xFFFF6B3D);
const ambar = Color(0xFFF5B841);
const tinta = Color(0xFF1A0E08); // texto sobre coral o ambar
const barraMini = Color(0xFF4A2519);

const titulos = 'Bricolage Grotesque';

/// Siempre oscuro: no hay tema claro.
final tema = ThemeData(
  brightness: Brightness.dark,
  fontFamily: 'DM Sans',
  scaffoldBackgroundColor: fondo,
  colorScheme: const ColorScheme.dark(
    primary: coral,
    onPrimary: tinta,
    secondary: ambar,
    onSecondary: tinta,
    surface: fondo,
    onSurface: texto,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: fondo,
    surfaceTintColor: Colors.transparent,
    titleTextStyle: TextStyle(fontFamily: titulos, fontWeight: FontWeight.w800, fontSize: 22, color: texto),
  ),
  textTheme: const TextTheme(
    headlineMedium: TextStyle(fontFamily: titulos, fontWeight: FontWeight.w800, fontSize: 28, letterSpacing: -0.5),
    titleLarge: TextStyle(fontFamily: titulos, fontWeight: FontWeight.w800, fontSize: 20),
  ),
);

// Tonos del lienzo para los albumes sin portada.
const _tonos = [
  Color(0xFF8C6A3F), Color(0xFFB23A26), Color(0xFF5E6B73), Color(0xFF3F5B45),
  Color(0xFF6E4B2E), Color(0xFF8E2F45), Color(0xFF3C4A63), Color(0xFF5B3A5E),
];

/// Portada de Jellyfin; sin imagen, un bloque de color con la inicial.
class Portada extends StatelessWidget {
  const Portada({super.key, required this.url, required this.id, required this.nombre, this.radio = 6});

  final String url, id, nombre;
  final double radio;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(radio),
        child: Image.network(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => reemplazo()),
      );

  // ponytail: hashCode de String puede cambiar entre versiones de Dart; solo
  // cambiaria el color, nada se rompe.
  Widget reemplazo() => ColoredBox(
        color: _tonos[id.hashCode % _tonos.length],
        child: LayoutBuilder(
          builder: (_, c) => Center(
            child: Text(
              nombre.isEmpty ? '?' : nombre.characters.first.toUpperCase(),
              style: TextStyle(fontFamily: titulos, fontWeight: FontWeight.w800, fontSize: c.maxHeight * 0.42, color: texto),
            ),
          ),
        ),
      );
}
