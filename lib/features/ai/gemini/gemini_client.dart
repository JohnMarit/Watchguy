import 'dart:convert';
import 'dart:typed_data';

import '../../../core/network/api_client.dart';
import 'gemini_parser.dart';
import 'scene_state.dart';

class GeminiSceneClient {
  GeminiSceneClient(this.api);

  final ApiClient api;

  Future<GeminiSceneUpdate?> interpret({
    required String organizationId,
    required String cameraId,
    required Uint8List jpeg,
    required SceneState state,
    required Map<String, dynamic> context,
  }) async {
    if (!api.isConfigured) return null;
    final json = await api.post('/v1/ai/frames', {
      'organizationId': organizationId,
      'cameraId': cameraId,
      'jpegBase64': base64Encode(jpeg),
      'sceneState': state.toJson(),
      'context': context,
    });
    return parseGeminiUpdate(jsonEncode(json));
  }
}
