import 'app_user.dart';

abstract class AuthRepository {
  Stream<AppUser?> watchUser();
  Future<AppUser?> currentUser();
  Future<AppUser> signInWithEmail({required String email, required String password});
  Future<AppUser> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  });
  Future<void> sendPasswordReset(String email);
  Future<AppUser> confirmVerification();
  Future<AppUser> signInWithGoogle();
  Future<AppUser> signInWithApple();
  Future<void> signOut();
}
