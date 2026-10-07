class AiSamplingPolicy {
  const AiSamplingPolicy({
    this.quiet = const Duration(seconds: 2),
    this.person = const Duration(seconds: 1),
    this.motion = const Duration(milliseconds: 500),
    this.incident = const Duration(milliseconds: 250),
  });

  final Duration quiet;
  final Duration person;
  final Duration motion;
  final Duration incident;

  Duration intervalFor({
    required int peopleCount,
    required double motionScore,
    required bool potentialIncident,
  }) {
    if (potentialIncident) return incident;
    if (motionScore >= 0.08) return motion;
    if (peopleCount > 0) return person;
    return quiet;
  }

  static AiSamplingPolicy fromRemote(Map<String, String> values) {
    const defaults = AiSamplingPolicy();
    return AiSamplingPolicy(
      quiet: _duration(values['ai_sample_quiet_ms'], defaults.quiet),
      person: _duration(values['ai_sample_person_ms'], defaults.person),
      motion: _duration(values['ai_sample_motion_ms'], defaults.motion),
      incident: _duration(values['ai_sample_incident_ms'], defaults.incident),
    );
  }

  static Duration _duration(String? raw, Duration fallback) {
    final parsed = int.tryParse(raw ?? '');
    if (parsed == null || parsed < 100) return fallback;
    return Duration(milliseconds: parsed);
  }
}

class ActivitySampler {
  ActivitySampler(this.policy);

  final AiSamplingPolicy policy;
  DateTime? _last;

  bool shouldSample({
    required DateTime now,
    required int peopleCount,
    required double motionScore,
    required bool potentialIncident,
  }) {
    final interval = policy.intervalFor(
      peopleCount: peopleCount,
      motionScore: motionScore,
      potentialIncident: potentialIncident,
    );
    final last = _last;
    if (last != null && now.difference(last) < interval) return false;
    _last = now;
    return true;
  }
}
