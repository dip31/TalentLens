import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'db_service.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  StreamSubscription<List<ConnectivityResult>>? _sub;

  void start() {
    _sub?.cancel();
    _sub = Connectivity().onConnectivityChanged.listen((results) async {
      final any = results.any((r) => r != ConnectivityResult.none);
      if (any) {
        await _syncPending();
      }
    });
  }

  Future<void> _syncPending() async {
    final pending = await DbService().getUnsyncedAssessments();
    for (final row in pending) {
      // TODO: upload to backend API, including video file if present
      // Simulate success
      await Future.delayed(const Duration(milliseconds: 200));
      await DbService().markAssessmentSynced(row['id'] as String);
    }
  }

  void dispose() {
    _sub?.cancel();
  }
}


