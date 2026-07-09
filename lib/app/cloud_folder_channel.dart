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

  @override
  Future<bool> shareFolder(String path) async {
    try {
      return await channel.invokeMethod<bool>('shareFolder', {'path': path}) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

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

/// Android Storage Access Framework folder grant for the mailbox transport.
///
/// The selected tree is a durable `content://` URI, not a filesystem path, so
/// `createFolderMailboxStore` routes it to an Android ContentResolver-backed
/// mailbox store instead of the plain directory store.
class AndroidSafFolderChannel implements CloudFolderLocator {
  const AndroidSafFolderChannel();

  static const channel = IcloudFolderChannel.channel;

  @override
  bool get isSupported => true;

  @override
  Future<String?> documentsPath() =>
      _invoke('pickAndroidTree', const <String, String>{});

  @override
  Future<String?> createBookmark(String path) =>
      _invoke('createBookmark', {'path': path});

  @override
  Future<String?> resolveBookmark(String bookmark) =>
      _invoke('resolveBookmark', {'bookmark': bookmark});

  @override
  Future<bool> shareFolder(String path) async => false;

  Future<String?> _invoke(String method, Map<String, String> args) async {
    try {
      return await channel.invokeMethod<String>(method, args);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}

/// The locator for the platform we're running on. Used by the provider and
/// by main()'s startup bookmark resolution (which runs before providers).
CloudFolderLocator platformCloudFolder() {
  if (platformSupportsIcloud) return const IcloudFolderChannel();
  if (platformIsAndroid) return const AndroidSafFolderChannel();
  return const UnsupportedCloudFolder();
}
