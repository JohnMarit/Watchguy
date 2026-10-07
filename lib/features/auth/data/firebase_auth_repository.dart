import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/storage/org_database.dart';
import '../domain/app_user.dart';
import '../domain/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this.auth, this.database);

  final FirebaseAuth auth;
  final OrgDatabase database;
  var _googleReady = false;

  Future<GoogleSignIn> _google() async {
    final google = GoogleSignIn.instance;
    if (!_googleReady) {
      await google.initialize();
      _googleReady = true;
    }
    return google;
  }

  @override
  Stream<AppUser?> watchUser() {
    return auth.authStateChanges().asyncMap(_mapUser);
  }

  @override
  Future<AppUser?> currentUser() => _mapUser(auth.currentUser);

  @override
  Future<AppUser> confirmVerification() async {
    final user = auth.currentUser;
    if (user == null) throw const AppException('auth', 'Sign in first.');
    await user.reload();
    final refreshed = auth.currentUser;
    if (refreshed == null || !refreshed.emailVerified) {
      throw const AppException('auth', 'Email is not verified yet.');
    }
    return (await _mapUser(refreshed))!;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      throw AppException('auth', error.message ?? 'Could not send the reset email.');
    }
  }

  @override
  Future<AppUser> signInWithApple() async {
    try {
      final apple = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
      );
      final credential = OAuthProvider('apple.com').credential(
        idToken: apple.identityToken,
        accessToken: apple.authorizationCode,
      );
      final result = await auth.signInWithCredential(credential);
      final user = await _mapUser(result.user);
      if (user == null) throw const AppException('auth', 'Apple sign-in failed.');
      return user;
    } on SignInWithAppleAuthorizationException catch (error) {
      throw AppException('auth', error.message);
    } on FirebaseAuthException catch (error) {
      throw AppException('auth', error.message ?? 'Apple sign-in failed.');
    }
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    try {
      final google = await _google();
      final account = await google.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const AppException('auth', 'Google sign-in did not return an identity token.');
      }
      final authorization = await account.authorizationClient.authorizationForScopes(const ['email']);
      final credential = GoogleAuthProvider.credential(
        accessToken: authorization?.accessToken,
        idToken: idToken,
      );
      final result = await auth.signInWithCredential(credential);
      final user = await _mapUser(result.user);
      if (user == null) throw const AppException('auth', 'Google sign-in failed.');
      return user;
    } on FirebaseAuthException catch (error) {
      throw AppException('auth', error.message ?? 'Google sign-in failed.');
    }
  }

  @override
  Future<AppUser> signInWithEmail({required String email, required String password}) async {
    try {
      final result = await auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = await _mapUser(result.user);
      if (user == null) throw const AppException('auth', 'Sign-in failed.');
      return user;
    } on FirebaseAuthException catch (error) {
      throw AppException('auth', _friendly(error));
    }
  }

  @override
  Future<AppUser> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final result = await auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await result.user?.updateDisplayName(displayName.trim());
      await result.user?.sendEmailVerification();
      final user = await _mapUser(auth.currentUser);
      if (user == null) throw const AppException('auth', 'Could not create the account.');
      return user;
    } on FirebaseAuthException catch (error) {
      throw AppException('auth', _friendly(error));
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _google().then((google) => google.signOut());
    } catch (_) {}
    await auth.signOut();
  }

  Future<AppUser?> _mapUser(User? user) async {
    if (user == null) return null;
    final appUser = AppUser(
      id: user.uid,
      email: user.email ?? '',
      displayName: user.displayName ?? user.email ?? 'Operator',
      emailVerified: user.emailVerified,
      photoUrl: user.photoURL,
    );
    await database.saveUserProfile(appUser);
    return appUser;
  }

  String _friendly(FirebaseAuthException error) {
    return switch (error.code) {
      'invalid-email' => 'Enter a valid email.',
      'user-not-found' || 'wrong-password' || 'invalid-credential' =>
        'Email or password is incorrect.',
      'email-already-in-use' => 'An account with that email already exists.',
      'weak-password' => 'Use at least 8 characters.',
      'too-many-requests' => 'Too many attempts. Wait a moment and try again.',
      _ => error.message ?? 'Authentication failed.',
    };
  }
}
