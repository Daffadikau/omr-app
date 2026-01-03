import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../models/batch_upload_item.dart';
import '../models/exam_submission.dart' as exam_model;
import 'advanced_image_processor.dart';
import 'image_optimization_service.dart';

class BatchUploadService {
  static const int MAX_BATCH_SIZE = 50;
  static const int CONCURRENT_UPLOADS = 3;
  static const List<String> SUPPORTED_FORMATS = ['jpg', 'jpeg', 'png', 'webp'];

  /// Create batch items from selected files
  static List<BatchUploadItem> createBatchItems({
    required List<File> files,
    required String baseStudentName,
  }) {
    List<BatchUploadItem> items = [];
    int index = 0;

    for (var file in files) {
      final fileExtension = file.path.split('.').last.toLowerCase();
      if (!SUPPORTED_FORMATS.contains(fileExtension)) {
        continue;
      }

      final studentName = '$baseStudentName ${index + 1}';
      final item = BatchUploadItem(
        id: DateTime.now().millisecondsSinceEpoch.toString() + index.toString(),
        studentName: studentName,
        mobileImage: file,
        webImage: null,
        isWeb: false,
        error: null,
        progress: 0.0,
        status: 'pending',
      );

      items.add(item);
      index++;
    }

    return items;
  }

  /// Create batch items from web images
  static List<BatchUploadItem> createBatchItemsFromWeb({
    required List<Uint8List> images,
    required String baseStudentName,
  }) {
    List<BatchUploadItem> items = [];
    int index = 0;

    for (var imageBytes in images) {
      final studentName = '$baseStudentName ${index + 1}';
      final item = BatchUploadItem(
        id: DateTime.now().millisecondsSinceEpoch.toString() + index.toString(),
        studentName: studentName,
        mobileImage: null,
        webImage: imageBytes,
        isWeb: true,
        error: null,
        progress: 0.0,
        status: 'pending',
      );

      items.add(item);
      index++;
    }

    return items;
  }

  /// Process and upload batch with progress tracking
  static Future<void> processBatch({
    required List<BatchUploadItem> items,
    required Function(BatchUploadItem) onItemUpdate,
    required Function() onBatchComplete,
    required Function(String) onBatchError,
    bool enhanceImages = true,
    bool autoRotate = true,
    bool reduceNoise = true,
  }) async {
    if (items.isEmpty) {
      onBatchError('No files selected for upload');
      return;
    }

    if (items.length > MAX_BATCH_SIZE) {
      onBatchError('Maximum $MAX_BATCH_SIZE files allowed per batch');
      return;
    }

    final queue = List<BatchUploadItem>.from(items);
    final inProgress = <BatchUploadItem>[];
    final completed = <BatchUploadItem>[];
    final failed = <BatchUploadItem>[];

    try {
      // Process in batches to avoid overwhelming the system
      while (queue.isNotEmpty || inProgress.isNotEmpty) {
        // Start new uploads if we have capacity
        while (inProgress.length < CONCURRENT_UPLOADS && queue.isNotEmpty) {
          final item = queue.removeAt(0);
          inProgress.add(item);

          _processSingleItem(
                item: item,
                enhanceImages: enhanceImages,
                autoRotate: autoRotate,
                reduceNoise: reduceNoise,
                onUpdate: onItemUpdate,
              )
              .then((_) {
                inProgress.remove(item);
                completed.add(item);
                onItemUpdate(item);
              })
              .catchError((error) {
                inProgress.remove(item);
                failed.add(item);
                item.error = error.toString();
                item.status = 'failed';
                onItemUpdate(item);
              });
        }

        // Wait a bit before checking again
        await Future.delayed(const Duration(milliseconds: 100));
      }

      if (failed.isNotEmpty) {
        onBatchError('${failed.length} files failed to upload');
      } else {
        onBatchComplete();
      }
    } catch (e) {
      onBatchError('Batch processing failed: $e');
    }
  }

  /// Process a single file with image optimization and upload
  static Future<void> _processSingleItem({
    required BatchUploadItem item,
    required bool enhanceImages,
    required bool autoRotate,
    required bool reduceNoise,
    required Function(BatchUploadItem) onUpdate,
  }) async {
    try {
      item.status = 'processing';
      onUpdate(item);

      // Step 1: Process image if enhancement is enabled
      if (enhanceImages) {
        item.progress = 0.2;
        onUpdate(item);

        if (item.isWeb && item.webImage != null) {
          // Process web image
          final result = await AdvancedImageProcessor.processWebImage(
            imageBytes: item.webImage!,
            enhanceQuality: enhanceImages,
            autoRotate: autoRotate,
            reduceNoise: reduceNoise,
            onProgress: (progress) {
              item.progress = 0.2 + (progress * 0.6); // 20% to 80%
              onUpdate(item);
            },
          );

          if (result.hasError) {
            throw Exception(result.errorMessage ?? 'Image processing failed');
          }
        } else if (!item.isWeb && item.mobileImage != null) {
          // Process mobile image
          final result = await AdvancedImageProcessor.processImage(
            imageFile: item.mobileImage!,
            enhanceQuality: enhanceImages,
            autoRotate: autoRotate,
            reduceNoise: reduceNoise,
            onProgress: (progress) {
              item.progress = 0.2 + (progress * 0.6); // 20% to 80%
              onUpdate(item);
            },
          );

          if (result.hasError) {
            throw Exception(result.errorMessage ?? 'Image processing failed');
          }
        }
      }

      // Step 2: Upload to Firebase
      item.progress = 0.8;
      onUpdate(item);

      await _uploadItem(item);

      item.progress = 1.0;
      item.status = 'completed';
      onUpdate(item);
    } catch (e) {
      item.status = 'failed';
      item.error = e.toString();
      item.progress = 0.0;
      onUpdate(item);
      rethrow;
    }
  }

