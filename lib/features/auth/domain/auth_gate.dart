import '../../../core/models/enums.dart';
import 'app_user.dart';

enum AppGate {
  loading,
  signedOut,
  verifyEmail,
  createOrganization,
  chooseMode,
  dashboard,
  camera,
}

AppGate resolveGate({
  required bool loading,
  required AppUser? user,
  required bool hasOrganization,
  required AppMode? mode,
}) {
  if (loading) return AppGate.loading;
  if (user == null) return AppGate.signedOut;
  if (!user.emailVerified) return AppGate.verifyEmail;
  if (!hasOrganization) return AppGate.createOrganization;
  return switch (mode) {
    null => AppGate.chooseMode,
    AppMode.dashboard => AppGate.dashboard,
    AppMode.camera => AppGate.camera,
  };
}

String? redirectFor(AppGate gate, String path) {
  const publicPaths = {'/sign-in', '/sign-up', '/reset-password'};
  return switch (gate) {
    AppGate.loading => path == '/' ? null : '/',
    AppGate.signedOut => publicPaths.contains(path) ? null : '/sign-in',
    AppGate.verifyEmail => path == '/verify-email' ? null : '/verify-email',
    AppGate.createOrganization => path == '/organization' ? null : '/organization',
    AppGate.chooseMode => path == '/mode' ? null : '/mode',
    AppGate.dashboard => path.startsWith('/dashboard') ? null : '/dashboard',
    AppGate.camera => path.startsWith('/camera') ? null : '/camera',
  };
}
