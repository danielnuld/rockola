import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

/// Lo que el servidor de huellas sabe de una cancion (docs/huellas.md): `bandas`
/// bytes por cuadro, `fps` cuadros por segundo.
class Huella {
  Huella(this.fps, this.bandas, this.datos);

  factory Huella.deJson(Map<String, dynamic> j) => Huella(j['fps'] as int, j['bandas'] as int, base64Decode(j['datos'] as String));

  final int fps, bandas;
  final Uint8List datos;

  int get cuadros => datos.length ~/ bandas;
}

// Cada cuadro es una FFT de 2048 muestras a 22 050 Hz: describe el sonido de su
// centro, 46 ms despues de donde empieza.
const _centro = 1024 / 22050;

/// Las bandas (0–1) en `posicion`, mezclando los dos cuadros vecinos: a 60 fps
/// la animacion no salta cada 50 ms.
List<double> cuadroEn(Huella h, Duration posicion) {
  if (h.cuadros == 0) return List.filled(h.bandas, 0);
  final x = ((posicion.inMicroseconds / 1e6 - _centro) * h.fps).clamp(0.0, h.cuadros - 1.0);
  final i = x.floor(), j = min(i + 1, h.cuadros - 1), f = x - i;
  return [for (var k = 0; k < h.bandas; k++) (h.datos[i * h.bandas + k] * (1 - f) + h.datos[j * h.bandas + k] * f) / 255];
}

/// Un golpe de graves: `actual` sube de golpe sobre su media reciente.
bool golpe(List<double> historial, double actual, {double umbral = 0.18}) {
  if (historial.isEmpty) return false;
  final media = historial.reduce((a, b) => a + b) / historial.length;
  return actual > 0.45 && actual - media > umbral;
}

/// Sin huella, senos lentos por banda: se mueve, pero no con la musica.
List<double> sintetico(double t, {int bandas = 16}) =>
    [for (var i = 0; i < bandas; i++) 0.4 + 0.25 * sin(t * (0.6 + 0.13 * i) + i * 1.7) + 0.1 * sin(t * 2.1 + i)];
