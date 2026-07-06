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

    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "CloudFolder")
    else { return }
    let channel = FlutterMethodChannel(
      name: "com.sai.knot/cloud_folder", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      guard call.method == "icloudDocumentsPath" else {
        result(FlutterMethodNotImplemented)
        return
      }
      // url(forUbiquityContainerIdentifier:) can block; keep it off the main
      // thread. Returns nil without the iCloud entitlement (needs the Apple
      // Developer account, docs/packaging.md) or when the user is signed out
      // or has iCloud Drive disabled.
      DispatchQueue.global(qos: .userInitiated).async {
        var path: String? = nil
        if let container = FileManager.default.url(forUbiquityContainerIdentifier: nil) {
          let docs = container.appendingPathComponent("Documents", isDirectory: true)
          try? FileManager.default.createDirectory(
            at: docs, withIntermediateDirectories: true)
          path = docs.path
        }
        DispatchQueue.main.async { result(path) }
      }
    }
  }
}
