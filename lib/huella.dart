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

const _tasa = 22050, _fps = 20, _nBandas = 16, _n = 2048;

/// La huella de una cancion desde su audio: mono, 16 bits, 22 050 Hz. Lo mismo que
/// `bandas_db` y `huella_de_pcm` de servidor/huellas.py, sin numpy. Devuelve el
/// JSON del servidor.
Map<String, Object> huellaDePcm(Int16List pcm) {
  const paso = _tasa ~/ _fps;
  final x = Float64List(max(pcm.length, _n));
  for (var i = 0; i < pcm.length; i++) {
    x[i] = pcm[i] / 32768;
  }
  final cuadros = (x.length - _n) ~/ paso + 1;
  final hann = [for (var i = 0; i < _n; i++) 0.5 - 0.5 * cos(2 * pi * i / (_n - 1))];
  // Bandas logaritmicas de 40 Hz a 11 kHz: que bins de la FFT caen en cada una.
  final bordes = [for (var i = 0; i <= _nBandas; i++) 40 * pow(11000 / 40, i / _nBandas)];
  final bins = [
    for (var b = 0; b < _nBandas; b++)
      [for (var k = 0; k <= _n ~/ 2; k++) if (k * _tasa / _n >= bordes[b] && k * _tasa / _n < bordes[b + 1]) k]
  ];
  final db = List.generate(_nBandas, (_) => Float64List(cuadros));
  final re = Float64List(_n), im = Float64List(_n);
  for (var c = 0; c < cuadros; c++) {
    for (var i = 0; i < _n; i++) {
      re[i] = x[c * paso + i] * hann[i];
      im[i] = 0;
    }
    _fft(re, im);
    for (var b = 0; b < _nBandas; b++) {
      var s = 0.0;
      for (final k in bins[b]) {
        s += sqrt(re[k] * re[k] + im[k] * im[k]);
      }
      db[b][c] = 20 * log(s / bins[b].length + 1e-6) / ln10;
    }
  }
  // Por banda, del 5 % al 99.5 % de esta cancion: asi los graves no tapan los agudos.
  final datos = Uint8List(cuadros * _nBandas);
  for (var b = 0; b < _nBandas; b++) {
    final orden = Float64List.fromList(db[b])..sort();
    final lo = _percentil(orden, 5), hi = _percentil(orden, 99.5);
    for (var c = 0; c < cuadros; c++) {
      datos[c * _nBandas + b] = (((db[b][c] - lo) / max(hi - lo, 1e-3)).clamp(0.0, 1.0) * 255).floor();
    }
  }
  return {'fps': _fps, 'bandas': _nBandas, 'cuadros': cuadros, 'datos': base64Encode(datos)};
}

/// Interpolando entre vecinos, como `np.percentile`.
double _percentil(Float64List orden, double p) {
  final x = p / 100 * (orden.length - 1);
  final i = x.floor(), j = min(i + 1, orden.length - 1);
  return orden[i] + (orden[j] - orden[i]) * (x - i);
}

/// FFT radix-2 en su sitio; el largo es potencia de 2.
void _fft(Float64List re, Float64List im) {
  final n = re.length;
  for (var i = 1, j = 0; i < n; i++) {
    var bit = n >> 1;
    for (; j & bit != 0; bit >>= 1) {
      j ^= bit;
    }
    j ^= bit;
    if (i < j) {
      var t = re[i];
      re[i] = re[j];
      re[j] = t;
      t = im[i];
      im[i] = im[j];
      im[j] = t;
    }
  }
  for (var largo = 2; largo <= n; largo <<= 1) {
    final a = -2 * pi / largo, wr = cos(a), wi = sin(a);
    for (var i = 0; i < n; i += largo) {
      var cr = 1.0, ci = 0.0;
      for (var k = 0; k < largo ~/ 2; k++) {
        final p = i + k, q = p + largo ~/ 2;
        final tr = re[q] * cr - im[q] * ci, ti = re[q] * ci + im[q] * cr;
        re[q] = re[p] - tr;
        im[q] = im[p] - ti;
        re[p] += tr;
        im[p] += ti;
        final t = cr * wr - ci * wi;
        ci = cr * wi + ci * wr;
        cr = t;
      }
    }
  }
}
