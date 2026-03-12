import 'package:permission_handler/permission_handler.dart';

class PermissionHelper {
  static Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status == PermissionStatus.granted;
  }

  static Future<bool> requestLocationPermission() async {
    final status = await Permission.location.request();
    return status == PermissionStatus.granted;
  }

  static Future<bool> requestStoragePermission() async {
    final status = await Permission.storage.request();
    return status == PermissionStatus.granted;
  }

  // Unified gallery/media picker permission across platforms and SDKs
  // - Android 13+ prefers READ_MEDIA_* via Permission.photos/Permission.videos
  // - Older Android falls back to storage
  // - iOS uses photos
  static Future<bool> requestGalleryPermission() async {
    // Try modern granular media permissions first
    final photos = await Permission.photos.request();
    final videos = await Permission.videos.request();
    if (photos == PermissionStatus.granted || videos == PermissionStatus.granted) {
      return true;
    }
    // Fallback for older Android
    final storage = await Permission.storage.request();
    return storage == PermissionStatus.granted;
  }

  static Future<Map<String, bool>> requestAllPermissions() async {
    final results = await [
      Permission.camera,
      Permission.location,
      Permission.photos,
      Permission.videos,
    ].request();

    return {
      'camera': results[Permission.camera] == PermissionStatus.granted,
      'location': results[Permission.location] == PermissionStatus.granted,
      'photos': results[Permission.photos] == PermissionStatus.granted,
      'videos': results[Permission.videos] == PermissionStatus.granted,
    };
  }

  static Future<bool> checkCameraPermission() async {
    final status = await Permission.camera.status;
    return status == PermissionStatus.granted;
  }

  static Future<bool> checkLocationPermission() async {
    final status = await Permission.location.status;
    return status == PermissionStatus.granted;
  }

  static Future<bool> checkStoragePermission() async {
    final status = await Permission.photos.status;
    return status == PermissionStatus.granted;
  }
}
