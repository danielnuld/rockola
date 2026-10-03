import AVFoundation
import CoreMedia
import Flutter
import UIKit
import FoundationModels

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let r = engineBridge.pluginRegistry.registrar(forPlugin: "Locutora") {
      Locutora.shared.escuchar(r.messenger())
    }
    if let r = engineBridge.pluginRegistry.registrar(forPlugin: "Huella") {
      Huella.escuchar(r.messenger())
    }
  }
}

/// El audio de una cancion descargada para calcular su huella en Dart
/// (huellaDePcm en lib/huella.dart): PCM mono de 16 bits a 22 050 Hz, como el
/// ffmpeg de servidor/huellas.py.
enum Huella {
  struct SinAudio: Error {}

  static func escuchar(_ mensajero: FlutterBinaryMessenger) {
    FlutterMethodChannel(name: "rockola/huella", binaryMessenger: mensajero).setMethodCallHandler { llamada, responder in
      guard llamada.method == "pcm", let ruta = llamada.arguments as? String else { return responder(FlutterMethodNotImplemented) }
      DispatchQueue.global(qos: .utility).async {
        let r: Any
        do {
          r = FlutterStandardTypedData(bytes: try pcm(ruta))
        } catch {
          r = FlutterError(code: "huella", message: "\(error)", details: nil)
        }
        DispatchQueue.main.async { responder(r) }
      }
    }
  }

  /// AVFoundation decodifica, mezcla a mono y remuestrea de una vez. Lo que no
  /// abre (ogg, opus, wma) lanza, y la cancion se queda sin huella.
  static func pcm(_ ruta: String) throws -> Data {
    let asset = AVURLAsset(url: URL(fileURLWithPath: ruta))
    let pistas = asset.tracks(withMediaType: .audio)
    guard !pistas.isEmpty else { throw SinAudio() }
    let lector = try AVAssetReader(asset: asset)
    let salida = AVAssetReaderAudioMixOutput(audioTracks: pistas, audioSettings: [
      AVFormatIDKey: kAudioFormatLinearPCM,
      AVSampleRateKey: 22050,
      AVNumberOfChannelsKey: 1,
      AVLinearPCMBitDepthKey: 16,
      AVLinearPCMIsFloatKey: false,
      AVLinearPCMIsBigEndianKey: false,
      AVLinearPCMIsNonInterleaved: false,
    ])
    lector.add(salida)
    guard lector.startReading() else { throw lector.error ?? SinAudio() }
    var datos = Data()
    while let muestra = salida.copyNextSampleBuffer() {
      guard let bloque = CMSampleBufferGetDataBuffer(muestra) else { continue }
      let largo = CMBlockBufferGetDataLength(bloque)
      var trozo = Data(count: largo)
      trozo.withUnsafeMutableBytes { _ = CMBlockBufferCopyDataBytes(bloque, atOffset: 0, dataLength: largo, destination: $0.baseAddress!) }
      datos.append(trozo)
    }
    if lector.status == .failed { throw lector.error ?? SinAudio() }
    return datos
  }
}

/// La locutora de la radio en el propio iPhone (LocutorIphone en lib/locutor.dart):
/// el texto con Foundation Models, la voz con el sintetizador del sistema.
final class Locutora {
  static let shared = Locutora()
  private let sintetizador = AVSpeechSynthesizer()
  private let muestra = AVSpeechSynthesizer() // el que suena, para probar voces en Ajustes
  private var canal: FlutterMethodChannel?

  func escuchar(_ mensajero: FlutterBinaryMessenger) {
    let c = FlutterMethodChannel(name: "rockola/locutor", binaryMessenger: mensajero)
    c.setMethodCallHandler { [weak self] llamada, responder in
      guard let self else { return }
      // Los null de Dart llegan como NSNull: `as? String` los deja en nil.
      let args = llamada.arguments as? [String: Any] ?? [:]
      let voz = self.voz(args["voz"] as? String)
      switch llamada.method {
      case "voz":
        responder(self.hayModelo ? voz.name : nil)
      case "voces":
        responder(self.enEspanol().map { v in
          // Por numero: .premium (3) es de iOS 16 y la app llega a iOS 15.
          let calidad = v.quality.rawValue >= 3 ? " · Premium" : v.quality.rawValue == 2 ? " · Mejorada" : ""
          return ["id": v.identifier, "nombre": v.name, "detalle": (Locale.current.localizedString(forIdentifier: v.language) ?? v.language) + calidad]
        })
      case "probar":
        self.muestra.stopSpeaking(at: .immediate)
        let frase = AVSpeechUtterance(string: "Hola, soy \(voz.name). Así sueno en Rockola FM.")
        frase.voice = voz
        self.muestra.speak(frase)
        responder(nil)
      case "escribir":
        Task { @MainActor in responder(await self.escribir(args["instrucciones"] as? String ?? "", args["pedido"] as? String ?? "")) }
      case "decir":
        self.decir(args["texto"] as? String ?? "", ssml: args["ssml"] as? String, voz, responder)
      default:
        responder(FlutterMethodNotImplemented)
      }
    }
    canal = c
  }

