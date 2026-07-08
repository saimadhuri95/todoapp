import '../data/sync/device_identity.dart';

KeyStore createKeyStoreImpl() => FallbackKeyStore(
  primary: const SecureKeyStore(),
  fallback: InMemoryKeyStore(),
);
