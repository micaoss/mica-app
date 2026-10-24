import Flutter
import NetworkExtension
import UIKit

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
    // `mica/wifi` join {ssid, psk}: the device's hotspot, through
    // NEHotspotConfiguration (the Hotspot Configuration entitlement).
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "MicaWifi") else { return }
    FlutterMethodChannel(name: "mica/wifi", binaryMessenger: registrar.messenger()).setMethodCallHandler { call, result in
      guard call.method == "join", let args = call.arguments as? [String: String],
        let ssid = args["ssid"], let psk = args["psk"]
      else { return result(FlutterMethodNotImplemented) }
      NEHotspotConfigurationManager.shared.apply(NEHotspotConfiguration(ssid: ssid, passphrase: psk, isWEP: false)) {
        error in
        let e = error as NSError?
        result(
          e == nil
            || (e!.domain == NEHotspotConfigurationErrorDomain
              && e!.code == NEHotspotConfigurationError.alreadyAssociated.rawValue))
      }
    }
  }
}
