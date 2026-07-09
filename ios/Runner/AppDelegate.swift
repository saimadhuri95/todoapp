import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Set once the engine is up; used to forward OAuth redirects into Dart.
  private var oauthChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// OAuth custom-scheme redirects (knot://oauth and the Google
  /// reversed-client-id scheme, both registered in Info.plist) — forwarded
  /// to lib/app/oauth_callback_channel.dart.
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    let scheme = url.scheme?.lowercased() ?? ""
    if scheme == "knot" || scheme.hasPrefix("com.googleusercontent.apps.") {
      oauthChannel?.invokeMethod("redirect", arguments: url.absoluteString)
      return true
    }
    return super.application(app, open: url, options: options)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    if let oauthRegistrar = engineBridge.pluginRegistry.registrar(forPlugin: "OAuthCallback") {
      oauthChannel = FlutterMethodChannel(
        name: "com.sai.knot/oauth_callback", binaryMessenger: oauthRegistrar.messenger())
    }

    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "CloudFolder")
    else { return }
    let channel = FlutterMethodChannel(
      name: "com.sai.knot/cloud_folder", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      if call.method == "shareFolder" {
        guard let args = call.arguments as? [String: Any],
          let path = args["path"] as? String
        else {
          result(false)
          return
        }
        let url = URL(fileURLWithPath: path, isDirectory: true)
        let windows = UIApplication.shared.connectedScenes
          .compactMap { $0 as? UIWindowScene }
          .flatMap { $0.windows }
        guard let root = windows.first(where: { $0.isKeyWindow })?.rootViewController else {
          result(false)
          return
        }
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let popover = controller.popoverPresentationController {
          popover.sourceView = root.view
          popover.sourceRect = CGRect(
            x: root.view.bounds.midX, y: root.view.bounds.midY, width: 1, height: 1)
        }
        root.present(controller, animated: true) {
          result(true)
        }
        return
      }

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
