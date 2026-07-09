import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/data/sync/mailbox_store.dart';
import 'package:todoapp/data/sync/mailbox_store_factory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const treeUri = 'content://com.android.externalstorage.documents/tree/knot';
  final store = AndroidSafMailboxStore(treeUri);
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidSafMailboxStore.channel, (call) async {
          calls.add(call);
          final args = (call.arguments as Map).cast<String, Object?>();
          expect(args['treeUri'], treeUri);
          return switch (call.method) {
            'listDeviceDirs' => ['device-a', 'device-b'],
            'listFiles' when args['deviceDir'] == 'device-a' => [
              '1.bin',
              '2.bin',
            ],
            'readFile'
                when args['deviceDir'] == 'device-a' &&
                    args['name'] == '1.bin' =>
              Uint8List.fromList([1, 2, 3]),
            'writeFile' => null,
            'deleteFile' => null,
            'wipeTree' => null,
            _ => throw PlatformException(code: 'unexpected'),
          };
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidSafMailboxStore.channel, null);
  });

  test('factory routes content URIs to the Android SAF mailbox store', () {
    expect(createFolderMailboxStore(treeUri), isA<AndroidSafMailboxStore>());
  });

  test('delegates mailbox operations to the native SAF channel', () async {
    expect(await store.listDeviceDirs(), ['device-a', 'device-b']);
    expect(await store.listFiles('device-a'), ['1.bin', '2.bin']);
    expect(await store.read('device-a', '1.bin'), [1, 2, 3]);

    await store.write('device-a', '3.bin', [4, 5]);
    await store.delete('device-a', '2.bin');
    await store.wipeAll();

    expect(calls.map((call) => call.method), [
      'listDeviceDirs',
      'listFiles',
      'readFile',
      'writeFile',
      'deleteFile',
      'wipeTree',
    ]);
    final writeArgs = (calls[3].arguments as Map).cast<String, Object?>();
    expect(writeArgs['deviceDir'], 'device-a');
    expect(writeArgs['name'], '3.bin');
    expect(writeArgs['bytes'], isA<Uint8List>());
    expect(writeArgs['bytes'] as Uint8List, [4, 5]);
  });
}
