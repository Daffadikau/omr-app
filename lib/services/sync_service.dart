import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/exam_submission.dart';
import 'local_database_service.dart';

class SyncService {
  static SyncService? _instance;
  static SyncService get instance => _instance ??= SyncService._();
  SyncService._();

  // Stream controllers for real-time sync status
  final StreamController<SyncStatus> _syncStatusController =
      StreamController.broadcast();
  final StreamController<int> _syncProgressController =
      StreamController.broadcast();

  // Getters for streams
  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;
  Stream<int> get syncProgressStream => _syncProgressController.stream;

  // State variables
  bool _isSyncing = false;
  bool _isOnline = true;
  Timer? _periodicSyncTimer;

  /// Initialize the sync service
  Future<void> initialize() async {
    // Check initial connectivity
    _isOnline = await _checkConnectivity();

    // Listen to connectivity changes
    Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      final wasOnline = _isOnline;
      _isOnline =
          results.isNotEmpty && results.first != ConnectivityResult.none;

      if (wasOnline != _isOnline && _isOnline) {
        // Just came online, trigger sync
        _triggerSync();
      }
    });

    // Start periodic sync (every 5 minutes when online)
    _startPeriodicSync();
  }

  /// Check if device is connected to internet
  Future<bool> _checkConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) return false;

      // Test actual internet connectivity
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Start periodic sync timer
  void _startPeriodicSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (_isOnline && !_isSyncing) {
        _triggerSync();
      }
    });
  }

  /// Trigger background sync
  void _triggerSync() {
    if (_isOnline && !_isSyncing) {
      _syncData();
    }
  }

  /// Sync data between local database and Firebase
  Future<void> _syncData() async {
    if (_isSyncing) return;

    _isSyncing = true;
    _syncStatusController.add(SyncStatus.started);

    try {
      // Sync pending uploads
      await _syncPendingUploads();

      // Sync analytics data
      await _syncAnalyticsData();

      // Sync user preferences
      await _syncUserPreferences();

      _syncStatusController.add(SyncStatus.completed);
    } catch (e) {
      _syncStatusController.add(SyncStatus.error);
      print('Sync error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Sync pending uploads to Firebase
  Future<void> _syncPendingUploads() async {
    final pendingItems = await LocalDatabaseService.getPendingSyncItems();
    final totalItems = pendingItems.length;
    var processedItems = 0;

    for (final item in pendingItems) {
      try {
        await _processSyncItem(item);
        await LocalDatabaseService.markSyncItemCompleted(item['id']);
        processedItems++;
        _syncProgressController.add(
          (processedItems / totalItems * 100).round(),
        );
      } catch (e) {
        await LocalDatabaseService.markSyncItemFailed(
          item['id'],
          error: e.toString(),
        );
        print('Failed to sync item ${item['id']}: $e');
      }
    }
  }

  /// Process individual sync item
  Future<void> _processSyncItem(Map<String, dynamic> item) async {
    final actionType = item['action_type'] as String;
    final data = item['data'] as String;

    switch (actionType) {
      case 'upload_exam':
        await _uploadExamToFirebase(data);
        break;
      case 'update_exam':
        await _updateExamInFirebase(data);
        break;
      case 'delete_exam':
        await _deleteExamFromFirebase(data);
        break;
      default:
        throw Exception('Unknown action type: $actionType');
    }
  }

  /// Upload exam to Firebase Storage and Firestore
  Future<void> _uploadExamToFirebase(String examData) async {
    // Parse exam data (implement proper JSON parsing in production)
    final exam = _parseExamData(examData);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Upload image to Firebase Storage
    final imageRef = FirebaseStorage.instance.ref().child(
      'exams/${user.uid}/${exam.studentName}_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );

    final imageFile = File(exam.imageUrl);
    if (!imageFile.existsSync()) {
      throw Exception('Image file not found: ${exam.imageUrl}');
    }

    final uploadTask = await imageRef.putFile(imageFile);
    final downloadUrl = await uploadTask.ref.getDownloadURL();

    // Save exam data to Firestore
    final examDoc = FirebaseFirestore.instance.collection('exam_scans').doc();

    await examDoc.set({
      'student_name': exam.studentName,
      'image_url': downloadUrl,
      'status': 'processing',
      'user_id': user.uid,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });

    // Update local database with Firebase ID
    final updatedExam = exam.copyWith(id: examDoc.id);
    await LocalDatabaseService.saveExamSubmission(updatedExam);
  }

  /// Update exam in Firebase
  Future<void> _updateExamInFirebase(String examData) async {
    final exam = _parseExamData(examData);

    if (exam.id.isEmpty) return;

    final examDoc = FirebaseFirestore.instance
        .collection('exam_scans')
        .doc(exam.id);

    await examDoc.update({
      'student_name': exam.studentName,
      'status': exam.status,
      'result_score': exam.resultScore,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// Delete exam from Firebase
  Future<void> _deleteExamFromFirebase(String examData) async {
    final exam = _parseExamData(examData);

    if (exam.id.isEmpty) return;

    await FirebaseFirestore.instance
        .collection('exam_scans')
        .doc(exam.id)
        .delete();
  }

  /// Sync analytics data
  Future<void> _syncAnalyticsData() async {
    // Cache analytics data locally
    final analyticsData = {
      'last_sync': DateTime.now().toIso8601String(),
      'user_id': FirebaseAuth.instance.currentUser?.uid ?? 'anonymous',
    };

    await LocalDatabaseService.cacheAnalyticsData(
      'user_analytics',
      analyticsData,
      const Duration(hours: 1),
    );
  }

  /// Sync user preferences
  Future<void> _syncUserPreferences() async {
    // Implement user preferences sync if needed
  }

  /// Manual sync trigger
  Future<void> syncNow() async {
    await _syncData();
  }

  /// Add exam to sync queue for later upload
  Future<void> queueExamForSync(ExamSubmission exam) async {
    await LocalDatabaseService.addToSyncQueue(
      itemType: 'exam',
      itemId: exam.id,
      actionType: 'upload_exam',
      data: exam.toMap(),
      priority: 2,
    );
  }

  /// Get sync statistics
  Future<SyncStatistics> getSyncStatistics() async {
    final stats = await LocalDatabaseService.getDatabaseStats();
    return SyncStatistics(
      pendingUploads: stats['pending_sync'] ?? 0,
      totalExams: stats['total_exams'] ?? 0,
      isOnline: _isOnline,
      lastSyncTime: DateTime.now(),
      isSyncing: _isSyncing,
    );
  }

  /// Clean up resources
  void dispose() {
    _periodicSyncTimer?.cancel();
    _syncStatusController.close();
    _syncProgressController.close();
  }

  /// Parse exam data string back to ExamSubmission object
  ExamSubmission _parseExamData(String data) {
    // This is a simplified parser - implement proper JSON parsing in production
    // For now, return a basic exam submission
    return ExamSubmission(
      id: '',
      studentName: 'Unknown',
      imageUrl: '',
      status: 'pending',
    );
  }
}

/// Sync status enum
enum SyncStatus { idle, started, syncing, completed, error }

/// Sync statistics model
class SyncStatistics {
  final int pendingUploads;
  final int totalExams;
  final bool isOnline;
  final DateTime lastSyncTime;
  final bool isSyncing;

  const SyncStatistics({
    required this.pendingUploads,
    required this.totalExams,
    required this.isOnline,
    required this.lastSyncTime,
    required this.isSyncing,
  });
}
