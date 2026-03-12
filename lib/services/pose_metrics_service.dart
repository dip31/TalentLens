import 'dart:math';

class PoseMetricsService {
  static final PoseMetricsService _instance = PoseMetricsService._internal();
  factory PoseMetricsService() => _instance;
  PoseMetricsService._internal();

  // Keypoint indices for MoveNet Thunder (17 keypoints)
  static const int nose = 0;
  static const int leftEye = 1;
  static const int rightEye = 2;
  static const int leftEar = 3;
  static const int rightEar = 4;
  static const int leftShoulder = 5;
  static const int rightShoulder = 6;
  static const int leftElbow = 7;
  static const int rightElbow = 8;
  static const int leftWrist = 9;
  static const int rightWrist = 10;
  static const int leftHip = 11;
  static const int rightHip = 12;
  static const int leftKnee = 13;
  static const int rightKnee = 14;
  static const int leftAnkle = 15;
  static const int rightAnkle = 16;

  Map<String, dynamic> analyzeSquatPerformance(List<List<double>> poseSequence) {
    if (poseSequence.isEmpty) {
      return _emptyMetrics();
    }

    final metrics = <String, dynamic>{};
    
    // Extract key metrics
    metrics['reps'] = _countSquatReps(poseSequence);
    metrics['avg_knee_angle'] = _calculateAverageKneeAngle(poseSequence);
    metrics['max_depth'] = _calculateMaxDepth(poseSequence);
    metrics['form_score'] = _calculateFormScore(poseSequence);
    metrics['consistency'] = _calculateConsistency(poseSequence);
    metrics['back_alignment'] = _calculateBackAlignment(poseSequence);
    metrics['knee_tracking'] = _calculateKneeTracking(poseSequence);
    metrics['tempo'] = _calculateTempo(poseSequence);
    
    // Overall score
    metrics['overall_score'] = _calculateOverallScore(metrics);
    
    return metrics;
  }

  int _countSquatReps(List<List<double>> poseSequence) {
    int reps = 0;
    bool inDownPhase = false;
    double previousKneeAngle = 180.0;
    
    for (final pose in poseSequence) {
      if (pose.length < 34) continue; // Need at least 17 keypoints * 2 coordinates
      
      final leftKneeAngle = _calculateKneeAngle(pose, leftHip, leftKnee, leftAnkle);
      final rightKneeAngle = _calculateKneeAngle(pose, rightHip, rightKnee, rightAnkle);
      final avgKneeAngle = (leftKneeAngle + rightKneeAngle) / 2;
      
      // Detect squat phases
      if (!inDownPhase && avgKneeAngle < 110) {
        inDownPhase = true;
      } else if (inDownPhase && avgKneeAngle > 160) {
        reps++;
        inDownPhase = false;
      }
      
      previousKneeAngle = avgKneeAngle;
    }
    
    return reps;
  }

  double _calculateAverageKneeAngle(List<List<double>> poseSequence) {
    double totalAngle = 0.0;
    int validFrames = 0;
    
    for (final pose in poseSequence) {
      if (pose.length < 34) continue;
      
      final leftKneeAngle = _calculateKneeAngle(pose, leftHip, leftKnee, leftAnkle);
      final rightKneeAngle = _calculateKneeAngle(pose, rightHip, rightKnee, rightAnkle);
      
      if (leftKneeAngle > 0 && rightKneeAngle > 0) {
        totalAngle += (leftKneeAngle + rightKneeAngle) / 2;
        validFrames++;
      }
    }
    
    return validFrames > 0 ? totalAngle / validFrames : 0.0;
  }

  double _calculateMaxDepth(List<List<double>> poseSequence) {
    double maxDepth = 0.0;
    
    for (final pose in poseSequence) {
      if (pose.length < 34) continue;
      
      final leftKneeAngle = _calculateKneeAngle(pose, leftHip, leftKnee, leftAnkle);
      final rightKneeAngle = _calculateKneeAngle(pose, rightHip, rightKnee, rightAnkle);
      final avgKneeAngle = (leftKneeAngle + rightKneeAngle) / 2;
      
      // Depth is measured as how much the knee angle decreases from standing (180°)
      final depth = 180.0 - avgKneeAngle;
      maxDepth = max(maxDepth, depth);
    }
    
    return maxDepth;
  }

