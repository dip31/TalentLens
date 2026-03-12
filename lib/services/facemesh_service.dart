import 'dart:typed_data';
import 'dart:math';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:image/image.dart' as img;

class FaceMeshService {
  static final FaceMeshService _instance = FaceMeshService._internal();
  factory FaceMeshService() => _instance;
  FaceMeshService._internal();

  tfl.Interpreter? _interpreter;
  static const int inputSize = 192; // FaceMesh input size
  static const int numLandmarks = 468; // FaceMesh landmark count

  Future<void> ensureLoaded() async {
    if (_interpreter != null) return;
    _interpreter = await tfl.Interpreter.fromAsset('assets/models/face_landmark.tflite');
  }

  Future<List<double>> extractFaceEmbedding(Uint8List imageBytes) async {
    await ensureLoaded();
    final interpreter = _interpreter!;
    
    // Decode and preprocess image
    final input = _preprocessImage(imageBytes);
    
    // Run inference
    final output = List.filled(1 * numLandmarks * 3, 0.0).reshape([1, numLandmarks, 3]);
    interpreter.run(input, output);
    
    // Extract face embedding from landmarks
    return _computeFaceEmbedding(output[0]);
  }

  List<List<List<List<double>>>> _preprocessImage(Uint8List imageBytes) {
    // Decode JPEG/PNG to Image
    final image = img.decodeImage(imageBytes);
    if (image == null) {
      throw Exception('Failed to decode image');
    }
    
    // Resize to 192x192 (FaceMesh input size)
    final resized = img.copyResize(image, width: inputSize, height: inputSize);
    
    // Convert to RGB float32 normalized to [0,1]
    final input = List.generate(1, (_) =>
      List.generate(inputSize, (_) =>
        List.generate(inputSize, (_) =>
          List.filled(3, 0.0))));
    
    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final p = resized.getPixel(x, y);
        input[0][y][x][0] = p.r / 255.0;
        input[0][y][x][1] = p.g / 255.0;
        input[0][y][x][2] = p.b / 255.0;
      }
    }
    
    return input;
  }

  List<double> _computeFaceEmbedding(List<List<double>> landmarks) {
    // Extract key facial features for embedding
    final List<double> embedding = [];
    
    // Eye landmarks (left and right)
    final leftEye = _getEyeLandmarks(landmarks, true);
    final rightEye = _getEyeLandmarks(landmarks, false);
    
    // Nose landmarks
    final nose = _getNoseLandmarks(landmarks);
    
    // Mouth landmarks
    final mouth = _getMouthLandmarks(landmarks);
    
    // Face contour
    final contour = _getFaceContour(landmarks);
    
    // Compute relative distances and angles
    embedding.addAll(_computeDistances(leftEye, rightEye));
    embedding.addAll(_computeDistances(leftEye, nose));
    embedding.addAll(_computeDistances(rightEye, nose));
    embedding.addAll(_computeDistances(nose, mouth));
    embedding.addAll(_computeAngles(leftEye, rightEye, nose));
    embedding.addAll(_computeAngles(leftEye, nose, mouth));
    
    // Add face shape features
    embedding.addAll(_computeFaceShape(contour));
    
    // Normalize embedding
    return _normalizeEmbedding(embedding);
  }

  List<double> _getEyeLandmarks(List<List<double>> landmarks, bool isLeft) {
    // Simplified eye landmark extraction
    final start = isLeft ? 33 : 362;
    final end = isLeft ? 46 : 374;
    final List<double> eye = [];
    for (int i = start; i <= end; i++) {
      if (i < landmarks.length) {
        eye.addAll([landmarks[i][0], landmarks[i][1]]);
      }
    }
    return eye;
  }

  List<double> _getNoseLandmarks(List<List<double>> landmarks) {
    final List<double> nose = [];
    for (int i = 1; i <= 5; i++) {
      if (i < landmarks.length) {
        nose.addAll([landmarks[i][0], landmarks[i][1]]);
      }
    }
    return nose;
  }

  List<double> _getMouthLandmarks(List<List<double>> landmarks) {
    final List<double> mouth = [];
    for (int i = 61; i <= 84; i++) {
      if (i < landmarks.length) {
        mouth.addAll([landmarks[i][0], landmarks[i][1]]);
      }
    }
    return mouth;
  }

  List<double> _getFaceContour(List<List<double>> landmarks) {
    final List<double> contour = [];
    for (int i = 0; i < landmarks.length; i += 10) {
      contour.addAll([landmarks[i][0], landmarks[i][1]]);
    }
    return contour;
  }

  List<double> _computeDistances(List<double> points1, List<double> points2) {
    final List<double> distances = [];
    for (int i = 0; i < points1.length; i += 2) {
      for (int j = 0; j < points2.length; j += 2) {
        final dx = points1[i] - points2[j];
        final dy = points1[i + 1] - points2[j + 1];
        distances.add(sqrt(dx * dx + dy * dy));
      }
    }
    return distances;
  }

  List<double> _computeAngles(List<double> points1, List<double> points2, List<double> points3) {
    final List<double> angles = [];
    for (int i = 0; i < points1.length; i += 2) {
      for (int j = 0; j < points2.length; j += 2) {
        for (int k = 0; k < points3.length; k += 2) {
          final angle = _computeAngle(
            [points1[i], points1[i + 1]],
            [points2[j], points2[j + 1]],
            [points3[k], points3[k + 1]]
          );
          angles.add(angle);
        }
      }
    }
    return angles;
  }

  double _computeAngle(List<double> p1, List<double> p2, List<double> p3) {
    final v1 = [p1[0] - p2[0], p1[1] - p2[1]];
    final v2 = [p3[0] - p2[0], p3[1] - p2[1]];
    
    final dot = v1[0] * v2[0] + v1[1] * v2[1];
    final mag1 = sqrt(v1[0] * v1[0] + v1[1] * v1[1]);
    final mag2 = sqrt(v2[0] * v2[0] + v2[1] * v2[1]);
    
    if (mag1 == 0 || mag2 == 0) return 0;
    
    final cosAngle = (dot / (mag1 * mag2)).clamp(-1.0, 1.0);
    return acos(cosAngle) * 180 / pi;
  }

  List<double> _computeFaceShape(List<double> contour) {
    // Compute face width, height, and aspect ratio
    if (contour.length < 4) return [0, 0, 0];
    
    double minX = contour[0], maxX = contour[0];
    double minY = contour[1], maxY = contour[1];
    
    for (int i = 0; i < contour.length; i += 2) {
      minX = min(minX, contour[i]);
      maxX = max(maxX, contour[i]);
      minY = min(minY, contour[i + 1]);
      maxY = max(maxY, contour[i + 1]);
    }
    
    final width = maxX - minX;
    final height = maxY - minY;
    final aspectRatio = height > 0 ? width / height : 0;
    
    return [width, height, aspectRatio.toDouble()];
  }

  List<double> _normalizeEmbedding(List<double> embedding) {
    if (embedding.isEmpty) return embedding;
    
    // L2 normalization
    final norm = sqrt(embedding.fold(0.0, (sum, val) => sum + val * val));
    if (norm == 0) return embedding;
    
    return embedding.map((val) => val / norm).toList();
  }

  double computeSimilarity(List<double> embedding1, List<double> embedding2) {
    if (embedding1.length != embedding2.length) return 0.0;
    
    double dotProduct = 0.0;
    for (int i = 0; i < embedding1.length; i++) {
      dotProduct += embedding1[i] * embedding2[i];
    }
    
    return dotProduct.clamp(0.0, 1.0);
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}
