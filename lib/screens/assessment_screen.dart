import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/face_recognition_provider.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../providers/auth_provider.dart';
import '../models/assessment_model.dart';
import '../services/db_service.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/permissions.dart';
import '../services/pose_metrics_service.dart';
import '../services/movenet_service.dart';
import 'dart:math';

class AssessmentScreen extends StatefulWidget {
  const AssessmentScreen({super.key});

  @override
  State<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends State<AssessmentScreen> {
  AssessmentStatus _currentStatus = AssessmentStatus.pending;
  String? _testType;
  int _scanningCountdown = 5;
  bool _isPersonInFrame = true;
  int _squatReps = 0;
  double _lastKneeAngle = 180;
  bool _isDownPhase = false;
  bool _fromGallery = false;
  Map<String, dynamic>? _detailedMetrics;
  String? _selectedVideoPath;

  @override
  void initState() {
    super.initState();
    // Initialize camera
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FaceRecognitionProvider>().initializeCamera();
    });
  }

  void _startAssessment() {
    setState(() {
      _currentStatus = AssessmentStatus.scanning;
    });
    
    _startCountdown();
  }

  void _startCountdown() {
    const duration = Duration(seconds: 1);
    Timer.periodic(duration, (timer) {
      if (mounted) {
        setState(() {
          _scanningCountdown--;
        });
        
        if (_scanningCountdown <= 0) {
          timer.cancel();
          _performFaceScanning();
        }
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _performFaceScanning() async {
    final auth = context.read<AuthProvider>();
    final faceProvider = context.read<FaceRecognitionProvider>();
    await faceProvider.ensureInitialized();
    // Ensure we have the registered vector loaded from DB for this user
    if (auth.currentUser != null) {
      await faceProvider.loadRegisteredFaceVector(auth.currentUser!.id);
    }
    if (!faceProvider.hasRegisteredVector) {
      if (mounted) {
        setState(() {
          _currentStatus = AssessmentStatus.failed;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No registered face found. Please register your face first.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    // Use system camera app for verification if preferred
    await faceProvider.startFaceScanningViaSystemCamera();
    
    if (mounted) {
      final faceProvider = context.read<FaceRecognitionProvider>();
      
      if (faceProvider.faceMatched) {
        setState(() {
          _currentStatus = AssessmentStatus.verified;
        });
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Face verification successful! Starting assessment...'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate to actual test after a delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            _startActualTest();
          }
        });
      } else {
        setState(() {
          _currentStatus = AssessmentStatus.failed;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Face verification failed. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _startActualTest() {
    // Show instructions and offer capture/upload before analysis
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'How to record your squat video',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '- Keep the camera at hip height, 2-3 meters away\n'
                '- Ensure good lighting and full body visible\n'
                '- Stand sideways so knees and hips are visible\n'
                '- Perform 10 controlled squats',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await _captureSquatVideo();
                      },
                      icon: const Icon(Icons.videocam),
                      label: const Text('Capture Video'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await _pickFromGallery();
                      },
                      icon: const Icon(Icons.video_library),
                      label: const Text('Upload Video'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _runSquatDetectionFor(Duration duration) async {
    // Retained for legacy path; new flow uses video + MoveNet
    await Future.delayed(duration);
    _completeTest();
  }

  Future<void> _captureSquatVideo() async {
    final ok = await PermissionHelper.requestCameraPermission();
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera permission required')),
      );
      return;
    }
    final picker = ImagePicker();
    final shot = await picker.pickVideo(source: ImageSource.camera, maxDuration: const Duration(seconds: 30));
    if (shot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No video captured')),
      );
      return;
    }
    await _analyzeVideo(shot.path);
  }

  Future<void> _analyzeVideo(String videoPath) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Analyzing video with MoveNet...')),
      );
      final service = MoveNetService();
      final series = await service.estimatePosesFromVideo(videoPath, sampleCount: 30);
      
      // Use PoseMetricsService for comprehensive analysis
      final metricsService = PoseMetricsService();
      final metrics = metricsService.analyzeSquatPerformance(series);
      
      _squatReps = metrics['reps'] as int? ?? 0;
      _lastKneeAngle = metrics['avg_knee_angle'] as double? ?? 0.0;
      
      // Store detailed metrics for persistence
      _detailedMetrics = metrics;
      _selectedVideoPath = videoPath;
      
      setState(() {});
      _completeTest();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Analysis failed: $e')),
      );
    }
  }

  int _estimateRepsFromKeypoints(List<List<double>> series) {
    // series[t] = [y0,x0, y1,x1, ... for 17 keypoints]
    // Use hip-knee-ankle to approximate knee angle changes
    int reps = 0;
    bool down = false;
    for (final frame in series) {
      if (frame.length < 34) continue; // need at least some points
      final hip = _getPoint(frame, 11); // left hip
      final knee = _getPoint(frame, 13); // left knee
      final ankle = _getPoint(frame, 15); // left ankle
      final angle = _kneeAngle(hip, knee, ankle);
      if (!down && angle < 110) down = true;
      if (down && angle > 160) { reps++; down = false; }
    }
    return reps;
  }

  List<double> _getPoint(List<double> frame, int idx) {
    final y = frame[idx * 2 + 0];
    final x = frame[idx * 2 + 1];
    return [x, y];
  }

  double _kneeAngle(List<double> hip, List<double> knee, List<double> ankle) {
    final ax = hip[0] - knee[0];
    final ay = hip[1] - knee[1];
    final bx = ankle[0] - knee[0];
    final by = ankle[1] - knee[1];
    final dot = ax * bx + ay * by;
    final na = sqrt((ax * ax + ay * ay).abs());
    final nb = sqrt((bx * bx + by * by).abs());
    if (na == 0 || nb == 0) return 180;
    final cosT = (dot / (na * nb)).clamp(-1.0, 1.0);
    return (acos(cosT) * 180 / pi);
  }

  void _updateRepLogic(double kneeAngle) {
    // Down phase when knee angle < 110; Up phase when > 160
    if (!_isDownPhase && kneeAngle < 110) {
      _isDownPhase = true;
    }
    if (_isDownPhase && kneeAngle > 160) {
      _squatReps += 1;
      _isDownPhase = false;
    }
    // If user leaves frame (placeholder condition), end test immediately
    if (!_isPersonInFrame && _currentStatus == AssessmentStatus.verified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User left camera frame'), backgroundColor: Colors.red),
      );
      _completeTest();
    }
  }

  void _completeTest() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Test completed successfully!'),
        backgroundColor: Colors.green,
      ),
    );
    // Persist detailed metrics and video path
    final user = context.read<AuthProvider>().currentUser;
    if (user != null) {
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final metrics = _detailedMetrics ?? {
        'reps': _squatReps,
        'avg_knee_angle': _lastKneeAngle,
        'form_score': 0.0,
        'consistency': 0.0,
        'overall_score': 0.0,
      };
      
      DbService().insertAssessment(
        id: id,
        userId: user.id,
        testName: 'squats',
        metrics: metrics,
        validityFlag: _isPersonInFrame,
        cheatIndicators: 'none',
        trialNumber: 1,
        videoPath: _selectedVideoPath,
        synced: false,
      );
    }
    // Navigate back to home
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        context.go('/home');
      }
    });
  }

  void _retryScanning() {
    setState(() {
      _currentStatus = AssessmentStatus.pending;
      _scanningCountdown = 5;
    });
    context.read<FaceRecognitionProvider>().resetScanning();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().currentUser;
    
    return WillPopScope(
      onWillPop: () async {
        context.go('/home');
        return false;
      },
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Assessment'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: Consumer<FaceRecognitionProvider>(
        builder: (context, faceProvider, _) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Status Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Icon(
                          _getStatusIcon(),
                          size: 48,
                          color: _getStatusColor(),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _getStatusText(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(),
                          ),
                        ),
                        if (_currentStatus == AssessmentStatus.scanning)
                          Text(
                            'Scanning in $_scanningCountdown seconds...',
                            style: const TextStyle(color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Camera Preview Area
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text(
                            'Camera Preview',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Stack(
                                  children: [
                                    if (faceProvider.cameraController != null && faceProvider.cameraController!.value.isInitialized)
                                      CameraPreview(faceProvider.cameraController!)
                                    else
                                      Container(
                                        color: Colors.grey[300],
                                        child: const Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.camera_alt,
                                                size: 64,
                                                color: Colors.grey,
                                              ),
                                              Text('Camera Preview'),
                                            ],
                                          ),
                                        ),
                                      ),
                                    
                                    // Face detection overlay
                                    if (faceProvider.faceDetected)
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.green,
                                              width: 3,
                                            ),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Center(
                                            child: Icon(
                                              Icons.face,
                                              color: Colors.green,
                                              size: 48,
                                            ),
                                          ),
                                        ),
                                      ),
                                    
                                    // Person tracking overlay
                                    if (!_isPersonInFrame)
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.red.withOpacity(0.3),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Center(
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.person_off,
                                                  color: Colors.red,
                                                  size: 48,
                                                ),
                                                Text(
                                                  'Please stay in frame',
                                                  style: TextStyle(
                                                    color: Colors.red,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    await _flipCamera(context);
                                  },
                                  icon: const Icon(Icons.cameraswitch),
                                  label: const Text('Flip Camera'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    await _pickFromGallery();
                                  },
                                  icon: const Icon(Icons.video_library),
                                  label: const Text('Upload Video'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Action Buttons
                Row(
                  children: [
                    if (_currentStatus == AssessmentStatus.pending)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _startAssessment,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Start Assessment'),
                        ),
                      ),
                    
                    if (_currentStatus == AssessmentStatus.failed)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _retryScanning,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Try Again'),
                        ),
                      ),
                    
                    if (_currentStatus == AssessmentStatus.verified)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => context.go('/home'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Back to Home'),
                        ),
                      ),
                  ],
                ),

                // Instructions
                if (_currentStatus == AssessmentStatus.pending)
                  const Padding(
                    padding: EdgeInsets.only(top: 16.0),
                    child: Text(
                      'Make sure you are in a well-lit area and your face is clearly visible',
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    ));
  }

  IconData _getStatusIcon() {
    switch (_currentStatus) {
      case AssessmentStatus.pending:
        return Icons.play_circle_outline;
      case AssessmentStatus.scanning:
        return Icons.face_retouching_natural;
      case AssessmentStatus.verified:
        return Icons.check_circle;
      case AssessmentStatus.failed:
        return Icons.error;
      case AssessmentStatus.retry:
        return Icons.refresh;
    }
  }

  Color _getStatusColor() {
    switch (_currentStatus) {
      case AssessmentStatus.pending:
        return Colors.blue;
      case AssessmentStatus.scanning:
        return Colors.orange;
      case AssessmentStatus.verified:
        return Colors.green;
      case AssessmentStatus.failed:
        return Colors.red;
      case AssessmentStatus.retry:
        return Colors.orange;
    }
  }

  String _getStatusText() {
    switch (_currentStatus) {
      case AssessmentStatus.pending:
        return 'Ready to Start';
      case AssessmentStatus.scanning:
        return 'Scanning Face';
      case AssessmentStatus.verified:
        return 'Face Verified';
      case AssessmentStatus.failed:
        return 'Verification Failed';
      case AssessmentStatus.retry:
        return 'Retry Required';
    }
  }

  Future<void> _flipCamera(BuildContext context) async {
    await context.read<FaceRecognitionProvider>().switchCamera();
  }

  Future<void> _pickFromGallery() async {
    final hasPerm = await PermissionHelper.requestGalleryPermission();
    if (!hasPerm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gallery permission required')),
      );
      return;
    }
    final picker = ImagePicker();
    final file = await picker.pickVideo(source: ImageSource.gallery);
    if (file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No video selected')),
      );
      return;
    }
    try {
      // Basic integrity check (> 100KB)
      final bytes = await file.readAsBytes();
      if (bytes.length < 100 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video too small, possibly invalid')),
        );
        return;
      }
      _fromGallery = true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video selected successfully')), 
      );
      // TODO: process or store the selected video path if needed
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to read video: $e')),
      );
    }
  }
}