  double _calculateFormScore(List<List<double>> poseSequence) {
    double totalScore = 0.0;
    int validFrames = 0;
    
    for (final pose in poseSequence) {
      if (pose.length < 34) continue;
      
      double frameScore = 100.0;
      
      // Check knee tracking (knees should not cave inward)
      final kneeTracking = _calculateKneeTrackingForFrame(pose);
      frameScore -= (kneeTracking * 20); // Penalty for poor knee tracking
      
      // Check back alignment
      final backAlignment = _calculateBackAlignmentForFrame(pose);
      frameScore -= (backAlignment * 15); // Penalty for poor back alignment
      
      // Check depth consistency
      final leftKneeAngle = _calculateKneeAngle(pose, leftHip, leftKnee, leftAnkle);
      final rightKneeAngle = _calculateKneeAngle(pose, rightHip, rightKnee, rightAnkle);
      final avgKneeAngle = (leftKneeAngle + rightKneeAngle) / 2;
      
      if (avgKneeAngle < 90) {
        frameScore -= 10; // Penalty for going too deep (potential injury risk)
      }
      
      totalScore += max(0.0, frameScore);
      validFrames++;
    }
    
    return validFrames > 0 ? totalScore / validFrames : 0.0;
  }

  double _calculateConsistency(List<List<double>> poseSequence) {
    if (poseSequence.length < 2) return 0.0;
    
    final List<double> kneeAngles = [];
    
    for (final pose in poseSequence) {
      if (pose.length < 34) continue;
      
      final leftKneeAngle = _calculateKneeAngle(pose, leftHip, leftKnee, leftAnkle);
      final rightKneeAngle = _calculateKneeAngle(pose, rightHip, rightKnee, rightAnkle);
      final avgKneeAngle = (leftKneeAngle + rightKneeAngle) / 2;
      
      if (leftKneeAngle > 0 && rightKneeAngle > 0) {
        kneeAngles.add(avgKneeAngle);
      }
    }
    
    if (kneeAngles.length < 2) return 0.0;
    
    // Calculate coefficient of variation (lower is more consistent)
    final mean = kneeAngles.reduce((a, b) => a + b) / kneeAngles.length;
    final variance = kneeAngles.map((angle) => pow(angle - mean, 2)).reduce((a, b) => a + b) / kneeAngles.length;
    final stdDev = sqrt(variance);
    final coefficientOfVariation = stdDev / mean;
    
    // Convert to percentage (0-100, higher is more consistent)
    return max(0.0, 100.0 - (coefficientOfVariation * 100));
  }

  double _calculateBackAlignment(List<List<double>> poseSequence) {
    double totalDeviation = 0.0;
    int validFrames = 0;
    
    for (final pose in poseSequence) {
      final deviation = _calculateBackAlignmentForFrame(pose);
      totalDeviation += deviation;
      validFrames++;
    }
    
    return validFrames > 0 ? totalDeviation / validFrames : 0.0;
  }

  double _calculateBackAlignmentForFrame(List<double> pose) {
    if (pose.length < 34) return 0.0;
    
    // Calculate angle between shoulder-hip line and vertical
    final leftShoulderPoint = _getPoint(pose, leftShoulder);
    final rightShoulderPoint = _getPoint(pose, rightShoulder);
    final leftHipPoint = _getPoint(pose, leftHip);
    final rightHipPoint = _getPoint(pose, rightHip);
    
    final shoulderCenter = [(leftShoulderPoint[0] + rightShoulderPoint[0]) / 2, (leftShoulderPoint[1] + rightShoulderPoint[1]) / 2];
    final hipCenter = [(leftHipPoint[0] + rightHipPoint[0]) / 2, (leftHipPoint[1] + rightHipPoint[1]) / 2];
    
    // Calculate angle from vertical
    final dx = shoulderCenter[0] - hipCenter[0];
    final dy = shoulderCenter[1] - hipCenter[1];
    final angle = atan2(dx, dy) * 180 / pi;
    
    // Return deviation from perfect alignment (0°)
    return angle.abs();
  }

  double _calculateKneeTracking(List<List<double>> poseSequence) {
    double totalDeviation = 0.0;
    int validFrames = 0;
    
    for (final pose in poseSequence) {
      final deviation = _calculateKneeTrackingForFrame(pose);
      totalDeviation += deviation;
      validFrames++;
    }
    
    return validFrames > 0 ? totalDeviation / validFrames : 0.0;
  }

