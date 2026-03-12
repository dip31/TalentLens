import 'dart:typed_data';
import 'dart:math';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:image/image.dart' as img;

class MoveNetService {
  static final MoveNetService _instance = MoveNetService._internal();
  factory MoveNetService() => _instance;
  MoveNetService._internal();

  tfl.Interpreter? _interpreter;

  Future<void> ensureLoaded() async {
    if (_interpreter != null) return;
    _interpreter = await tfl.Interpreter.fromAsset('assets/models/movenet_thunder.tflite');
  }

  Future<List<List<double>>> estimatePosesFromVideo(String videoPath, {int sampleCount = 24}) async {
    await ensureLoaded();
    final interpreter = _interpreter!;
    final List<List<double>> keypointsOverTime = [];

    // Sample N frames evenly across the video using thumbnails
    for (int i = 0; i < sampleCount; i++) {
      final bytes = await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        quality: 75,
        timeMs: (i * 1000 ~/ (sampleCount / 2)).clamp(0, 60000),
      );
      if (bytes == null) continue;
      final input = _preprocess(bytes);
      final output = List.filled(1 * 17 * 3, 0.0).reshape([1, 17, 3]);
      interpreter.run(input, output);
      // Extract x,y for 17 keypoints (ignore confidence)
      final points = <double>[];
      for (int k = 0; k < 17; k++) {
        points.add(output[0][k][1]); // y
        points.add(output[0][k][0]); // x
      }
      keypointsOverTime.add(points);
    }
    return keypointsOverTime;
  }

  List<List<List<List<double>>>> _preprocess(Uint8List jpegBytes) {
    // Decode JPEG/PNG to Image
    final image = img.decodeImage(jpegBytes);
    if (image == null) {
      throw Exception('Failed to decode image');
    }
    
    // Resize to 256x256 (MoveNet Thunder input size)
    final resized = img.copyResize(image, width: 256, height: 256);
    
    // Convert to RGB float32 normalized to [-1,1] (MoveNet Thunder expects this range)
    final input = List.generate(1, (_) =>
      List.generate(256, (_) =>
        List.generate(256, (_) =>
          List.filled(3, 0.0))));
    
    for (int y = 0; y < 256; y++) {
      for (int x = 0; x < 256; x++) {
        final p = resized.getPixel(x, y);
        input[0][y][x][0] = (p.r / 127.5) - 1.0;   // R: [0,255] -> [-1,1]
        input[0][y][x][1] = (p.g / 127.5) - 1.0;   // G: [0,255] -> [-1,1]
        input[0][y][x][2] = (p.b / 127.5) - 1.0;   // B: [0,255] -> [-1,1]
      }
    }
    
    return input;
  }
}
