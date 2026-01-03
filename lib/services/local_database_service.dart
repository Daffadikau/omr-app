import 'dart:async';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/exam_submission.dart';

class LocalDatabaseService {
  static Database? _database;
  static const String _databaseName = 'omr_scanner.db';
  static const int _databaseVersion = 1;

  /// Get or initialize the local database
  static Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize the local database with all tables
  static Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Create database tables
  static Future<void> _onCreate(Database db, int version) async {
    // Offline exams table
    await db.execute('''
      CREATE TABLE offline_exams (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firebase_id TEXT UNIQUE,
        student_name TEXT NOT NULL,
        image_path TEXT NOT NULL,
        processed_image_path TEXT,
        status TEXT NOT NULL,
        result_score REAL,
        error_message TEXT,
        metadata TEXT,
        subject TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        sync_error TEXT,
        last_sync_attempt TEXT
      )
    ''');

    // Sync queue table
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        item_type TEXT NOT NULL,
        item_id TEXT NOT NULL,
        action_type TEXT NOT NULL,
        data TEXT NOT NULL,
        priority INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0,
        max_retries INTEGER NOT NULL DEFAULT 3,
        status TEXT NOT NULL DEFAULT 'pending'
      )
    ''');

    // Analytics cache table
    await db.execute('''
      CREATE TABLE analytics_cache (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cache_key TEXT UNIQUE NOT NULL,
        data TEXT NOT NULL,
        expires_at TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // Create indexes for better performance
    await db.execute(
      'CREATE INDEX idx_offline_exams_status ON offline_exams(status)',
    );
    await db.execute(
      'CREATE INDEX idx_offline_exams_sync_status ON offline_exams(sync_status)',
    );
    await db.execute(
      'CREATE INDEX idx_offline_exams_created_at ON offline_exams(created_at)',
    );
    await db.execute(
      'CREATE INDEX idx_sync_queue_status ON sync_queue(status)',
    );
    await db.execute(
      'CREATE INDEX idx_sync_queue_priority ON sync_queue(priority)',
    );
    await db.execute(
      'CREATE INDEX idx_analytics_cache_key ON analytics_cache(cache_key)',
    );
  }

