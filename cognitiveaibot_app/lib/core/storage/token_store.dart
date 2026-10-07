import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the session token is kept between launches.
abstract interface class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> delete();
}

/// The session token in the Keychain (iOS/macOS) or Keystore (Android).
///
/// macOS: the data-protection keychain needs a team-signed build (it uses the
/// keychain-access-groups entitlement). A locally built, ad-hoc signed app
/// gets error -34018 instead; it then keeps the token in a file inside its
/// own sandbox container, which only this app can read. (The legacy login
/// keychain is never used: it would show a password prompt to the user.)
class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage(mOptions: MacOsOptions(usesDataProtectionKeychain: true));

  static const _key = 'cognitiveaibot.session_token';
  final FlutterSecureStorage _storage;
  bool _useFile = false;

  static bool _missingEntitlement(Object e) => e is PlatformException && e.code.contains('-34018') ||
      e is PlatformException && (e.message ?? '').contains('entitlement') ||
      e.toString().contains('-34018');

  File? get _file {
    if (kIsWeb || !Platform.isMacOS) return null;
    final home = Platform.environment['HOME'];
    return home == null ? null : File('$home/Library/Application Support/cognitiveaibot/session');
  }

  Future<T?> _keychain<T>(Future<T?> Function() call) async {
    if (_useFile) return null;
    try {
      return await call();
    } catch (e) {
      if (_missingEntitlement(e) && _file != null) {
        _useFile = true;
      } else {
        debugPrint('[TokenStore] keychain error: $e');
      }
      return null;
    }
  }

  @override
  Future<String?> read() async {
    final token = await _keychain(() => _storage.read(key: _key));
    if (token != null && token.isNotEmpty) return token;
    // A keychain read can't tell "no entitlement" from "nothing saved", so
    // the sandbox file is checked whenever the keychain has nothing.
    final f = _file;
    if (f == null) return null;
    try {
      return await f.exists() ? (await f.readAsString()).trim() : null;
    } catch (e) {
      debugPrint('[TokenStore] read failed: $e');
      return null;
    }
  }

  @override
  Future<void> write(String token) async {
    await _keychain(() => _storage.write(key: _key, value: token));
    if (!_useFile) return;
    try {
      final f = _file!;
      await f.parent.create(recursive: true);
      await f.writeAsString(token, flush: true);
    } catch (e) {
      // The session still works for this launch; it just won't be restored.
      debugPrint('[TokenStore] write failed: $e');
    }
  }

  @override
  Future<void> delete() async {
    await _keychain(() => _storage.delete(key: _key));
    final f = _file;
    if (f == null) return;
    try {
      if (await f.exists()) await f.delete();
    } catch (e) {
      debugPrint('[TokenStore] delete failed: $e');
    }
  }
}

/// Keeps the token in memory only (tests).
class MemoryTokenStore implements TokenStore {
  MemoryTokenStore([this._token]);

  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> delete() async => _token = null;
}
