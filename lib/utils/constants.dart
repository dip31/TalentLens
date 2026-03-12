class AppConstants {
  // Assessment Types
  static const String verticalJumpTest = 'vertical_jump';
  static const String situpsTest = 'situps';
  static const String shuttleRunTest = 'shuttle_run';
  static const String enduranceRunTest = 'endurance_run';

  // Face Recognition
  static const int faceScanningDuration = 5; // seconds
  static const double faceMatchThreshold = 0.8;

  // Camera Settings
  static const int cameraResolutionWidth = 640;
  static const int cameraResolutionHeight = 480;

  // Assessment Durations (in seconds)
  static const int verticalJumpDuration = 30;
  static const int situpsDuration = 60;
  static const int shuttleRunDuration = 120;
  static const int enduranceRunDuration = 300;

  // Gamification
  static const int pointsPerTest = 100;
  static const int bonusPointsForPerfectScore = 50;
  static const int maxRetries = 3;

  // UI Constants
  static const double defaultPadding = 16.0;
  static const double cardElevation = 2.0;
  static const double borderRadius = 8.0;
}
