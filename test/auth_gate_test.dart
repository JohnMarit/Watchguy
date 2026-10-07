import 'package:flutter_test/flutter_test.dart';
import 'package:watchguy/core/models/enums.dart';
import 'package:watchguy/features/auth/domain/app_user.dart';
import 'package:watchguy/features/auth/domain/auth_gate.dart';

void main() {
  const user = AppUser(id: 'u1', email: 'a@b.com', displayName: 'A', emailVerified: true);
  const unverified = AppUser(id: 'u1', email: 'a@b.com', displayName: 'A', emailVerified: false);

  test('authentication gate follows the launch sequence', () {
    expect(resolveGate(loading: true, user: null, hasOrganization: false, mode: null), AppGate.loading);
    expect(resolveGate(loading: false, user: null, hasOrganization: false, mode: null), AppGate.signedOut);
    expect(resolveGate(loading: false, user: unverified, hasOrganization: false, mode: null), AppGate.verifyEmail);
    expect(resolveGate(loading: false, user: user, hasOrganization: false, mode: null), AppGate.createOrganization);
    expect(resolveGate(loading: false, user: user, hasOrganization: true, mode: null), AppGate.chooseMode);
    expect(
      resolveGate(loading: false, user: user, hasOrganization: true, mode: AppMode.dashboard),
      AppGate.dashboard,
    );
    expect(redirectFor(AppGate.signedOut, '/dashboard'), '/sign-in');
    expect(redirectFor(AppGate.dashboard, '/sign-in'), '/dashboard');
    expect(redirectFor(AppGate.camera, '/camera/settings'), isNull);
  });
}
