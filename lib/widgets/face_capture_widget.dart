import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/face_recognition_provider.dart';
import '../utils/permissions.dart';
import 'package:camera/camera.dart';

class FaceCaptureWidget extends StatefulWidget {
  final VoidCallback onFaceCaptured;

  const FaceCaptureWidget({
    super.key,
    required this.onFaceCaptured,
  });

  @override
  State<FaceCaptureWidget> createState() => _FaceCaptureWidgetState();
}

class _FaceCaptureWidgetState extends State<FaceCaptureWidget> {
  @override
  Widget build(BuildContext context) {
    return Consumer<FaceRecognitionProvider>(
      builder: (context, faceProvider, _) {
        if (!faceProvider.isInitialized) {
          return const Center(
            child: Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Initializing camera...'),
              ],
            ),
          );
        }

        if (faceProvider.error != null) {
          return Column(
            children: [
              Icon(
                Icons.error,
                color: Colors.red,
                size: 48,
              ),
              const SizedBox(height: 8),
              Text(
                faceProvider.error!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  faceProvider.initializeCamera();
                },
                child: const Text('Retry'),
              ),
            ],
          );
        }

        return Column(
          children: [
            // Camera Preview
            Container(
              height: 200,
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
                      CameraPreview(faceProvider.cameraController!),
                    
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
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Instructions
            const Text(
              'Position your face in the center of the frame',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            
            // Capture Button (use default system camera)
            ElevatedButton.icon(
              onPressed: () async {
                final granted = await PermissionHelper.requestCameraPermission();
                if (!granted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Camera permission required')),
                  );
                  return;
                }
                await faceProvider.captureFaceViaSystemCamera();
                if (faceProvider.registeredFaceVector != null && faceProvider.registeredFaceVector!.isNotEmpty) {
                  widget.onFaceCaptured();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Face captured successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else if (faceProvider.error != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(faceProvider.error!)),
                  );
                }
              },
              icon: const Icon(Icons.camera_alt),
              label: const Text('Capture Face'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }
}
