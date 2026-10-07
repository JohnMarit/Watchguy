import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../app/providers.dart';
import '../../../core/models/enums.dart';
import '../../../core/security/secret_hash.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common.dart';
import '../domain/pairing_service.dart';
import '../domain/pairing_token.dart';

class PendingPairing extends Notifier<PairingPayload?> {
  @override
  PairingPayload? build() => null;

  void setPayload(PairingPayload? payload) => state = payload;
}

final pendingPairingProvider = NotifierProvider<PendingPairing, PairingPayload?>(PendingPairing.new);

class AddCameraScreen extends ConsumerStatefulWidget {
  const AddCameraScreen({super.key});

  @override
  ConsumerState<AddCameraScreen> createState() => _AddCameraScreenState();
}

class _AddCameraScreenState extends ConsumerState<AddCameraScreen> {
  PairingPayload? payload;
  String? error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_create);
  }

  Future<void> _create() async {
    final session = ref.read(sessionControllerProvider);
    final org = session.organization;
    final user = session.user;
    if (org == null || user == null) return;
    final api = ref.read(apiClientProvider);
    try {
      if (api.isConfigured) {
        final json = await api.post('/v1/pairing-tokens', {'organizationId': org.id});
        setState(() {
          payload = PairingPayload(
            organizationId: org.id,
            tokenId: json['tokenId'] as String,
            secret: json['secret'] as String,
            expiresAt: DateTime.parse(json['expiresAt'] as String),
          );
        });
        return;
      }
      final service = PairingService(clock: ref.read(clockProvider));
      final invitation = service.issue(
        tokenId: const Uuid().v4(),
        organizationId: org.id,
        createdBy: user.id,
      );
      await ref.read(orgDatabaseProvider).savePairingToken(invitation.token);
      setState(() => payload = invitation.payload);
    } catch (error) {
      setState(() => this.error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = payload;
    return Scaffold(
      appBar: AppBar(title: const Text('Add camera')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Scan this code on the camera phone.', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
              'The code expires in 10 minutes and works once. It does not contain your password.',
              style: TextStyle(color: AppColors.muted, height: 1.4),
            ),
            const SizedBox(height: 24),
            if (error != null) Text(error!, style: const TextStyle(color: AppColors.critical)),
            if (code != null)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: QrImageView(data: code.encode(), size: 220, backgroundColor: Colors.white),
                ),
              )
            else if (error == null)
              const Center(child: CircularProgressIndicator()),
            const Spacer(),
            const Text('On the other phone, choose Use as camera and scan this code.', style: TextStyle(color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}

class ScanPairingScreen extends ConsumerStatefulWidget {
  const ScanPairingScreen({super.key});

  @override
  ConsumerState<ScanPairingScreen> createState() => _ScanPairingScreenState();
}

class _ScanPairingScreenState extends ConsumerState<ScanPairingScreen> {
  final controller = MobileScannerController();

  /// The scanner keeps reporting the same code. Without this the setup page
  /// would be pushed again every frame and Back would appear to do nothing.
  var handled = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (handled) return;
    final raw = capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
    if (raw == null) return;
    try {
      final payload = PairingPayload.decode(raw);
      handled = true;
      await controller.stop();
      ref.read(pendingPairingProvider.notifier).setPayload(payload);
      if (!mounted) return;
      await context.push('/camera/setup');
      if (!mounted) return;
      handled = false;
      await controller.start();
    } catch (error) {
      if (mounted) showAppMessage(context, error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan pairing code')),
      body: Column(
        children: [
          Expanded(child: MobileScanner(controller: controller, onDetect: _onDetect)),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SecondaryButton(
              label: 'Cancel',
              onPressed: () => context.canPop() ? context.pop() : context.go('/camera'),
            ),
          ),
        ],
      ),
    );
  }
}

class CameraSetupScreen extends ConsumerStatefulWidget {
  const CameraSetupScreen({super.key});

  @override
  ConsumerState<CameraSetupScreen> createState() => _CameraSetupScreenState();
}

/// Ready-made camera names and the spot each one usually watches, so pairing
/// never stalls on an empty form.
const cameraSamples = <(String, String)>[
  ('Main Gate', 'North entrance'),
  ('Reception', 'Front desk'),
  ('Warehouse', 'Loading dock'),
  ('Parking', 'West lot'),
  ('Back Door', 'Service corridor'),
  ('Shop Counter', 'Till area'),
];

class _CameraSetupScreenState extends ConsumerState<CameraSetupScreen> {
  final name = TextEditingController(text: cameraSamples.first.$1);
  final location = TextEditingController(text: cameraSamples.first.$2);
  var busy = false;

  @override
  void dispose() {
    name.dispose();
    location.dispose();
    super.dispose();
  }

  void _apply((String, String) sample) {
    name.text = sample.$1;
    location.text = sample.$2;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Name this camera')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'These sample values are ready to use. Tap another spot or edit them.',
            style: TextStyle(color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: cameraSamples
                .map((sample) => ActionChip(
                      label: Text(sample.$1),
                      onPressed: () => _apply(sample),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Camera name')),
          const SizedBox(height: 12),
          TextField(controller: location, decoration: const InputDecoration(labelText: 'Location')),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Start camera mode',
            busy: busy,
            onPressed: () async {
              final payload = ref.read(pendingPairingProvider);
              final session = ref.read(sessionControllerProvider);
              if (payload == null || session.user == null) return;
              setState(() => busy = true);
              try {
                final cameraId = await _claim(payload, session.user!.id, session.settings.deviceId);
                await ref.read(sessionControllerProvider.notifier).setActiveCamera(cameraId);
                await ref.read(sessionControllerProvider.notifier).chooseMode(AppMode.camera);
              } on PairingRejection catch (error) {
                if (context.mounted) showAppMessage(context, error.message);
              } catch (error) {
                if (context.mounted) showAppMessage(context, error.toString());
              } finally {
                if (mounted) setState(() => busy = false);
              }
            },
          ),
          const SizedBox(height: 10),
          SecondaryButton(
            label: 'Back',
            onPressed: busy
                ? null
                : () => context.canPop() ? context.pop() : context.go('/camera'),
          ),
        ],
      ),
    );
  }

  Future<String> _claim(PairingPayload payload, String userId, String deviceId) async {
    final cameraName = name.text.trim().isEmpty ? cameraSamples.first.$1 : name.text.trim();
    final cameraLocation =
        location.text.trim().isEmpty ? cameraSamples.first.$2 : location.text.trim();
    final api = ref.read(apiClientProvider);
    if (api.isConfigured) {
      final json = await api.post('/v1/pairing-tokens/claim', {
        'organizationId': payload.organizationId,
        'tokenId': payload.tokenId,
        'secret': payload.secret,
        'deviceId': deviceId,
        'name': cameraName,
        'location': cameraLocation,
      });
      return json['cameraId'] as String;
    }
    final database = ref.read(orgDatabaseProvider);
    final clock = ref.read(clockProvider);
    final service = PairingService(clock: clock);
    final stored = await database.getPairingToken(payload.organizationId, payload.tokenId);
    final camera = service.redeem(
      token: stored,
      payload: payload,
      cameraId: const Uuid().v4(),
      operatorUserId: userId,
      deviceId: deviceId,
      name: cameraName,
      location: cameraLocation,
    );
    await database.savePairingToken(StoredPairingToken(
      id: payload.tokenId,
      organizationId: payload.organizationId,
      secretHash: stored?.secretHash ?? hashSecret(payload.secret),
      createdBy: stored?.createdBy ?? '',
      expiresAt: stored?.expiresAt ?? payload.expiresAt,
      consumedAt: clock.now(),
      consumedByDeviceId: deviceId,
    ));
    await database.saveCamera(camera);
    return camera.id;
  }
}