  double _calculateKneeTrackingForFrame(List<double> pose) {
    if (pose.length < 34) return 0.0;
    
    final leftHipPoint = _getPoint(pose, leftHip);
    final rightHipPoint = _getPoint(pose, rightHip);
    final leftKneePoint = _getPoint(pose, leftKnee);
    final rightKneePoint = _getPoint(pose, rightKnee);
    final leftAnklePoint = _getPoint(pose, leftAnkle);
    final rightAnklePoint = _getPoint(pose, rightAnkle);
    
    // Calculate knee valgus (inward collapse)
    final leftKneeValgus = _calculateKneeValgus(leftHipPoint, leftKneePoint, leftAnklePoint);
    final rightKneeValgus = _calculateKneeValgus(rightHipPoint, rightKneePoint, rightAnklePoint);
    
    return (leftKneeValgus + rightKneeValgus) / 2;
  }

  double _calculateKneeValgus(List<double> hip, List<double> knee, List<double> ankle) {
    // Calculate the angle between hip-knee-ankle line and vertical
    final hipKnee = [knee[0] - hip[0], knee[1] - hip[1]];
    final kneeAnkle = [ankle[0] - knee[0], ankle[1] - knee[1]];
    
    final angle = _calculateAngle(hipKnee, kneeAnkle);
    
    // Return deviation from ideal alignment (knees should track over toes)
    return (angle - 180).abs();
  }

  double _calculateTempo(List<List<double>> poseSequence) {
    if (poseSequence.length < 10) return 0.0;
    
    // Calculate average time between reps (simplified)
    final reps = _countSquatReps(poseSequence);
    if (reps == 0) return 0.0;
    
    // Assuming 30 FPS (adjust based on actual frame rate)
    final totalFrames = poseSequence.length;
    final framesPerRep = totalFrames / reps;
    final secondsPerRep = framesPerRep / 30.0;
    
    return secondsPerRep;
  }

  double _calculateOverallScore(Map<String, dynamic> metrics) {
    final formScore = metrics['form_score'] as double? ?? 0.0;
    final consistency = metrics['consistency'] as double? ?? 0.0;
    final backAlignment = metrics['back_alignment'] as double? ?? 0.0;
    final kneeTracking = metrics['knee_tracking'] as double? ?? 0.0;
    
    // Weighted average
    final overallScore = (formScore * 0.4) + 
                        (consistency * 0.3) + 
                        ((100 - backAlignment) * 0.15) + 
                        ((100 - kneeTracking) * 0.15);
    
    return overallScore.clamp(0.0, 100.0);
  }

  double _calculateKneeAngle(List<double> pose, int hipIdx, int kneeIdx, int ankleIdx) {
    final hip = _getPoint(pose, hipIdx);
    final knee = _getPoint(pose, kneeIdx);
    final ankle = _getPoint(pose, ankleIdx);
    
    return _calculateAngle(
      [hip[0] - knee[0], hip[1] - knee[1]],
      [ankle[0] - knee[0], ankle[1] - knee[1]]
    );
  }

  double _calculateAngle(List<double> v1, List<double> v2) {
    final dot = v1[0] * v2[0] + v1[1] * v2[1];
    final mag1 = sqrt(v1[0] * v1[0] + v1[1] * v1[1]);
    final mag2 = sqrt(v2[0] * v2[0] + v2[1] * v2[1]);
    
    if (mag1 == 0 || mag2 == 0) return 0.0;
    
    final cosAngle = (dot / (mag1 * mag2)).clamp(-1.0, 1.0);
    return acos(cosAngle) * 180 / pi;
  }

  List<double> _getPoint(List<double> pose, int keypointIndex) {
    final x = pose[keypointIndex * 2];
    final y = pose[keypointIndex * 2 + 1];
    return [x, y];
  }

  Map<String, dynamic> _emptyMetrics() {
    return {
      'reps': 0,
      'avg_knee_angle': 0.0,
      'max_depth': 0.0,
      'form_score': 0.0,
      'consistency': 0.0,
      'back_alignment': 0.0,
      'knee_tracking': 0.0,
      'tempo': 0.0,
      'overall_score': 0.0,
    };
  }
}
