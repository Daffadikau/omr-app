import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/exam_submission.dart';
import 'local_database_service.dart';
import 'sync_service.dart';

class OfflineQueueService {
  static OfflineQueueService? _instance;
  static OfflineQueueService get instance =>
      _instance ??= OfflineQueueService._();
  OfflineQueueService._();

  // Queue management
  final List<QueueItem> _processingQueue = [];
  final List<QueueItem> _pendingQueue = [];
  final List<QueueItem> _failedQueue = [];

  // State variables
  bool _isProcessing = false;
  final int _maxConcurrentUploads = 3;
  Timer? _processingTimer;

  // Stream controllers for real-time updates
  final StreamController<QueueStatus> _queueStatusController =
      StreamController.broadcast();
  final StreamController<int> _progressController =
      StreamController.broadcast();

  // Getters
  Stream<QueueStatus> get queueStatusStream => _queueStatusController.stream;
  Stream<int> get progressStream => _progressController.stream;

  List<QueueItem> get pendingQueue => List.unmodifiable(_pendingQueue);
  List<QueueItem> get processingQueue => List.unmodifiable(_processingQueue);
  List<QueueItem> get failedQueue => List.unmodifiable(_failedQueue);
  bool get isProcessing => _isProcessing;

  /// Initialize the offline queue service
  Future<void> initialize() async {
    try {
      // Load existing queue items from database
      await _loadQueueFromDatabase();

      // Start processing timer
      _startProcessingTimer();

      print('Offline queue service initialized');
    } catch (e) {
      print('Error initializing offline queue service: $e');
    }
  }

  /// Add item to queue
  Future<void> addToQueue({
    required QueueItemType type,
    required String itemId,
    required Map<String, dynamic> data,
    int priority = 1,
    int maxRetries = 3,
  }) async {
    final queueItem = QueueItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      itemId: itemId,
      data: data,
      priority: priority,
      maxRetries: maxRetries,
      createdAt: DateTime.now(),
      retryCount: 0,
    );

    // Add to pending queue
    _pendingQueue.add(queueItem);

    // Save to database
    await _saveQueueToDatabase();

    // Sort by priority
    _sortQueueByPriority();

    // Notify listeners
    _queueStatusController.add(QueueStatus.itemAdded);

