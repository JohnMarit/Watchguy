import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/domain/auth_gate.dart';
import '../features/auth/presentation/auth_screens.dart';
import '../features/camera/presentation/camera_mode_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/incidents/presentation/incident_detail_screen.dart';
import '../features/live_stream/presentation/live_view_screen.dart';
import '../features/pairing/presentation/pairing_screens.dart';
import '../features/zones/presentation/zone_editor_screen.dart';
import 'providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);
  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final gate = ref.read(sessionControllerProvider).gate;
      return redirectFor(gate, state.uri.path);
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/sign-in', builder: (context, state) => const SignInScreen()),
      GoRoute(path: '/sign-up', builder: (context, state) => const SignUpScreen()),
      GoRoute(path: '/reset-password', builder: (context, state) => const ResetPasswordScreen()),
      GoRoute(path: '/verify-email', builder: (context, state) => const VerifyEmailScreen()),
      GoRoute(path: '/organization', builder: (context, state) => const OrganizationSetupScreen()),
      GoRoute(path: '/mode', builder: (context, state) => const ModeSelectScreen()),
      GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
      GoRoute(path: '/dashboard/pair', builder: (context, state) => const AddCameraScreen()),
      GoRoute(path: '/dashboard/grid', builder: (context, state) => const MultiCameraScreen()),
      GoRoute(
        path: '/dashboard/cameras/:cameraId',
        builder: (context, state) => CameraDetailScreen(cameraId: state.pathParameters['cameraId']!),
      ),
      GoRoute(
        path: '/dashboard/cameras/:cameraId/live',
        builder: (context, state) => LiveViewScreen(cameraId: state.pathParameters['cameraId']!),
      ),
      GoRoute(
        path: '/dashboard/cameras/:cameraId/zones',
        builder: (context, state) => ZoneEditorScreen(cameraId: state.pathParameters['cameraId']!),
      ),
      GoRoute(path: '/dashboard/incidents', builder: (context, state) => const IncidentListScreen()),
      GoRoute(
        path: '/dashboard/incidents/:incidentId',
        builder: (context, state) => IncidentDetailScreen(incidentId: state.pathParameters['incidentId']!),
      ),
      GoRoute(path: '/camera', builder: (context, state) => const CameraModeScreen()),
      GoRoute(path: '/camera/pair', builder: (context, state) => const ScanPairingScreen()),
      GoRoute(path: '/camera/setup', builder: (context, state) => const CameraSetupScreen()),
      GoRoute(path: '/camera/settings', builder: (context, state) => const CameraSettingsScreen()),
    ],
  );
});

class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(this.ref) {
    ref.listen(sessionControllerProvider, (_, _) => notifyListeners());
  }

  final Ref ref;
}