  /// Upload single item to Firebase
  static Future<void> _uploadItem(BatchUploadItem item) async {
    // This would integrate with your existing ExamRepository
    // For now, we'll simulate the upload process

    // Simulate upload delay
    await Future.delayed(
      Duration(milliseconds: 500 + (item.progress * 1000).toInt()),
    );

    // Here you would use your existing ExamRepository.uploadScanWithProgress
    // Example:
    // await _repository.uploadScanWithProgress(
    //   studentName: item.studentName,
    //   isWeb: item.isWeb,
    //   webImage: item.webImage,
    //   mobileImage: item.mobileImage,
    //   onProgress: (progress) {
    //     item.progress = 0.8 + (progress * 0.2); // 80% to 100%
    //   },
    // );
  }

  /// Retry failed uploads
  static Future<void> retryFailedUploads({
    required List<BatchUploadItem> failedItems,
    required Function(BatchUploadItem) onItemUpdate,
    required Function() onRetryComplete,
    required Function(String) onRetryError,
    bool enhanceImages = true,
    bool autoRotate = true,
    bool reduceNoise = true,
  }) async {
    if (failedItems.isEmpty) {
      onRetryComplete();
      return;
    }

    final pendingItems = failedItems
        .map(
          (item) =>
              item.copyWith(status: 'pending', error: null, progress: 0.0),
        )
        .toList();

    await processBatch(
      items: pendingItems,
      onItemUpdate: onItemUpdate,
      onBatchComplete: onRetryComplete,
      onBatchError: onRetryError,
      enhanceImages: enhanceImages,
      autoRotate: autoRotate,
      reduceNoise: reduceNoise,
    );
  }

  /// Cancel ongoing batch processing
  static void cancelBatchProcessing() {
    // Implementation would maintain a list of ongoing tasks
    // and cancel them when needed
  }

  /// Get batch statistics
  static BatchStatistics getBatchStatistics(List<BatchUploadItem> items) {
    final total = items.length;
    final completed = items.where((item) => item.status == 'completed').length;
    final failed = items.where((item) => item.status == 'failed').length;
    final processing = items
        .where((item) => item.status == 'processing')
        .length;
    final pending = items.where((item) => item.status == 'pending').length;

    return BatchStatistics(
      totalItems: total,
      completedItems: completed,
      failedItems: failed,
      processingItems: processing,
      pendingItems: pending,
      successRate: total > 0 ? (completed / total * 100) : 0.0,
    );
  }

  /// Validate batch before processing
  static List<String> validateBatch(List<BatchUploadItem> items) {
    final errors = <String>[];

    if (items.isEmpty) {
      errors.add('No files selected');
      return errors;
    }

    if (items.length > MAX_BATCH_SIZE) {
      errors.add('Maximum $MAX_BATCH_SIZE files allowed per batch');
    }

    for (var item in items) {
      if (item.studentName.trim().isEmpty) {
        errors.add('Student name is required for all items');
        break;
      }

      if (item.isWeb && item.webImage == null) {
        errors.add('Web image data is missing for ${item.studentName}');
        break;
      }

      if (!item.isWeb && item.mobileImage == null) {
        errors.add('Mobile image file is missing for ${item.studentName}');
        break;
      }
    }

    return errors;
  }

  /// Extract student name from file name
  static String _extractStudentNameFromFileName(String fileName) {
    // Remove file extension
    final nameWithoutExtension = fileName.split('.').first;

    // Try to extract student name patterns
    // Examples: "john_doe_123", "Jane Smith - Math Exam", etc.

    // Pattern 1: Name followed by numbers
    final nameNumberPattern = RegExp(r'^([a-zA-Z\s]+)_\d+$');
    final match1 = nameNumberPattern.firstMatch(nameWithoutExtension);
    if (match1 != null) {
      return match1.group(1)!.replaceAll('_', ' ').trim();
    }

    // Pattern 2: Name followed by dash and description
    final nameDashPattern = RegExp(r'^([a-zA-Z\s]+)\s*-\s*.+$');
    final match2 = nameDashPattern.firstMatch(nameWithoutExtension);
    if (match2 != null) {
      return match2.group(1)!.trim();
    }

    // Pattern 3: Replace underscores and return as is
    return nameWithoutExtension.replaceAll('_', ' ').trim();
  }
}

class BatchStatistics {
  final int totalItems;
  final int completedItems;
  final int failedItems;
  final int processingItems;
  final int pendingItems;
  final double successRate;

  BatchStatistics({
    required this.totalItems,
    required this.completedItems,
    required this.failedItems,
    required this.processingItems,
    required this.pendingItems,
    required this.successRate,
  });

  bool get isComplete => completedItems + failedItems == totalItems;
  bool get hasFailures => failedItems > 0;
  bool get isProcessing => processingItems > 0;

  String get statusText {
    if (isComplete) {
      if (hasFailures) {
        return 'Completed with $failedItems failures';
      } else {
        return 'All $totalItems items uploaded successfully';
      }
    } else if (isProcessing) {
      return 'Processing $processingItems items...';
    } else {
      return 'Ready to upload $pendingItems items';
    }
  }
}
