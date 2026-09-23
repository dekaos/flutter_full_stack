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
    registerBackupExclusion(with: engineBridge.pluginRegistry)
  }

  /// Keeps a path out of iCloud and computer backups: the language packs,
  /// which can be fetched again and would otherwise put 355 MB each in the
  /// learner's backup. See lib/core/backup_exclusion.dart.
  private func registerBackupExclusion(with registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "BackupExclusion") else { return }
    let channel = FlutterMethodChannel(
      name: "br.com.stuhler.flutter_full_stack/backup",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "exclude", let path = call.arguments as? String else {
        result(FlutterMethodNotImplemented)
        return
      }
      var url = URL(fileURLWithPath: path)
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      do {
        try url.setResourceValues(values)
        result(nil)
      } catch {
        result(
          FlutterError(
            code: "exclude_failed", message: error.localizedDescription, details: path))
      }
    }
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
