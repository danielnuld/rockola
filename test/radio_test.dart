import 'dart:async';
import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rockola/ajustes.dart';
import 'package:rockola/mezclas.dart';
import 'package:rockola/player.dart';
import 'package:rockola/locutor.dart';
import 'package:rockola/locutor_iphone.dart';
import 'package:rockola/radio.dart';
import 'package:rockola/tema.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'falso.dart';

/// Una cola de verdad (la del QueueHandler) sin audio detras.
class ColaFalsa extends BaseAudioHandler with QueueHandler {
  @override
  Future<void> skipToQueueItem(int index) async {
    playbackState.add(playbackState.value.copyWith(queueIndex: index));
    mediaItem.add(queue.value[index]);
  }
}

/// Servidor del locutor falso: apunta los pedidos, puede caerse o hacerse esperar.
class ServidorLocutor {
  final pedidos = <Map<String, dynamic>>[];
  bool caido = false;
  Completer<void>? espera;

  late final cliente = MockClient((r) async {
    if (caido) return http.Response('', 503);
    if (r.method == 'GET') return http.Response(jsonEncode({'nombre': 'Giulia'}), 200);
    pedidos.add(jsonDecode(r.body));
    await espera?.future;
    return http.Response(
      jsonEncode({'texto': 'Entrada ${pedidos.length}', 'audio': base64.encode([1, 2, 3]), 'formato': 'audio/ogg'}),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
}

Mezcla mezcla(String p, {List<String> extra = const []}) => (
      nombre: 'Mezcla $p',
      descripcion: '',
      canciones: [
        for (final id in [...extra, for (var i = 0; i < 10; i++) '$p$i'])
          {'Id': id, 'Name': 'Canción $id', 'AlbumArtist': 'Artista', 'AlbumId': 'al', 'UserData': {'PlayCount': 1}},
      ],
    );

void main() {
  final cola = ColaFalsa();
  setUpAll(() => player = cola);

  final jf = Falso().jf;
  final mezclas = [mezcla('a'), mezcla('b', extra: ['a0']), mezcla('c')];
  late ServidorLocutor s;
  late SesionRadio radio;

  int posicion(String id) => cola.queue.value.indexWhere((m) => m.extras?['itemId'] == id);
  Future<void> suena(String id) async {
    await cola.skipToQueueItem(posicion(id));
    await pumpEventQueue();
  }

  setUp(() {
    cola.queue.add([]);
    cola.playbackState.add(PlaybackState());
    s = ServidorLocutor();
    radio = SesionRadio(jf)
      ..locutor = LocutorServidor('http://loc', cliente: s.cliente)
      ..nombre = 'Giulia';
  });
  tearDown(() => radio.dispose());

  test('la hora: por turnos, sin repetir, y el rumbo cambia por donde empieza', () {
    final ids = [for (final c in horaDeRadio(mezclas, 0)) c['Id']];
    expect(ids.take(6), ['a0', 'b0', 'c0', 'a1', 'b1', 'c1'], reason: 'b empieza en a0, que ya sonó');
    expect(ids, hasLength(16));
    expect(ids.toSet(), hasLength(16));
  });

  test('cambiar el rumbo da otras canciones, no las mismas en otro orden', () {
    final antes = {for (final c in horaDeRadio(mezclas, 0)) c['Id']};
    final despues = [for (final c in horaDeRadio(mezclas, 1)) c['Id']];
    expect(despues.first, isNot('a0'));
    expect(despues.where(antes.contains).length, lessThan(4), reason: 'casi sin repetir la hora anterior');
  });

  test('una entrada pedida para la hora anterior no se mete en la nueva', () async {
    await radio.sintonizar(mezclas);
    s.espera = Completer();
    await suena('c0'); // pide la de antes de la cuarta
    final nueva = radio.cambiarRumbo(mezclas); // la apertura nueva tambien espera
    s.espera!.complete();
    await nueva;
    await pumpEventQueue();
    expect(cola.queue.value.where(esLocutor), hasLength(1), reason: 'solo la apertura de la hora nueva');
    expect(esLocutor(cola.queue.value.first), isTrue);
  });

  test('abre con una entrada y mete otra antes de la cuarta cancion', () async {
    await radio.sintonizar(mezclas);
    expect(esLocutor(cola.queue.value.first), isTrue);
    expect(cola.queue.value.first.extras!['texto'], 'Entrada 1');
    expect(s.pedidos.first['antes'], isNull);
    expect(s.pedidos.first['despues']['titulo'], 'Canción a0');

    await suena('b0'); // segunda: no toca
    expect(s.pedidos, hasLength(1));
    await suena('c0'); // tercera: se pide la de antes de la cuarta
    final cuarta = posicion('a1');
    expect(esLocutor(cola.queue.value[cuarta - 1]), isTrue, reason: 'entrada justo antes de la cuarta');
    expect(s.pedidos.last['antes']['titulo'], 'Canción c0');
    expect(s.pedidos.last['charla'], 'normal');
  });

  test('un dato una entrada si y otra no, nunca al abrir', () async {
    await radio.sintonizar(mezclas);
    await suena('c0'); // antes de la 4a
    await suena('c1'); // antes de la 7a
    await suena('c2'); // antes de la 10a
    expect([for (final p in s.pedidos) p['dato']], [false, true, false, true]);
  });

  test('con menos charla, cada seis y en una frase', () async {
    radio.menosCharla(true);
    await radio.sintonizar(mezclas);
    await suena('c0'); // tercera
    expect(s.pedidos, hasLength(1), reason: 'solo la apertura');
    await suena('c1'); // sexta
    expect(s.pedidos, hasLength(2));
    expect(s.pedidos.last['charla'], 'poca');
    expect(s.pedidos.last['dato'], isFalse, reason: 'sin datos con menos charla');
    expect(esLocutor(cola.queue.value[posicion('a2') - 1]), isTrue);
  });

  test('con el servidor caido suena solo musica', () async {
    s.caido = true;
    await radio.sintonizar(mezclas);
    await suena('c0');
    expect(cola.queue.value.where(esLocutor), isEmpty);
    expect(cola.queue.value, hasLength(16));
    expect(radio.locutorCaido, isTrue);
  });

  test('una entrada que llega tarde se descarta', () async {
    await radio.sintonizar(mezclas);
    s.espera = Completer();
    await suena('c0');
    await suena('a1'); // ya empezo la cancion que debia presentar
    s.espera!.complete();
    await pumpEventQueue();
    expect(cola.queue.value.where(esLocutor), hasLength(1), reason: 'solo la apertura');
  });

  testWidgets('la pantalla muestra lo que dice la locutora mientras habla', (tester) async {
    SharedPreferences.setMockInitialValues({'locutor': 'http://loc'});
    final r = SesionRadio(jf, cliente: s.cliente);
    addTearDown(r.dispose);
    await tester.pumpWidget(MaterialApp(theme: tema, home: RadioPage(r, mezclas: Future.value(mezclas))));
    await tester.pumpAndSettle();
    expect(find.text('Giulia'), findsOneWidget);

    await tester.tap(find.text('Sintonizar'));
    await tester.pumpAndSettle();
    expect(find.text('ROCKOLA FM · HABLANDO'), findsOneWidget);
    expect(find.text('«Entrada 1»'), findsOneWidget);
    expect(find.text('SIGUE'), findsOneWidget);
    expect(find.text('Canción a0'), findsNWidgets(2), reason: 'en "Sigue" y en la rotacion');
    expect(find.text('EN LA ROTACIÓN'), findsOneWidget);
  });

  testWidgets('mientras sintoniza, el boton lo dice y no se puede pulsar dos veces', (tester) async {
    SharedPreferences.setMockInitialValues({'locutor': 'http://loc'});
    final r = SesionRadio(jf, cliente: s.cliente);
    addTearDown(r.dispose);
    await tester.pumpWidget(MaterialApp(theme: tema, home: RadioPage(r, mezclas: Future.value(mezclas))));
    await tester.pumpAndSettle();

    s.espera = Completer(); // la apertura tarda
    await tester.tap(find.text('Sintonizar'));
    await tester.pump();
    expect(find.text('Sintonizando…'), findsOneWidget);
    expect(find.text('Giulia prepara la apertura…'), findsOneWidget);
    await tester.tap(find.text('Sintonizando…'));
    await tester.pump();

    s.espera!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Sintonizando…'), findsNothing);
    expect(s.pedidos, hasLength(1), reason: 'el segundo toque no pidio otra apertura');
    expect(find.text('«Entrada 1»'), findsOneWidget);
  });

  testWidgets('Ajustes guarda el servidor al escribir, sin pulsar el boton', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(MaterialApp(theme: tema, home: const AjustesPage()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'http://tu-servidor:8787 ');
    await tester.pumpAndSettle();
    expect((await SharedPreferences.getInstance()).getString('locutor'), 'http://tu-servidor:8787');
  });

  test('el pedido al modelo del iPhone: solo lo que da la app', () {
    const reptilia = (titulo: 'Reptilia', artista: 'The Strokes', album: 'Room on Fire', anio: 2003, escuchas: 11);
    const nueva = (titulo: 'Proud Mary', artista: null, album: null, anio: null, escuchas: 0);
    final apertura = pedidoLocutora(null, reptilia, nombre: 'Paulina');
    expect(apertura.instrucciones, startsWith('Eres Paulina, locutora de Rockola FM'));
    expect(apertura.pedido,
        'Abre la radio. Ahora presenta «Reptilia» de The Strokes del álbum «Room on Fire» (2003) — la ha escuchado 11 veces. Una o dos frases cortas.');
    expect(pedidoLocutora(reptilia, nueva, poca: true, nombre: 'Paulina').pedido,
        startsWith('Acaba de sonar «Reptilia»'));
    expect(pedidoLocutora(reptilia, nueva, poca: true, nombre: 'Paulina').pedido,
        endsWith('Ahora presenta «Proud Mary» — nunca la ha escuchado. Una sola frase corta.'));
  });

  test('hablada: el ánimo no se ve y se oye; pausas entre frases', () {
    final e = hablada('[Emocionada] ¡Aquí viene Reptilia! Súbele... que esto <arde> & ya.');
    expect(e.texto, '¡Aquí viene Reptilia! Súbele... que esto <arde> & ya.');
    expect(
        e.ssml,
        '<speak><prosody rate="112%" pitch="+12%">¡Aquí viene Reptilia! <break time="300ms"/> '
        'Súbele… <break time="400ms"/> que esto &lt;arde&gt; &amp; ya.</prosody></speak>');
    expect(hablada('[furiosa] Hola.').texto, 'Hola.', reason: 'un ánimo que no está no se dice');
    expect(hablada('[furiosa] Hola.').ssml, contains('rate="100%"'));
    expect(hablada('Sin etiqueta.').texto, 'Sin etiqueta.');
    expect(hablada(' [tranquila] ').texto, isEmpty);
  });

  test('en el iPhone habla la locutora del teléfono, nunca el servidor', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final llamadas = <String>[];
    Map? dicho;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('rockola/locutor'), (c) async {
      llamadas.add(c.method);
      if (c.method == 'decir') dicho = c.arguments;
      return switch (c.method) { 'voz' => 'Paulina', 'escribir' => ' [alegre] Arrancamos. ', 'decir' => '/tmp/entrada.caf', _ => null };
    });
    SharedPreferences.setMockInitialValues({'locutor': 'http://loc'});
    final iphone = SesionRadio(jf, cliente: s.cliente);
    addTearDown(iphone.dispose);

    await iphone.configurar();
    expect(iphone.nombre, 'Paulina', reason: 'el nombre es el de la voz, no el del servidor');
    await iphone.sintonizar(mezclas);
    expect(s.pedidos, isEmpty);
    expect(llamadas, containsAllInOrder(['escribir', 'decir']));
    final apertura = cola.queue.value.first;
    expect(esLocutor(apertura), isTrue);
    expect(apertura.id, 'file:///tmp/entrada.caf');
    expect(apertura.extras!['texto'], 'Arrancamos.');
    expect(dicho!['texto'], 'Arrancamos.');
    expect(dicho!['ssml'], '<speak><prosody rate="105%" pitch="+6%">Arrancamos.</prosody></speak>');
  });

  testWidgets('en Ajustes del iPhone se elige la voz, y la locutora habla con ella', (tester) async {
    final llamadas = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('rockola/locutor'), (c) async {
      llamadas.add(c);
      return switch (c.method) {
        'voces' => [
            {'id': 'premium.Paulina', 'nombre': 'Paulina', 'detalle': 'español (México) · Premium'},
            {'id': 'Jorge', 'nombre': 'Jorge', 'detalle': 'español (España)'},
          ],
        'voz' => c.arguments['voz'] == 'Jorge' ? 'Jorge' : 'Paulina',
        'escribir' => 'Hola.',
        'decir' => '/tmp/e.caf',
        _ => null,
      };
    });
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(MaterialApp(theme: tema, home: const Scaffold(body: VozLocutora())));
    await tester.pumpAndSettle();
    expect(find.text('español (México) · Premium'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget, reason: 'Automática, de entrada');

    await tester.tap(find.byTooltip('Oír Jorge'));
    expect(llamadas.last.arguments, {'voz': 'Jorge'});
    await tester.tap(find.text('Jorge'));
    await tester.pumpAndSettle();
    expect((await SharedPreferences.getInstance()).getString('voz'), 'Jorge');

    final locutor = LocutorIphone();
    expect(await locutor.nombre(), 'Jorge');
    await tester.runAsync(() => locutor.entrada(null, (titulo: 'Reptilia', artista: null, album: null, anio: null, escuchas: null)));
    expect(llamadas.lastWhere((c) => c.method == 'decir').arguments['voz'], 'Jorge');
  });
}
