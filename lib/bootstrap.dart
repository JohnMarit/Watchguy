import 'dart:async';
import 'dart:io';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod/misc.dart';
import 'package:path_provider/path_provider.dart';

import 'app/providers.dart';
import 'core/config/app_config.dart';
import 'core/logging/app_logger.dart';
import 'core/storage/file_document_store.dart';
import 'core/storage/firestore_org_database.dart';
import 'core/storage/org_database.dart';
import 'features/auth/data/demo_accounts.dart';
import 'features/auth/data/firebase_auth_repository.dart';
import 'features/auth/data/local_auth_repository.dart';
import 'features/live_stream/data/local_live_relay.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppBootstrap {
  static Future<List<Override>> start(AppConfig config) async {
    final support = await getApplicationSupportDirectory();
    final store = FileDocumentStore(Directory('${support.path}/watchguy'));
    final logger = const AppLogger('bootstrap');
    unawaited(LocalLiveDirectory.instance.start());
    OrgDatabase database = LocalOrgDatabase(store);
    final localAuth = LocalAuthRepository(store);
    if (!config.firebaseConfigured) {
      logger.info('Firebase dart-defines are empty. Using the on-device store.');
      await seedDemoAccounts(store: store, database: database, now: DateTime.now().toUtc());
      return [
        appConfigProvider.overrideWithValue(config),
        documentStoreProvider.overrideWithValue(store),
        orgDatabaseProvider.overrideWithValue(database),
        authRepositoryProvider.overrideWithValue(localAuth),
      ];
    }
    await Firebase.initializeApp(options: _options(config));
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode ? const AndroidDebugProvider() : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode ? const AppleDebugProvider() : const AppleAppAttestProvider(),
    );
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    database = FirestoreOrgDatabase(FirebaseFirestore.instance);
    FirebaseMessaging.onBackgroundMessage(_backgroundMessage);
    try {
      await FirebaseMessaging.instance.requestPermission();
    } catch (error) {
      logger.error('notification permission', error: error);
    }
    return [
      appConfigProvider.overrideWithValue(config),
      documentStoreProvider.overrideWithValue(store),
      orgDatabaseProvider.overrideWithValue(database),
      authRepositoryProvider.overrideWithValue(
        FirebaseAuthRepository(FirebaseAuth.instance, database),
      ),
    ];
  }

  static FirebaseOptions _options(AppConfig config) {
    return FirebaseOptions(
      apiKey: config.firebaseApiKey,
      appId: config.firebaseAppId,
      messagingSenderId: config.firebaseMessagingSenderId,
      projectId: config.firebaseProjectId,
      storageBucket: config.firebaseStorageBucket,
      iosBundleId: config.firebaseIosBundleId,
    );
  }
}

@pragma('vm:entry-point')
Future<void> _backgroundMessage(RemoteMessage message) async {
  const AppLogger('push').info('Background alert ${message.messageId}');
}
