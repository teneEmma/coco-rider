import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the session survives app restarts (Keychain on iOS, Keystore on Android).
abstract class TokenStore {
  Future<String?> read();

  Future<void> write(String value);

  Future<void> delete();

  factory TokenStore.secure() = _SecureTokenStore;

  factory TokenStore.memory() = MemoryTokenStore;
}

class _SecureTokenStore implements TokenStore {
  static const _key = 'coco_rider_session';
  final _storage = const FlutterSecureStorage();

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);

  @override
  Future<void> delete() => _storage.delete(key: _key);
}

class MemoryTokenStore implements TokenStore {
  String? _value;

  @override
  Future<String?> read() async => _value;

  @override
  Future<void> write(String value) async => _value = value;

  @override
  Future<void> delete() async => _value = null;
}