  /// iOS 26 con Apple Intelligence encendido (iPhone 15 Pro o posterior).
  private var hayModelo: Bool {
    if #available(iOS 26, *) { return SystemLanguageModel.default.isAvailable }
    return false
  }

  /// Una sesion nueva por entrada: sin historia que crezca. Un error (el modelo
  /// se niega o no esta) llega a Dart como excepcion y la entrada no suena.
  private func escribir(_ instrucciones: String, _ pedido: String) async -> Any? {
    if #available(iOS 26, *) {
      do {
        return try await LanguageModelSession(instructions: instrucciones).respond(to: pedido).content
      } catch {
        return FlutterError(code: "modelo", message: "\(error)", details: nil)
      }
    }
    return FlutterError(code: "sin-modelo", message: nil, details: nil)
  }

  /// Las voces en español instaladas, de mejor a peor: primero la calidad
  /// (premium, mejorada, normal), despues la region del telefono y despues es-MX.
  /// Sin guardar: una voz recien descargada sale sin reabrir la app.
  private func enEspanol() -> [AVSpeechSynthesisVoice] {
    let region = "es-" + ((Locale.current as NSLocale).countryCode ?? "MX")
    func puntos(_ v: AVSpeechSynthesisVoice) -> Int {
      v.quality.rawValue * 10 + (v.language == region ? 2 : v.language == "es-MX" ? 1 : 0)
    }
    return AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("es") }.sorted { puntos($0) > puntos($1) }
  }

  /// La elegida en Ajustes si sigue instalada; si no, la mejor.
  private func voz(_ id: String?) -> AVSpeechSynthesisVoice {
    id.flatMap(AVSpeechSynthesisVoice.init(identifier:)) ?? enEspanol().first ?? AVSpeechSynthesisVoice(language: "es-MX")!
  }

  /// Escribe la voz a un .caf del temporal (iOS lo vacia solo) y responde su ruta.
  /// El sintetizador no suena: solo entrega buffers, y el ultimo viene vacio.
  /// Con SSML (hablada en lib/locutor.dart) varia el ritmo, el tono y las pausas;
  /// en iOS 15, o si no lo entiende, dice el texto plano.
  private func decir(_ texto: String, ssml: String?, _ voz: AVSpeechSynthesisVoice, _ responder: @escaping FlutterResult) {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("locutora-\(UUID().uuidString).caf")
    var conSsml: AVSpeechUtterance?
    if #available(iOS 16, *), let ssml { conSsml = AVSpeechUtterance(ssmlRepresentation: ssml) }
    let frase = conSsml ?? AVSpeechUtterance(string: texto)
    frase.voice = voz
    var archivo: AVAudioFile?
    var listo = false
    func acabar(_ r: Any?) {
      listo = true
      archivo = nil // cierra el archivo
      DispatchQueue.main.async { responder(r) }
    }
    sintetizador.write(frase) { buffer in
      guard !listo else { return }
      guard let pcm = buffer as? AVAudioPCMBuffer, pcm.frameLength > 0 else {
        return acabar(archivo == nil ? FlutterError(code: "voz", message: "sin audio", details: nil) : url.path)
      }
      do {
        if archivo == nil {
          archivo = try AVAudioFile(forWriting: url, settings: pcm.format.settings, commonFormat: pcm.format.commonFormat, interleaved: pcm.format.isInterleaved)
        }
        try archivo?.write(from: pcm)
      } catch {
        acabar(FlutterError(code: "voz", message: "\(error)", details: nil))
      }
    }
  }
}
