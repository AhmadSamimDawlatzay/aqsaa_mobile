import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/auth_models.dart';

// The only platform boundary: tests replace this with an in-memory implementation.
abstract interface class SecureKeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class PlatformSecureStore implements SecureKeyValueStore {
  PlatformSecureStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(resetOnError: false),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.unlocked_this_device,
            ),
          );
  final FlutterSecureStorage _storage;
  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class SessionStorageException implements Exception {
  const SessionStorageException();
}

class SessionStore {
  SessionStore(this._storage);
  final SecureKeyValueStore _storage;
  static const deviceKey = 'aqsaa.installation.v1';
  String _sessionKey(String scope) =>
      'aqsaa.session.v1.${base64Url.encode(utf8.encode(scope))}';

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (_) {
      throw const SessionStorageException();
    }
  }

  Future<String> deviceId() => _guard(() async {
    final existing = await _storage.read(deviceKey);
    if (existing != null) {
      if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(existing)) {
        throw const FormatException('Invalid installation ID');
      }
      return existing;
    }
    final random = Random.secure();
    final id = List.generate(
      32,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    await _storage.write(deviceKey, id);
    return id;
  });

  Future<SessionCredential?> read(String scope) => _guard(() async {
    final raw = await _storage.read(_sessionKey(scope));
    if (raw == null) return null;
    final data = authObject(jsonDecode(raw));
    // Defense in depth: even a copied record cannot authorize another server.
    if (data['api_base'] != scope) {
      throw const FormatException('Wrong session scope');
    }
    return SessionCredential(
      apiBase: scope,
      token: authString(data['token']),
      expiresAt: DateTime.parse(authString(data['expires_at'])),
    );
  });
  Future<void> save(SessionCredential session) => _guard(
    () => _storage.write(
      _sessionKey(session.apiBase),
      jsonEncode({
        'api_base': session.apiBase,
        'token': session.token,
        'expires_at': session.expiresAt.toUtc().toIso8601String(),
      }),
    ),
  );
  Future<void> clear(String scope) =>
      _guard(() => _storage.delete(_sessionKey(scope)));
}
