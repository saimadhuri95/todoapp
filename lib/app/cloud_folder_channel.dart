import 'package:flutter/services.dart';

import '../core/cloud_folder.dart';
import '../core/platform_info.dart';

/// iCloud Drive ubiquity container via a method channel (TASKS.md 3.12).
/// Swift handlers live in ios/Runner/AppDelegate.swift and
/// macos/Runner/MainFlutterWindow.swift; they resolve the container off the
/// main thread (the FileManager call can block) and return the path of its
/// Documents subfolder, or nil when iCloud is unavailable.
class IcloudFolderChannel implements CloudFolderLocator {
  const IcloudFolderChannel();

  static const channel = MethodChannel('com.sai.knot/cloud_folder');

  @override
  bool get isSupported => true;

  @override
  Future<String?> documentsPath() =>
      _invoke('icloudDocumentsPath', const <String, String>{});

  @override
  Future<String?> createBookmark(String path) =>
      _invoke('createBookmark', {'path': path});

  @override
  Future<String?> resolveBookmark(String bookmark) =>
      _invoke('resolveBookmark', {'bookmark': bookmark});

  Future<String?> _invoke(String method, Map<String, String> args) async {
    try {
      return await channel.invokeMethod<String>(method, args);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      // Native handler absent (tests) or method unimplemented on this
      // platform (bookmarks are macOS-only; iOS answers not-implemented).
      return null;
    }
  }
}

/// The locator for the platform we're running on. Used by the provider and
/// by main()'s startup bookmark resolution (which runs before providers).
CloudFolderLocator platformCloudFolder() => platformSupportsIcloud
    ? const IcloudFolderChannel()
    : const UnsupportedCloudFolder();