    // Trigger processing
    _triggerProcessing();
  }

  /// Remove item from queue
  Future<void> removeFromQueue(String itemId) async {
    _pendingQueue.removeWhere((item) => item.id == itemId);
    _processingQueue.removeWhere((item) => item.id == itemId);
    _failedQueue.removeWhere((item) => item.id == itemId);

    await _saveQueueToDatabase();
    _queueStatusController.add(QueueStatus.itemRemoved);
  }

  /// Clear all queues
  Future<void> clearAllQueues() async {
    _pendingQueue.clear();
    _processingQueue.clear();
    _failedQueue.clear();

    await _saveQueueToDatabase();
    _queueStatusController.add(QueueStatus.queueCleared);
  }

  /// Start processing queue
  void startProcessing() {
    if (!_isProcessing) {
      _triggerProcessing();
    }
  }

  /// Stop processing queue
  void stopProcessing() {
    _processingTimer?.cancel();
    _isProcessing = false;
  }

  /// Retry failed items
  Future<void> retryFailedItems() async {
    for (final item in List.from(_failedQueue)) {
      item.retryCount = 0;
      _pendingQueue.add(item);
      _failedQueue.remove(item);
    }

    _sortQueueByPriority();
    await _saveQueueToDatabase();
    _triggerProcessing();
  }

  /// Get queue statistics
  QueueStatistics getStatistics() {
    return QueueStatistics(
      pendingCount: _pendingQueue.length,
      processingCount: _processingQueue.length,
      failedCount: _failedQueue.length,
      totalCount:
          _pendingQueue.length + _processingQueue.length + _failedQueue.length,
      isProcessing: _isProcessing,
    );
  }

  /// Start processing timer
  void _startProcessingTimer() {
    _processingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _triggerProcessing();
    });
  }

  /// Trigger processing
  void _triggerProcessing() async {
    if (_isProcessing) return;

    // Check if we can process more items
    if (_processingQueue.length >= _maxConcurrentUploads) return;
    if (_pendingQueue.isEmpty) return;

    _isProcessing = true;
    _queueStatusController.add(QueueStatus.processingStarted);

    try {
      // Move items from pending to processing
      while (_processingQueue.length < _maxConcurrentUploads &&
          _pendingQueue.isNotEmpty) {
        final item = _pendingQueue.removeAt(0);
        _processingQueue.add(item);

        // Process item
        _processQueueItem(item);
      }
    } catch (e) {
      print('Error triggering processing: $e');
    } finally {
      _isProcessing = false;
    }
  }

  /// Process individual queue item
  Future<void> _processQueueItem(QueueItem item) async {
    try {
      switch (item.type) {
        case QueueItemType.uploadExam:
          await _processUploadExam(item);
          break;
        case QueueItemType.updateExam:
          await _processUpdateExam(item);
          break;
        case QueueItemType.deleteExam:
          await _processDeleteExam(item);
          break;
        case QueueItemType.syncAnalytics:
          await _processSyncAnalytics(item);
          break;
        default:
          throw Exception('Unknown queue item type: ${item.type}');
      }

      // Item processed successfully
      _processingQueue.removeWhere((queueItem) => queueItem.id == item.id);
      await _saveQueueToDatabase();

      _queueStatusController.add(QueueStatus.itemCompleted);
      _progressController.add(_getProgressPercentage());
    } catch (e) {
      // Item processing failed
      await _handleProcessingError(item, e);
    }
  }

  /// Process exam upload
  Future<void> _processUploadExam(QueueItem item) async {
    // Create ExamSubmission from data map using fromMap() method
    final examData = ExamSubmission.fromMap(item.data);

    // Use the sync service to upload
    await SyncService.instance.queueExamForSync(examData);
  }

  /// Process exam update
  Future<void> _processUpdateExam(QueueItem item) async {
    // Create ExamSubmission from data map using fromMap() method
    final examData = ExamSubmission.fromMap(item.data);

    // Update exam in local database and sync
    await LocalDatabaseService.updateExamSubmission(examData);
    // TODO: Implement Firebase update through sync service
  }

  /// Process exam deletion
  Future<void> _processDeleteExam(QueueItem item) async {
    // Delete from local database
    await LocalDatabaseService.deleteExamSubmission(item.itemId);
    // TODO: Implement Firebase deletion through sync service
  }

  /// Process analytics sync
  Future<void> _processSyncAnalytics(QueueItem item) async {
    // Sync analytics data
    await SyncService.instance.syncNow();
  }

  /// Handle processing errors
  Future<void> _handleProcessingError(QueueItem item, dynamic error) async {
    item.retryCount++;

    if (item.retryCount >= item.maxRetries) {
      // Max retries reached, move to failed queue
      _processingQueue.removeWhere((queueItem) => queueItem.id == item.id);
      _failedQueue.add(item);
      _queueStatusController.add(QueueStatus.itemFailed);
    } else {
      // Move back to pending queue for retry
      _processingQueue.removeWhere((queueItem) => queueItem.id == item.id);
      _pendingQueue.insert(0, item); // Insert at beginning for retry
    }

    await _saveQueueToDatabase();
    print('Queue item ${item.id} failed: $error');
  }

  /// Sort queue by priority
  void _sortQueueByPriority() {
    _pendingQueue.sort((a, b) => b.priority.compareTo(a.priority));
  }

  /// Get progress percentage
  int _getProgressPercentage() {
    final total =
        _pendingQueue.length + _processingQueue.length + _failedQueue.length;
    if (total == 0) return 100;

    final completed =
        _failedQueue.length; // Only failed items are "completed" for now
    return ((total - _pendingQueue.length - _processingQueue.length) /
            total *
            100)
        .round();
  }

  /// Load queue from database
  Future<void> _loadQueueFromDatabase() async {
    try {
      final pendingItems = await LocalDatabaseService.getPendingSyncItems();

      for (final itemData in pendingItems) {
        final item = QueueItem.fromMap(itemData);

        // Categorize based on status
        switch (item.status) {
          case 'pending':
            _pendingQueue.add(item);
            break;
          case 'processing':
            _processingQueue.add(item);
            break;
          case 'failed':
            _failedQueue.add(item);
            break;
        }
      }

      _sortQueueByPriority();
    } catch (e) {
      print('Error loading queue from database: $e');
    }
  }

  /// Save queue to database
  Future<void> _saveQueueToDatabase() async {
    try {
      // Clear existing queue items
      // TODO: Implement queue item deletion in LocalDatabaseService

      // Save current queue items
      final allItems = [..._pendingQueue, ..._processingQueue, ..._failedQueue];

      for (final item in allItems) {
        await LocalDatabaseService.addToSyncQueue(
          itemType: item.type.toString().split('.').last,
          itemId: item.itemId,
          actionType: item.type.toString().split('.').last,
          data: item.data,
          priority: item.priority,
        );
      }
    } catch (e) {
      print('Error saving queue to database: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _processingTimer?.cancel();
    _queueStatusController.close();
    _progressController.close();
  }
}

/// Queue item types
enum QueueItemType { uploadExam, updateExam, deleteExam, syncAnalytics }

/// Queue status
enum QueueStatus {
  itemAdded,
  itemRemoved,
  itemCompleted,
  itemFailed,
  processingStarted,
  queueCleared,
}

/// Queue item model
class QueueItem {
  final String id;
  final QueueItemType type;
  final String itemId;
  final Map<String, dynamic> data;
  final int priority;
  final int maxRetries;
  final DateTime createdAt;
  int retryCount;
  String status;

  QueueItem({
    required this.id,
    required this.type,
    required this.itemId,
    required this.data,
    required this.priority,
    required this.maxRetries,
    required this.createdAt,
    this.retryCount = 0,
    this.status = 'pending',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.toString(),
      'itemId': itemId,
      'data': data,
      'priority': priority,
      'maxRetries': maxRetries,
      'createdAt': createdAt.toIso8601String(),
      'retryCount': retryCount,
      'status': status,
    };
  }

  factory QueueItem.fromMap(Map<String, dynamic> map) {
    return QueueItem(
      id: map['id'] ?? '',
      type: QueueItemType.values.firstWhere(
        (e) => e.toString() == map['type'],
        orElse: () => QueueItemType.uploadExam,
      ),
      itemId: map['itemId'] ?? '',
      data: Map<String, dynamic>.from(map['data'] ?? {}),
      priority: map['priority'] ?? 1,
      maxRetries: map['maxRetries'] ?? 3,
      createdAt: DateTime.parse(
        map['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      retryCount: map['retryCount'] ?? 0,
      status: map['status'] ?? 'pending',
    );
  }
}

/// Queue statistics model
class QueueStatistics {
  final int pendingCount;
  final int processingCount;
  final int failedCount;
  final int totalCount;
  final bool isProcessing;

  const QueueStatistics({
    required this.pendingCount,
    required this.processingCount,
    required this.failedCount,
    required this.totalCount,
    required this.isProcessing,
  });

  int get completedCount => totalCount - pendingCount - processingCount;
  double get completionPercentage => totalCount > 0
      ? (completedCount / totalCount * 100).clamp(0.0, 100.0)
      : 0.0;
}
