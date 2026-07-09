import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/app/cloud_folder_channel.dart';
import 'package:todoapp/core/cloud_folder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const locator = IcloudFolderChannel();

  void mockNative(Future<Object?> Function(MethodCall) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(IcloudFolderChannel.channel, handler);
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(IcloudFolderChannel.channel, null);
  });

  test('returns the container Documents path from the native side', () async {
    mockNative((call) async {
      expect(call.method, 'icloudDocumentsPath');
      return '/mobile/containers/icloud~com~sai~knot/Documents';
    });
    expect(
      await locator.documentsPath(),
      '/mobile/containers/icloud~com~sai~knot/Documents',
    );
    expect(locator.isSupported, isTrue);
  });

  test(
    'null when iCloud is unavailable (signed out / no entitlement)',
    () async {
      mockNative((call) async => null);
      expect(await locator.documentsPath(), isNull);
    },
  );

  test('null on platform errors', () async {
    mockNative((call) async => throw PlatformException(code: 'boom'));
    expect(await locator.documentsPath(), isNull);
  });

  test('null when no native handler is registered', () async {
    expect(await locator.documentsPath(), isNull);
  });

  test('bookmark round-trip passes arguments through', () async {
    mockNative(
      (call) async => switch (call.method) {
        'createBookmark' when (call.arguments as Map)['path'] == '/Drive/box' =>
          'Ym9va21hcms=',
        'resolveBookmark'
            when (call.arguments as Map)['bookmark'] == 'Ym9va21hcms=' =>
          '/Drive/moved-box',
        _ => throw PlatformException(code: 'unexpected'),
      },
    );
    expect(await locator.createBookmark('/Drive/box'), 'Ym9va21hcms=');
    expect(await locator.resolveBookmark('Ym9va21hcms='), '/Drive/moved-box');
  });

  test('bookmark methods are null where unimplemented (iOS)', () async {
    // No mock handler → MissingPluginException, the same failure mode as a
    // native side that answers FlutterMethodNotImplemented.
    expect(await locator.createBookmark('/x'), isNull);
    expect(await locator.resolveBookmark('AAAA'), isNull);
  });

  test('Android SAF picker returns a persistable tree URI', () async {
    const android = AndroidSafFolderChannel();
    mockNative((call) async {
      expect(call.method, 'pickAndroidTree');
      return 'content://com.android.externalstorage.documents/tree/primary%3AKnot';
    });
    expect(
      await android.documentsPath(),
      'content://com.android.externalstorage.documents/tree/primary%3AKnot',
    );
    expect(android.isSupported, isTrue);
  });

  test('Android SAF bookmark helpers pass content URI through', () async {
    const android = AndroidSafFolderChannel();
    mockNative(
      (call) async => switch (call.method) {
        'createBookmark'
            when (call.arguments as Map)['path'] == 'content://tree/knot' =>
          'content://tree/knot',
        'resolveBookmark'
            when (call.arguments as Map)['bookmark'] == 'content://tree/knot' =>
          'content://tree/knot',
        _ => throw PlatformException(code: 'unexpected'),
      },
    );
    expect(
      await android.createBookmark('content://tree/knot'),
      'content://tree/knot',
    );
    expect(
      await android.resolveBookmark('content://tree/knot'),
      'content://tree/knot',
    );
  });

  test('unsupported platforms report unsupported and null', () async {
    const unsupported = UnsupportedCloudFolder();
    expect(unsupported.isSupported, isFalse);
    expect(await unsupported.documentsPath(), isNull);
    expect(await unsupported.createBookmark('/x'), isNull);
    expect(await unsupported.resolveBookmark('AAAA'), isNull);
  });
}
