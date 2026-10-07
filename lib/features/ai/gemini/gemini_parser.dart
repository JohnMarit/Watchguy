import 'dart:convert';

import '../../../core/errors/app_exception.dart';
import '../../../core/models/enums.dart';
import 'scene_state.dart';

class GeminiParseException extends AppException {
  const GeminiParseException(String message) : super('gemini_parse', message);
}

GeminiSceneUpdate parseGeminiUpdate(String raw) {
  final start = raw.indexOf('{');
  final end = raw.lastIndexOf('}');
  if (start < 0 || end <= start) {
    throw const GeminiParseException('Gemini returned an unstructured response.');
  }
  final decoded = jsonDecode(raw.substring(start, end + 1));
  if (decoded is! Map) {
    throw const GeminiParseException('Gemini returned an unstructured response.');
  }
  final json = Map<String, dynamic>.from(decoded);
  final score = (json['risk_score'] as num?)?.toInt();
  if (score == null || score < 0 || score > 100) {
    throw const GeminiParseException('Gemini risk score is missing.');
  }
  final description = _safeDescription(json['description']?.toString() ?? '');
  final uncertainties = (json['uncertainties'] as List<dynamic>? ?? []).map((e) => '$e').toList();
  if (description != (json['description']?.toString() ?? '')) {
    uncertainties.add('Description omitted a disallowed judgement.');
  }
  return GeminiSceneUpdate(
    sceneState: json['scene_state']?.toString() ?? 'unknown',
    peopleCount: (json['people_count'] as num?)?.toInt() ?? 0,
    activity: json['activity']?.toString() ?? 'unknown',
    description: description,
    riskScore: score,
    riskLevel: enumByName(RiskLevel.values, json['risk_level'], RiskLevel.normal),
    suspicious: json['suspicious'] as bool? ?? false,
    preserveRecording: json['preserve_recording'] as bool? ?? false,
    notifyOwner: json['notify_owner'] as bool? ?? false,
    requestHumanReview: json['request_human_review'] as bool? ?? false,
    observations: (json['observations'] as List<dynamic>? ?? []).map((e) => '$e').toList(),
    uncertainties: uncertainties,
  );
}

String _safeDescription(String description) {
  final lowered = description.toLowerCase();
  for (final word in forbiddenJudgements) {
    if (lowered.contains(word)) return 'Activity needs human review.';
  }
  return description;
}
