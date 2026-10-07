import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/app_config.dart';
import '../../core/models/enums.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/document_store.dart';
import '../../core/storage/org_database.dart';
import '../../core/time/clock.dart';
import '../../features/ai/gemini/gemini_client.dart';
import '../../features/ai/local/activity_sampler.dart';
import '../../features/auth/data/demo_accounts.dart';
import '../../features/auth/domain/app_user.dart';
import '../../features/auth/domain/auth_gate.dart';
import '../../features/auth/domain/auth_repository.dart';
import '../../features/organization/domain/organization.dart';
import '../../features/settings/domain/app_settings.dart';

final clockProvider = Provider<Clock>((ref) => const SystemClock());

final appConfigProvider = Provider<AppConfig>((ref) {
  throw UnimplementedError('AppConfig is provided at startup.');
});

final documentStoreProvider = Provider<DocumentStore>((ref) {
  throw UnimplementedError('DocumentStore is provided at startup.');
});

final orgDatabaseProvider = Provider<OrgDatabase>((ref) {
  throw UnimplementedError('OrgDatabase is provided at startup.');
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  throw UnimplementedError('AuthRepository is provided at startup.');
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(config: ref.watch(appConfigProvider));
});

final geminiClientProvider = Provider<GeminiSceneClient>((ref) {
  return GeminiSceneClient(ref.watch(apiClientProvider));
});

final samplingPolicyProvider = Provider<AiSamplingPolicy>((ref) => const AiSamplingPolicy());

class Session {
  const Session({
    required this.ready,
    this.user,
    this.organization,
    this.settings = const AppSettings(),
  });

  final bool ready;
  final AppUser? user;
  final Organization? organization;
  final AppSettings settings;

  AppGate get gate => resolveGate(
        loading: !ready,
        user: user,
        hasOrganization: organization != null,
        mode: settings.mode,
      );

  Session copyWith({
    bool? ready,
    AppUser? user,
    Organization? organization,
    AppSettings? settings,
    bool clearUser = false,
    bool clearOrganization = false,
  }) {
    return Session(
      ready: ready ?? this.ready,
      user: clearUser ? null : user ?? this.user,
      organization: clearOrganization ? null : organization ?? this.organization,
      settings: settings ?? this.settings,
    );
  }
}

class SessionController extends Notifier<Session> {
  @override
  Session build() {
    final auth = ref.watch(authRepositoryProvider);
    final subscription = auth.watchUser().listen(_onUser);
    ref.onDispose(subscription.cancel);
    return const Session(ready: false);
  }

  Future<void> _onUser(AppUser? user) async {
    var settings = await _loadSettings();
    final demo = user == null ? null : demoAccountFor(user);
    if (demo != null) {
      settings = settings.copyWith(
        mode: demo.mode,
        organizationId: demoOrganizationId,
        activeCameraId: demo.activeCameraId,
        clearCamera: demo.activeCameraId == null,
      );
      await _saveSettings(settings);
    }
    if (user == null) {
      state = Session(ready: true, settings: settings);
      return;
    }
    final organization = await ref.read(orgDatabaseProvider).organizationForUser(user.id);
    state = Session(
      ready: true,
      user: user,
      organization: organization,
      settings: settings.copyWith(organizationId: organization?.id),
    );
  }

  Future<void> signIn(String email, String password) {
    return ref.read(authRepositoryProvider).signInWithEmail(email: email, password: password);
  }

  Future<void> signUp(String name, String email, String password) {
    return ref.read(authRepositoryProvider).signUpWithEmail(
          email: email,
          password: password,
          displayName: name,
        );
  }

  Future<void> signInWithGoogle() => ref.read(authRepositoryProvider).signInWithGoogle();

  Future<void> signInWithApple() => ref.read(authRepositoryProvider).signInWithApple();

  Future<void> resetPassword(String email) {
    return ref.read(authRepositoryProvider).sendPasswordReset(email);
  }

  Future<void> confirmVerification() {
    return ref.read(authRepositoryProvider).confirmVerification();
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
  }

  Future<void> createOrganization(String name) async {
    final user = state.user;
    if (user == null) return;
    final now = ref.read(clockProvider).now();
    final organization = Organization(
      id: const Uuid().v4(),
      name: name.trim(),
      ownerId: user.id,
      createdAt: now,
    );
    final database = ref.read(orgDatabaseProvider);
    await database.saveOrganization(organization);
    await database.saveMember(OrganizationMember(
      userId: user.id,
      organizationId: organization.id,
      role: MemberRole.owner,
      createdAt: now,
      email: user.email,
    ));
    state = state.copyWith(organization: organization);
  }

  Future<void> chooseMode(AppMode mode) async {
    final next = state.settings.copyWith(mode: mode);
    await _saveSettings(next);
    state = state.copyWith(settings: next);
  }

  Future<void> updateSettings(AppSettings settings) async {
    await _saveSettings(settings);
    state = state.copyWith(settings: settings);
  }

  Future<void> setActiveCamera(String cameraId) {
    return updateSettings(state.settings.copyWith(activeCameraId: cameraId));
  }

  Future<AppSettings> _loadSettings() async {
    final json = await ref.read(documentStoreProvider).read('settings/app');
    final settings = AppSettings.fromJson(json);
    if (settings.deviceId.isNotEmpty) return settings;
    final created = settings.copyWith(deviceId: const Uuid().v4());
    await _saveSettings(created);
    return created;
  }

  Future<void> _saveSettings(AppSettings settings) {
    return ref.read(documentStoreProvider).write('settings/app', settings.toJson());
  }
}

final sessionControllerProvider = NotifierProvider<SessionController, Session>(SessionController.new);
