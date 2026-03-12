enum AssessmentStatus {
  pending,
  scanning,
  verified,
  failed,
  retry
}

class AssessmentModel {
  final String id;
  final String userId;
  final AssessmentStatus status;
  final DateTime startTime;
  final DateTime? endTime;
  final String? videoPath;
  final Map<String, dynamic>? metrics;
  final bool isCheatDetected;
  final String? errorMessage;

  AssessmentModel({
    required this.id,
    required this.userId,
    required this.status,
    required this.startTime,
    this.endTime,
    this.videoPath,
    this.metrics,
    this.isCheatDetected = false,
    this.errorMessage,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'status': status.name,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'videoPath': videoPath,
      'metrics': metrics,
      'isCheatDetected': isCheatDetected,
      'errorMessage': errorMessage,
    };
  }

  factory AssessmentModel.fromJson(Map<String, dynamic> json) {
    return AssessmentModel(
      id: json['id'],
      userId: json['userId'],
      status: AssessmentStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => AssessmentStatus.pending,
      ),
      startTime: DateTime.parse(json['startTime']),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      videoPath: json['videoPath'],
      metrics: json['metrics'],
      isCheatDetected: json['isCheatDetected'] ?? false,
      errorMessage: json['errorMessage'],
    );
  }
}
