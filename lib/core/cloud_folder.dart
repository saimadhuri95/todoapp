/// Platform-provided cloud-synced folder for the mailbox transport
/// (TASKS.md 3.12). Interface lives here per CLAUDE.md: platform-specific
/// folder access goes behind a Dart abstraction; the method-channel
/// implementation is in `lib/app/cloud_folder_channel.dart`.
abstract interface class CloudFolderLocator {
  /// Whether this platform can offer a managed cloud folder at all
  /// (iOS/macOS iCloud Drive). UI hides the option when false.
  bool get isSupported;

  /// Path to a Documents directory inside the app's iCloud Drive container,
  /// created on demand. Null when unavailable: not signed in to iCloud,
  /// iCloud Drive disabled, or the app was built without the iCloud
  /// entitlement (see docs/packaging.md — needs the Apple Developer account).
  Future<String?> documentsPath();

  /// App-scoped security bookmark for a user-picked folder (TASKS.md 4.18).
  /// The macOS sandbox forgets picker grants on relaunch; the bookmark is
  /// what makes access durable. Null where the platform doesn't need one —
  /// callers then rely on the plain path.
  Future<String?> createBookmark(String path);

  /// Resolves a bookmark from [createBookmark], starting security-scoped
  /// access. Returns the folder's current path (it may have moved), or null
  /// if the bookmark can't be resolved.
  Future<String?> resolveBookmark(String bookmark);

  /// Opens the platform's sharing surface for an iCloud/folder backend.
  /// Returns false when the platform cannot present one; callers should then
  /// point the user to the manual Files/Finder sharing fallback.
  Future<bool> shareFolder(String path);
}

/// Platforms with no managed cloud folder (Windows/Linux/Android use the
/// generic directory picker instead).
class UnsupportedCloudFolder implements CloudFolderLocator {
  const UnsupportedCloudFolder();

  @override
  bool get isSupported => false;

  @override
  Future<String?> documentsPath() async => null;

  @override
  Future<String?> createBookmark(String path) async => null;

  @override
  Future<String?> resolveBookmark(String bookmark) async => null;

  @override
  Future<bool> shareFolder(String path) async => false;
}
