import '../data/sync/device_identity.dart';
import 'key_store_factory_native.dart'
    if (dart.library.js_interop) 'key_store_factory_web.dart';

KeyStore createKeyStore() => createKeyStoreImpl();
