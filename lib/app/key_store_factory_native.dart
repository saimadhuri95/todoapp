import 'package:path_provider/path_provider.dart';

import '../data/sync/device_identity.dart';

KeyStore createKeyStoreImpl() => FallbackKeyStore(
  primary: const SecureKeyStore(),
  fallback: FileKeyStore(getApplicationSupportDirectory),
);
