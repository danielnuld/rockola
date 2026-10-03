import 'package:flutter_test/flutter_test.dart';
import 'package:rockola/player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // El play() de just_audio no vuelve hasta que la musica se pausa: si Player lo
  // devolviera, reproducir() no acabaria nunca (la radio se quedaba cargando).
  test('play() vuelve al momento, sin esperar a que acabe la musica', () async {
    await Player().play().timeout(const Duration(seconds: 1));
  });
}
