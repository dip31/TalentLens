import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DbService {
  static final DbService _instance = DbService._internal();
  factory DbService() => _instance;
  DbService._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'sports_talent.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE users (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            age INTEGER NOT NULL,
            gender TEXT NOT NULL,
            latitude REAL,
            longitude REAL,
            location TEXT,
            face_image_path TEXT,
            face_vector TEXT,
            preferred_sports TEXT,
            govt_id TEXT,
            registration_date TEXT,
            is_verified INTEGER DEFAULT 0
          );
        ''');
        await db.execute('''
          CREATE TABLE assessments (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            test_name TEXT NOT NULL,
            metrics TEXT,
            validity_flag INTEGER DEFAULT 1,
            cheat_indicators TEXT,
            trial_number INTEGER DEFAULT 1,
            video_path TEXT,
            created_at TEXT,
            synced INTEGER DEFAULT 0,
            FOREIGN KEY(user_id) REFERENCES users(id)
          );
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE assessments ADD COLUMN synced INTEGER DEFAULT 0');
        }
      },
    );
  }

  Future<void> upsertUser(Map<String, dynamic> userRow) async {
    final db = await database;
    await db.insert(
      'users',
      userRow,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getUserRaw(String id) async {
    final db = await database;
    final res = await db.query('users', where: 'id=?', whereArgs: [id], limit: 1);
    if (res.isEmpty) return null;
    return res.first;
  }

  Future<void> insertAssessment({
    required String id,
    required String userId,
    required String testName,
    required Map<String, dynamic> metrics,
    required bool validityFlag,
    required String cheatIndicators,
    required int trialNumber,
    String? videoPath,
    bool synced = false,
  }) async {
    final db = await database;
    await db.insert('assessments', {
      'id': id,
      'user_id': userId,
      'test_name': testName,
      'metrics': jsonEncode(metrics),
      'validity_flag': validityFlag ? 1 : 0,
      'cheat_indicators': cheatIndicators,
      'trial_number': trialNumber,
      'video_path': videoPath,
      'created_at': DateTime.now().toIso8601String(),
      'synced': synced ? 1 : 0,
    });
  }

  Future<List<Map<String, dynamic>>> getLeaderboard(String testName) async {
    final db = await database;
    final res = await db.rawQuery(
      r'''
      SELECT a.user_id, u.name, u.gender, u.age, a.metrics, a.validity_flag, a.cheat_indicators, a.trial_number, a.created_at
      FROM assessments a
      JOIN users u ON u.id = a.user_id
      WHERE a.test_name = ?
      ORDER BY json_extract(a.metrics, '$.reps') DESC, a.created_at ASC
      '''
      , [testName]);
    return res;
  }

  Future<int> getTrialCount(String userId, String testName) async {
    final db = await database;
    final res = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM assessments WHERE user_id=? AND test_name=?',
      [userId, testName],
    );
    final v = res.first['cnt'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  Future<void> clearCurrentUserData(String userId) async {
    final db = await database;
    await db.delete('assessments', where: 'user_id=?', whereArgs: [userId]);
    await db.delete('users', where: 'id=?', whereArgs: [userId]);
  }

  Future<List<Map<String, dynamic>>> getUnsyncedAssessments() async {
    final db = await database;
    return db.query('assessments', where: 'synced = 0');
  }

  Future<void> markAssessmentSynced(String id) async {
    final db = await database;
    await db.update('assessments', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
  }
}