import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../services/db_service.dart';
import '../services/facemesh_service.dart';
import 'package:image_picker/image_picker.dart';

class FaceRecognitionProvider extends ChangeNotifier {
  CameraController? _cameraController;
  bool _isInitialized = false;
  bool _isScanning = false;
  bool _faceDetected = false;
  bool _faceMatched = false;
  String? _error;
  List<CameraDescription> _cameras = [];
  List<double>? _registeredFaceVector;
  List<double>? _registeredFaceEmbedding; // FaceMesh embedding
  int _cameraIndex = 0;

  CameraController? get cameraController => _cameraController;
  bool get isInitialized => _isInitialized;
  bool get isScanning => _isScanning;
  bool get faceDetected => _faceDetected;
  bool get faceMatched => _faceMatched;
  String? get error => _error;
  List<double>? get registeredFaceVector => _registeredFaceVector;
  List<double>? get registeredFaceEmbedding => _registeredFaceEmbedding;
  bool get hasRegisteredVector => _registeredFaceVector != null && _registeredFaceVector!.isNotEmpty;
  bool get hasRegisteredEmbedding => _registeredFaceEmbedding != null && _registeredFaceEmbedding!.isNotEmpty;
  String? _lastCapturedImagePath;
  String? get lastCapturedImagePath => _lastCapturedImagePath;

