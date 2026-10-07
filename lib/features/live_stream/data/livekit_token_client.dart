import '../../../core/errors/app_exception.dart';
import '../../../core/models/enums.dart';
import '../../../core/network/api_client.dart';
import '../domain/live_session.dart';

class LiveKitTokenClient {
  LiveKitTokenClient(this.api);

  final ApiClient api;

  Future<LiveKitCredentials> issue({
    required String organizationId,
    required String cameraId,
    required LiveRole role,
  }) async {
    if (!api.isConfigured) {
      throw const UnavailableException(
        'Live view needs the server token endpoint. No LiveKit secret is stored in the app.',
      );
    }
    final json = await api.post('/v1/livekit/token', {
      'organizationId': organizationId,
      'cameraId': cameraId,
      'role': role.name,
    });
    return LiveKitCredentials(
      url: json['url'] as String,
      room: json['room'] as String,
      token: json['token'] as String,
      role: role,
    );
  }
}