  /// Handle database upgrades
  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // Add migration logic here if needed
    if (oldVersion < 2) {
      // Migration from version 1 to 2
      await db.execute('ALTER TABLE offline_exams ADD COLUMN subject TEXT');
    }
  }

  // ===== OFFLINE EXAM OPERATIONS =====

  /// Save exam submission to local database
  static Future<int> saveExamSubmission(ExamSubmission exam) async {
    final db = await database;

    final examData = {
      'firebase_id': exam.id,
      'student_name': exam.studentName,
      'image_path': exam.imageUrl,
      'status': exam.status,
      'result_score': exam.resultScore,
      'metadata': exam.metadata?.toString(),
      'subject': exam.subject,
      'created_at':
          exam.timestamp?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'sync_status': exam.id.isNotEmpty ? 'synced' : 'pending',
    };

    return await db.insert(
      'offline_exams',
      examData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all offline exam submissions
  static Future<List<ExamSubmission>> getOfflineExamSubmissions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'offline_exams',
      orderBy: 'created_at DESC',
    );

    return List.generate(maps.length, (i) {
      return ExamSubmission(
        id: maps[i]['firebase_id'] ?? maps[i]['id'].toString(),
        studentName: maps[i]['student_name'],
        imageUrl: maps[i]['image_path'],
        status: maps[i]['status'],
        resultScore: maps[i]['result_score'],
        timestamp: DateTime.parse(maps[i]['created_at']),
        subject: maps[i]['subject'],
        metadata: maps[i]['metadata'] != null
            ? {'data': maps[i]['metadata']}
            : null,
      );
    });
  }

  /// Get exam submission by ID
  static Future<ExamSubmission?> getExamSubmission(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'offline_exams',
      where: 'firebase_id = ? OR id = ?',
      whereArgs: [id, id],
      limit: 1,
    );

    if (maps.isEmpty) return null;

    final map = maps.first;
    return ExamSubmission(
      id: map['firebase_id'] ?? map['id'].toString(),
      studentName: map['student_name'],
      imageUrl: map['image_path'],
      status: map['status'],
      resultScore: map['result_score'],
      timestamp: DateTime.parse(map['created_at']),
      subject: map['subject'],
      metadata: map['metadata'] != null ? {'data': map['metadata']} : null,
    );
  }

  /// Update exam submission
  static Future<int> updateExamSubmission(ExamSubmission exam) async {
    final db = await database;

    final examData = {
      'student_name': exam.studentName,
      'image_path': exam.imageUrl,
      'status': exam.status,
      'result_score': exam.resultScore,
      'metadata': exam.metadata?.toString(),
      'subject': exam.subject,
      'updated_at': DateTime.now().toIso8601String(),
    };

    return await db.update(
      'offline_exams',
      examData,
      where: 'firebase_id = ?',
      whereArgs: [exam.id],
    );
  }

  /// Delete exam submission
  static Future<int> deleteExamSubmission(String id) async {
    final db = await database;
    return await db.delete(
      'offline_exams',
      where: 'firebase_id = ?',
      whereArgs: [id],
    );
  }

  // ===== SYNC QUEUE OPERATIONS =====

  /// Add item to sync queue
  static Future<int> addToSyncQueue({
    required String itemType,
    required String itemId,
    required String actionType,
    required Map<String, dynamic> data,
    int priority = 1,
  }) async {
    final db = await database;

    final queueItem = {
      'item_type': itemType,
      'item_id': itemId,
      'action_type': actionType,
      'data': data.toString(),
      'priority': priority,
      'created_at': DateTime.now().toIso8601String(),
      'retry_count': 0,
    };

    return await db.insert('sync_queue', queueItem);
  }

  /// Get pending sync items
  static Future<List<Map<String, dynamic>>> getPendingSyncItems() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sync_queue',
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'priority DESC, created_at ASC',
    );

    return maps;
  }

  /// Mark sync item as completed
  static Future<int> markSyncItemCompleted(int itemId) async {
    final db = await database;
    return await db.update(
      'sync_queue',
      {'status': 'completed'},
      where: 'id = ?',
      whereArgs: [itemId],
    );
  }

  /// Mark sync item as failed
  static Future<int> markSyncItemFailed(int itemId, {String? error}) async {
    final db = await database;
    final item = await db.query(
      'sync_queue',
      where: 'id = ?',
      whereArgs: [itemId],
      limit: 1,
    );

    if (item.isEmpty) return 0;

    final currentRetryCount = item.first['retry_count'] as int;
    final maxRetries = item.first['max_retries'] as int;

    if (currentRetryCount >= maxRetries) {
      return await db.update(
        'sync_queue',
        {'status': 'failed', 'sync_error': error},
        where: 'id = ?',
        whereArgs: [itemId],
      );
    } else {
      return await db.update(
        'sync_queue',
        {
          'retry_count': currentRetryCount + 1,
          'last_sync_attempt': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [itemId],
      );
    }
  }

  // ===== ANALYTICS CACHE OPERATIONS =====

  /// Cache analytics data
  static Future<void> cacheAnalyticsData(
    String key,
    Map<String, dynamic> data,
    Duration expiry,
  ) async {
    final db = await database;
    final expiresAt = DateTime.now().add(expiry).toIso8601String();

    final cacheData = {
      'cache_key': key,
      'data': data.toString(),
      'expires_at': expiresAt,
      'created_at': DateTime.now().toIso8601String(),
    };

    await db.insert(
      'analytics_cache',
      cacheData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get cached analytics data
  static Future<Map<String, dynamic>?> getCachedAnalyticsData(
    String key,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'analytics_cache',
      where: 'cache_key = ? AND expires_at > ?',
      whereArgs: [key, DateTime.now().toIso8601String()],
      limit: 1,
    );

    if (maps.isEmpty) return null;

    // Parse the cached data (you might want to use a proper JSON parser here)
    return {'data': maps.first['data']};
  }

  /// Clear expired cache
  static Future<void> clearExpiredCache() async {
    final db = await database;
    await db.delete(
      'analytics_cache',
      where: 'expires_at < ?',
      whereArgs: [DateTime.now().toIso8601String()],
    );
  }

  // ===== UTILITY METHODS =====

  /// Get database statistics
  static Future<Map<String, int>> getDatabaseStats() async {
    final db = await database;

    final examCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM offline_exams'),
    );
    final pendingSyncCount = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM sync_queue WHERE status = "pending"',
      ),
    );
    final cacheCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM analytics_cache'),
    );

    return {
      'total_exams': examCount ?? 0,
      'pending_sync': pendingSyncCount ?? 0,
      'cached_items': cacheCount ?? 0,
    };
  }

  /// Clear all data (for testing or reset)
  static Future<void> clearAllData() async {
    final db = await database;
    await db.delete('offline_exams');
    await db.delete('sync_queue');
    await db.delete('analytics_cache');
  }

  /// Close database connection
  static Future<void> closeDatabase() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
