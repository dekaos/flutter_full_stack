import Flutter
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
    registerAppSettings(with: engineBridge.pluginRegistry)
  }

  /// The app's own page in Settings, where a refused permission can be
  /// granted again. See lib/core/app_settings.dart.
  private func registerAppSettings(with registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "AppSettings") else { return }
    let channel = FlutterMethodChannel(
      name: "br.com.stuhler.flutter_full_stack/app_settings",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "open",
        let url = URL(string: UIApplication.openSettingsURLString)
      else {
        result(FlutterMethodNotImplemented)
        return
      }
      UIApplication.shared.open(url) { _ in result(nil) }
    }
  }
}
