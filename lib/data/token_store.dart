import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Abstract interface for persisting and retrieving edit tokens keyed by shop ID.
abstract class TokenStore {
  /// Returns the edit token for [shopId], or null if none is stored.
  Future<String?> read(String shopId);

  /// Persists [token] for [shopId], overwriting any existing value.
  Future<void> write(String shopId, String token);

  /// Removes the edit token for [shopId].
  Future<void> delete(String shopId);
}

/// [TokenStore] implementation backed by [FlutterSecureStorage].
///
/// Tokens are stored under the key `edit_token_<shopId>` so they are
/// namespaced and cannot collide with other secure-storage entries.
class SecureTokenStore implements TokenStore {
  final FlutterSecureStorage _storage;

  SecureTokenStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  String _key(String shopId) => 'edit_token_$shopId';

  @override
  Future<String?> read(String shopId) => _storage.read(key: _key(shopId));

  @override
  Future<void> write(String shopId, String token) =>
      _storage.write(key: _key(shopId), value: token);

  @override
  Future<void> delete(String shopId) => _storage.delete(key: _key(shopId));
}
