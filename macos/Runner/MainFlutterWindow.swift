import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let channel = FlutterMethodChannel(
      name: "com.sai.knot/cloud_folder",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "icloudDocumentsPath":
        // url(forUbiquityContainerIdentifier:) can block; keep it off the
        // main thread. Returns nil without the iCloud entitlement (needs the
        // Apple Developer account, docs/packaging.md) or when the user is
        // signed out or has iCloud Drive disabled.
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

      case "createBookmark":
        // App-scoped security bookmark: what lets the sandboxed app reopen a
        // user-picked folder after relaunch (TASKS.md 4.18).
        guard let args = call.arguments as? [String: Any],
          let path = args["path"] as? String
        else {
          result(FlutterError(code: "bad-args", message: "path required", details: nil))
          return
        }
        do {
          let data = try URL(fileURLWithPath: path, isDirectory: true).bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil, relativeTo: nil)
          result(data.base64EncodedString())
        } catch {
          result(FlutterError(
            code: "bookmark", message: error.localizedDescription, details: nil))
        }

      case "resolveBookmark":
        guard let args = call.arguments as? [String: Any],
          let encoded = args["bookmark"] as? String,
          let data = Data(base64Encoded: encoded)
        else {
          result(FlutterError(code: "bad-args", message: "bookmark required", details: nil))
          return
        }
        do {
          var stale = false
          let url = try URL(
            resolvingBookmarkData: data, options: .withSecurityScope,
            relativeTo: nil, bookmarkDataIsStale: &stale)
          // Access stays open for the app's lifetime — the sync engine reads
          // the folder continuously, so there is no matching stop call.
          _ = url.startAccessingSecurityScopedResource()
          result(url.path)
        } catch {
          result(FlutterError(
            code: "bookmark", message: error.localizedDescription, details: nil))
        }

      case "shareFolder":
        guard let args = call.arguments as? [String: Any],
          let path = args["path"] as? String
        else {
          result(false)
          return
        }
        let url = URL(fileURLWithPath: path, isDirectory: true)
        NSWorkspace.shared.activateFileViewerSelecting([url])
        result(true)

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }
}
