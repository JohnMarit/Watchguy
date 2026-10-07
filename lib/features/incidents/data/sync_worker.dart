class OutboxJob {
  OutboxJob({
    required this.id,
    required this.type,
    required this.payload,
    this.attempts = 0,
    this.lastError,
  });

  final String id;
  final String type;
  final Map<String, dynamic> payload;
  int attempts;
  String? lastError;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'payload': payload,
        'attempts': attempts,
        'lastError': lastError,
      };

  factory OutboxJob.fromJson(Map<String, dynamic> json) {
    return OutboxJob(
      id: json['id'] as String,
      type: json['type'] as String,
      payload: Map<String, dynamic>.from(json['payload'] as Map),
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      lastError: json['lastError'] as String?,
    );
  }
}

class SyncWorker {
  const SyncWorker();

  Future<List<OutboxJob>> flush({
    required bool online,
    required List<OutboxJob> jobs,
    required Future<void> Function(OutboxJob job) send,
  }) async {
    if (!online) return jobs;
    final remaining = <OutboxJob>[];
    for (final job in jobs) {
      try {
        await send(job);
      } catch (error) {
        job.attempts += 1;
        job.lastError = error.toString();
        remaining.add(job);
      }
    }
    return remaining;
  }
}

class RetrySchedule {
  const RetrySchedule();

  static const _seconds = [1, 2, 4, 8, 16, 30];

  Duration delayFor(int attempt) {
    final index = attempt < 0
        ? 0
        : attempt >= _seconds.length
            ? _seconds.length - 1
            : attempt;
    return Duration(seconds: _seconds[index]);
  }

  bool exhausted(int attempt) => attempt >= 8;
}

class LoadGovernor {
  const LoadGovernor();

  Duration detectorInterval({
    required Duration baseline,
    required Duration lastInference,
    required bool batteryLow,
  }) {
    var interval = baseline;
    if (lastInference > const Duration(milliseconds: 400)) {
      interval += const Duration(milliseconds: 400);
    }
    if (batteryLow) interval += const Duration(milliseconds: 300);
    if (interval > const Duration(seconds: 2)) return const Duration(seconds: 2);
    return interval;
  }
}
