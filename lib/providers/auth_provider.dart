import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/db_service.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;

  Future<void> registerUser(UserModel user, {List<double>? faceVector, String? faceImagePath}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Persist to SQLite
      final row = user.toJson();
      if (faceVector != null) {
        row['faceVector'] = faceVector;
      }
      if (faceImagePath != null) {
        row['faceImagePath'] = faceImagePath;
      }
      await DbService().upsertUser({
        'id': row['id'],
        'name': row['name'],
        'age': row['age'],
        'gender': row['gender'],
        'latitude': row['latitude'],
        'longitude': row['longitude'],
        'location': row['location'],
        'face_image_path': row['faceImagePath'],
        'face_vector': faceVector != null ? faceVector.toString() : null,
        'preferred_sports': row['preferredSports'],
        'govt_id': row['govtId'],
        'registration_date': row['registrationDate'],
        'is_verified': row['isVerified'] == true ? 1 : 0,
      });

      // Keep a lightweight pointer in SharedPreferences for current user id
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user_id', user.id);

      _currentUser = user;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Registration failed: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadUser() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('current_user_id');
      if (userId != null) {
        final data = await DbService().getUserRaw(userId);
        if (data != null) {
          _currentUser = UserModel.fromJson({
            'id': data['id'],
            'name': data['name'],
            'age': data['age'],
            'gender': data['gender'],
            'latitude': data['latitude'],
            'longitude': data['longitude'],
            'location': data['location'],
            'faceImagePath': data['face_image_path'],
            'faceVector': null,
            'preferredSports': data['preferred_sports'],
            'govtId': data['govt_id'],
            'registrationDate': data['registration_date'] ?? DateTime.now().toIso8601String(),
            'isVerified': (data['is_verified'] as int? ?? 0) == 1,
          });
        }
      }
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load user: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user_id');
    _currentUser = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
