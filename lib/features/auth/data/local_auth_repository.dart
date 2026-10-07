import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/storage/document_store.dart';
import '../domain/app_user.dart';
import '../domain/auth_repository.dart';

class LocalAuthRepository implements AuthRepository {
  LocalAuthRepository(this.store);

  final DocumentStore store;
  final StreamController<AppUser?> _controller = StreamController<AppUser?>.broadcast();
  AppUser? _current;
  var _restored = false;

  @override
  Stream<AppUser?> watchUser() async* {
    await _restore();
    yield _current;
    yield* _controller.stream;
  }

  @override
  Future<AppUser?> currentUser() async {
    await _restore();
    return _current;
  }

  @override
  Future<AppUser> confirmVerification() async {
    final user = _requireUser();
    final verified = user.copyWith(emailVerified: true);
    await store.write('authUsers/${user.id}', verified.toJson());
    _set(verified);
    return verified;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    throw const UnavailableException(
      'Local mode has no email service. Sign in with the password you created, or create a new account.',
    );
  }

  @override
  Future<AppUser> signInWithApple() {
    throw const UnavailableException('Apple sign-in needs a configured Firebase project.');
  }

  @override
  Future<AppUser> signInWithGoogle() {
    throw const UnavailableException('Google sign-in needs a configured Firebase project.');
  }

  @override
  Future<AppUser> signInWithEmail({required String email, required String password}) async {
    final users = await store.list('authUsers');
    Map<String, dynamic>? match;
    for (final user in users) {
      if ((user['email'] as String?)?.toLowerCase() == email.trim().toLowerCase()) {
        match = user;
      }
    }
    if (match == null) {
      throw const AppException('auth', 'No account uses that email.');
    }
    final secret = await store.read('authSecrets/${match['id']}');
    if (secret == null || !_passwordMatches(password, secret)) {
      throw const AppException('auth', 'That password is incorrect.');
    }
    final user = AppUser.fromJson(match);
    _set(user);
    await store.write('auth/session', {'userId': user.id});
    return user;
  }

  @override
  Future<AppUser> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    if (!_validEmail(email)) throw const AppException('auth', 'Enter a valid email.');
    if (password.length < 8) {
      throw const AppException('auth', 'Use at least 8 characters.');
    }
    final existing = await store.list('authUsers');
    for (final user in existing) {
      if ((user['email'] as String?)?.toLowerCase() == email.trim().toLowerCase()) {
        throw const AppException('auth', 'An account with that email already exists.');
      }
    }
    final id = 'local_${DateTime.now().microsecondsSinceEpoch}';
    final user = AppUser(
      id: id,
      email: email.trim(),
      displayName: displayName.trim().isEmpty ? email.trim() : displayName.trim(),
      emailVerified: false,
    );
    final salt = _salt();
    await store.write('authUsers/$id', user.toJson());
    await store.write('authSecrets/$id', {
      'salt': salt,
      'hash': sha256.convert(utf8.encode('$salt:$password')).toString(),
    });
    _set(user);
    await store.write('auth/session', {'userId': user.id});
    return user;
  }

  @override
  Future<void> signOut() async {
    _set(null);
    await store.delete('auth/session');
  }

  Future<void> _restore() async {
    if (_restored) return;
    _restored = true;
    final session = await store.read('auth/session');
    final userId = session?['userId'] as String?;
    if (userId == null) return;
    final json = await store.read('authUsers/$userId');
    if (json != null) _current = AppUser.fromJson(json);
  }

  void _set(AppUser? user) {
    _current = user;
    if (!_controller.isClosed) _controller.add(user);
  }

  AppUser _requireUser() {
    final user = _current;
    if (user == null) throw const AppException('auth', 'Sign in first.');
    return user;
  }

  bool _passwordMatches(String password, Map<String, dynamic> secret) {
    final salt = secret['salt'] as String? ?? '';
    final hash = sha256.convert(utf8.encode('$salt:$password')).toString();
    return hash == secret['hash'];
  }

  bool _validEmail(String email) => email.contains('@') && email.contains('.');

  String _salt() {
    final random = Random.secure();
    return List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }
}