  Future<void> initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _error = 'No cameras available';
        notifyListeners();
        return;
      }

      // Prefer front camera by default if available
      if (_cameraIndex == 0 && _cameras.any((c) => c.lensDirection == CameraLensDirection.front)) {
        _cameraIndex = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.front);
        if (_cameraIndex < 0) {
          _cameraIndex = 0;
        }
      }

      _cameraController?.dispose();
      _cameraController = CameraController(
        _cameras[_cameraIndex % _cameras.length],
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to initialize camera: $e';
      notifyListeners();
    }
  }

  Future<void> switchCamera() async {
    if (_cameras.isEmpty) {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;
    }
    try {
      final current = _cameras[_cameraIndex % _cameras.length];
      final alternativeIndex = _cameras.indexWhere(
        (c) => c.lensDirection != current.lensDirection,
      );
      if (alternativeIndex != -1) {
        _cameraIndex = alternativeIndex;
      } else {
        _cameraIndex = (_cameraIndex + 1) % _cameras.length;
      }
      await initializeCamera();
    } catch (e) {
      _error = 'Failed to switch camera: $e';
      notifyListeners();
    }
  }

  Future<void> startFaceScanning() async {
    if (!_isInitialized || _cameraController == null || !(_cameraController!.value.isInitialized)) {
      _error = 'Camera not initialized';
      notifyListeners();
      return;
    }
    if (_isScanning) {
      return; // avoid concurrent scans
    }

    _isScanning = true;
    _faceDetected = false;
    _faceMatched = false;
    _error = null;
    notifyListeners();

    try {
      final options = FaceDetectorOptions(
        enableContours: true,
        enableClassification: true,
        performanceMode: FaceDetectorMode.accurate,
      );
      final detector = FaceDetector(options: options);

      const int maxAttempts = 3;
      const double matchThreshold = 0.82; // tighten threshold a bit
      double bestSimilarity = -1.0;
      bool anyFaceDetected = false;

      for (int attempt = 0; attempt < maxAttempts; attempt++) {
        final imageFile = await _cameraController!.takePicture();
        final input = InputImage.fromFilePath(imageFile.path);
        final faces = await detector.processImage(input);
        if (faces.isNotEmpty) {
          anyFaceDetected = true;
          // Choose the largest face by bounding box area to reduce false picks
          faces.sort((a, b) {
            final aa = a.boundingBox.width * a.boundingBox.height;
            final bb = b.boundingBox.width * b.boundingBox.height;
            return bb.compareTo(aa);
          });
          final candidate = faces.first;
          // Basic head orientation sanity check to avoid side profiles
          final headEulerY = candidate.headEulerAngleY ?? 0.0; // left-right
          final headEulerZ = candidate.headEulerAngleZ ?? 0.0; // tilt
          if (headEulerY.abs() > 20 || headEulerZ.abs() > 20) {
            // skip angles too far from frontal to reduce false matches
            continue;
          }
          final vector = _computeFaceVector(candidate);
          if (_registeredFaceVector != null && vector.isNotEmpty) {
            final sim = _cosineSimilarity(_registeredFaceVector!, vector);
            if (sim > bestSimilarity) {
              bestSimilarity = sim;
            }
            if (sim >= matchThreshold) {
              _faceDetected = true;
              _faceMatched = true;
              break;
            }
          }
        }
        // small delay between attempts
        await Future.delayed(const Duration(milliseconds: 250));
      }

      _faceDetected = anyFaceDetected;
      if (!_faceMatched && _registeredFaceVector != null) {
        // Not matched after attempts; keep the best similarity for debugging
        if (bestSimilarity >= 0) {
          _error = 'Face not matched (similarity=${bestSimilarity.toStringAsFixed(2)})';
        } else if (!anyFaceDetected) {
          _error = 'No face detected. Improve lighting and center your face.';
        }
      }

      await detector.close();
    } catch (e) {
      _error = 'Face scanning failed: $e';
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<void> captureFaceImage() async {
    if (!_isInitialized || _cameraController == null) {
      _error = 'Camera not initialized';
      notifyListeners();
      return;
    }

    try {
      final image = await _cameraController!.takePicture();
      // Persist face image
      final dir = await getApplicationDocumentsDirectory();
      final facePath = '${dir.path}/face_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(image.path).copy(facePath);
      // Extract face vector to register
      final input = InputImage.fromFilePath(facePath);
      final options = FaceDetectorOptions(enableContours: true, performanceMode: FaceDetectorMode.accurate);
      final detector = FaceDetector(options: options);
      final faces = await detector.processImage(input);
      if (faces.isNotEmpty) {
        _registeredFaceVector = _computeFaceVector(faces.first);
      }
      await detector.close();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to capture image: $e';
      notifyListeners();
    }
  }

  // Capture a single image using the system camera app (default camera)
  // and register the face vector from that image.
  Future<void> captureFaceViaSystemCamera() async {
    try {
      final picker = ImagePicker();
      final shot = await picker.pickImage(source: ImageSource.camera, preferredCameraDevice: CameraDevice.front);
      if (shot == null) {
        _error = 'No image captured';
        notifyListeners();
        return;
      }
      // Persist captured image into app documents for later reference
      final dir = await getApplicationDocumentsDirectory();
      final facePath = '${dir.path}/face_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(shot.path).copy(facePath);
      _lastCapturedImagePath = facePath;

      // Extract FaceMesh embedding for better accuracy
      final faceMeshService = FaceMeshService();
      final imageBytes = await File(facePath).readAsBytes();
      _registeredFaceEmbedding = await faceMeshService.extractFaceEmbedding(imageBytes);
      
      // Also keep the old method for backward compatibility
      final input = InputImage.fromFilePath(facePath);
      final options = FaceDetectorOptions(enableContours: true, performanceMode: FaceDetectorMode.accurate);
      final detector = FaceDetector(options: options);
      final faces = await detector.processImage(input);
      if (faces.isNotEmpty) {
        _registeredFaceVector = _computeFaceVector(faces.first);
        _error = null;
      } else {
        _error = 'No face detected in captured image';
      }
      await detector.close();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to capture via system camera: $e';
      notifyListeners();
    }
  }

  // Use system camera to take a verification shot and compare to registered vector
  Future<void> startFaceScanningViaSystemCamera() async {
    if (_isScanning) return;
    _isScanning = true;
    _faceDetected = false;
    _faceMatched = false;
    _error = null;
    notifyListeners();

    try {
      final picker = ImagePicker();
      final shot = await picker.pickImage(source: ImageSource.camera, preferredCameraDevice: CameraDevice.front);
      if (shot == null) {
        _error = 'No image captured';
        return;
      }
      
      // Use FaceMesh for verification if available
      if (_registeredFaceEmbedding != null && _registeredFaceEmbedding!.isNotEmpty) {
        final faceMeshService = FaceMeshService();
        final imageBytes = await File(shot.path).readAsBytes();
        final currentEmbedding = await faceMeshService.extractFaceEmbedding(imageBytes);
        final similarity = faceMeshService.computeSimilarity(_registeredFaceEmbedding!, currentEmbedding);
        _faceDetected = true;
        _faceMatched = similarity >= 0.75; // FaceMesh threshold
        if (!_faceMatched) {
          _error = 'Face not matched (similarity=${similarity.toStringAsFixed(2)})';
        }
      } else {
        // Fallback to old method
        final input = InputImage.fromFilePath(shot.path);
        final options = FaceDetectorOptions(
          enableContours: true,
          enableClassification: true,
          performanceMode: FaceDetectorMode.accurate,
        );
        final detector = FaceDetector(options: options);
        final faces = await detector.processImage(input);
        _faceDetected = faces.isNotEmpty;
        if (_faceDetected) {
          // choose the biggest face
          faces.sort((a, b) {
            final aa = a.boundingBox.width * a.boundingBox.height;
            final bb = b.boundingBox.width * b.boundingBox.height;
            return bb.compareTo(aa);
          });
          final f = faces.first;
          final headEulerY = f.headEulerAngleY ?? 0.0;
          final headEulerZ = f.headEulerAngleZ ?? 0.0;
          if (headEulerY.abs() <= 20 && headEulerZ.abs() <= 20) {
            final vector = _computeFaceVector(f);
            if (_registeredFaceVector != null && vector.isNotEmpty) {
              final sim = _cosineSimilarity(_registeredFaceVector!, vector);
              _faceMatched = sim >= 0.82;
              if (!_faceMatched) {
                _error = 'Face not matched (similarity=${sim.toStringAsFixed(2)})';
              }
            } else {
              _error = 'No registered face found';
            }
          } else {
            _error = 'Face not frontal. Keep your head straight.';
          }
        } else {
          _error = 'No face detected. Improve lighting and center your face.';
        }
        await detector.close();
      }
    } catch (e) {
      _error = 'Face scanning failed: $e';
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  void stopScanning() {
    _isScanning = false;
    notifyListeners();
  }

  void resetScanning() {
    _faceDetected = false;
    _faceMatched = false;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> ensureInitialized() async {
    if (!_isInitialized || _cameraController == null || !(_cameraController!.value.isInitialized)) {
      await initializeCamera();
    }
  }

  Future<void> loadRegisteredFaceVector(String userId) async {
    try {
      final row = await DbService().getUserRaw(userId);
      if (row != null) {
        final raw = row['face_vector'];
        if (raw is String && raw.trim().isNotEmpty) {
          _registeredFaceVector = _parseFaceVectorString(raw);
          notifyListeners();
        }
      }
    } catch (e) {
      _error = 'Failed to load face vector: $e';
      notifyListeners();
    }
  }

  List<double> _computeFaceVector(Face face) {
    // Build a simple vector from selected contour points (e.g., left/right eye, nose, mouth)
    final points = <Point<double>>[];
    final contours = face.contours;
    void addPoints(FaceContourType type) {
      final c = contours[type];
      if (c != null) {
        for (final p in c.points) {
          points.add(Point(p.x.toDouble(), p.y.toDouble()));
        }
      }
    }
    addPoints(FaceContourType.leftEye);
    addPoints(FaceContourType.rightEye);
    addPoints(FaceContourType.noseBottom);
    addPoints(FaceContourType.upperLipTop);
    addPoints(FaceContourType.lowerLipBottom);
    if (points.isEmpty) return [];
    final meanX = points.map((e) => e.x).reduce((a,b)=>a+b)/points.length;
    final meanY = points.map((e) => e.y).reduce((a,b)=>a+b)/points.length;
    final vector = <double>[];
    for (final p in points) {
      vector..add(p.x - meanX)..add(p.y - meanY);
    }
    // L2 normalize
    final norm = sqrt(vector.fold<double>(0, (s, v) => s + v*v));
    if (norm == 0) return vector;
    return vector.map((v) => v / norm).toList(growable: false);
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.isEmpty || b.isEmpty) return 0;
    final n = a.length < b.length ? a.length : b.length;
    double dot = 0, na = 0, nb = 0;
    for (int i=0;i<n;i++) { dot += a[i]*b[i]; na += a[i]*a[i]; nb += b[i]*b[i]; }
    if (na == 0 || nb == 0) return 0;
    return dot / (sqrt(na) * sqrt(nb));
  }

  List<double> _parseFaceVectorString(String raw) {
    // Supports either JSON array ("[0.1,0.2]") or Dart list toString ("[0.1, 0.2]")
    try {
      final trimmed = raw.trim();
      final withoutBrackets = trimmed.startsWith('[') && trimmed.endsWith(']')
          ? trimmed.substring(1, trimmed.length - 1)
          : trimmed;
      if (withoutBrackets.isEmpty) return [];
      return withoutBrackets
          .split(',')
          .map((s) => double.tryParse(s.trim()) ?? 0.0)
          .toList(growable: false);
    } catch (_) {
      return [];
    }
  }
}
