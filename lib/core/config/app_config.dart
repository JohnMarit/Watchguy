class AppConfig {
  const AppConfig({
    required this.firebaseApiKey,
    required this.firebaseAppId,
    required this.firebaseMessagingSenderId,
    required this.firebaseProjectId,
    required this.firebaseStorageBucket,
    required this.firebaseIosBundleId,
    required this.apiBaseUrl,
  });

  final String firebaseApiKey;
  final String firebaseAppId;
  final String firebaseMessagingSenderId;
  final String firebaseProjectId;
  final String firebaseStorageBucket;
  final String firebaseIosBundleId;
  final String apiBaseUrl;

  bool get firebaseConfigured =>
      firebaseApiKey.isNotEmpty &&
      firebaseAppId.isNotEmpty &&
      firebaseMessagingSenderId.isNotEmpty &&
      firebaseProjectId.isNotEmpty &&
      firebaseStorageBucket.isNotEmpty;

  bool get apiConfigured => apiBaseUrl.isNotEmpty;

  factory AppConfig.fromEnvironment() {
    return AppConfig(
      firebaseApiKey: const String.fromEnvironment('FIREBASE_API_KEY'),
      firebaseAppId: const String.fromEnvironment('FIREBASE_APP_ID'),
      firebaseMessagingSenderId:
          const String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
      firebaseProjectId: const String.fromEnvironment('FIREBASE_PROJECT_ID'),
      firebaseStorageBucket:
          const String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
      firebaseIosBundleId: const String.fromEnvironment(
        'FIREBASE_IOS_BUNDLE_ID',
        defaultValue: 'com.watchguy.watchguy',
      ),
      apiBaseUrl: const String.fromEnvironment('API_BASE_URL'),
    );
  }
}
