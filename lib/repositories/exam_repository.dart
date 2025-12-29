import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/app_constants.dart';
import '../models/exam_submission.dart';
import '../services/image_optimization_service.dart';

class ExamRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Enhanced stream with pagination
  Stream<List<ExamSubmission>> getScansStream({
    int limit = AppConstants.scansPerPage,
  }) {
    return _firestore
        .collection(AppConstants.examScansCollection)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map(_mapSnapshotToSubmissions);
  }

  // Paginated query for large datasets
  Future<List<ExamSubmission>> getScansPaginated({
    DocumentSnapshot? lastDocument,
    int limit = AppConstants.scansPerPage,
  }) async {
    Query query = _firestore
        .collection(AppConstants.examScansCollection)
        .orderBy('timestamp', descending: true)
        .limit(limit);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    final snapshot = await query.get();
    return _mapSnapshotToSubmissions(snapshot);
  }

  // Single image upload with progress tracking
  Future<void> uploadScanWithProgress({
    required String studentName,
    required bool isWeb,
    Uint8List? webImage,
    File? mobileImage,
    Function(double)? onProgress,
  }) async {
    try {
      // Validate inputs
      if (studentName.trim().isEmpty) {
        throw Exception('Student name is required');
      }

      if ((isWeb && webImage == null) || (!isWeb && mobileImage == null)) {
        throw Exception('Image is required');
      }

      // Optimize image
      String fileName;
      Uint8List? optimizedImage;
      File? optimizedFile;

      if (isWeb) {
        final validation = await ImageOptimizationService.validateWebImage(
          webImage!,
        );
        if (!validation['isValid']) {
          throw Exception(validation['errorMessage']);
        }

        optimizedImage = await ImageOptimizationService.optimizeWebImage(
          webImage,
        );
        fileName = await ImageOptimizationService.getOptimizedFileName(
          studentName,
          true,
        );
      } else {
        final validation = await ImageOptimizationService.validateImageFile(
          mobileImage!,
        );
        if (!validation['isValid']) {
          throw Exception(validation['errorMessage']);
        }

        optimizedFile = await ImageOptimizationService.optimizeImageFile(
          mobileImage,
        );
        fileName = await ImageOptimizationService.getOptimizedFileName(
          studentName,
          false,
        );
      }

      // Upload to Firebase Storage
      String downloadUrl = await _uploadImage(
        fileName: fileName,
        isWeb: isWeb,
        webImage: optimizedImage,
        mobileImage: optimizedFile,
        onProgress: onProgress,
      );

      // Save metadata to Firestore
      await _firestore.collection(AppConstants.examScansCollection).add({
        'student_name': studentName.trim(),
        'image_url': downloadUrl,
        'status': 'processing',
        'result_score': null,
        'timestamp': FieldValue.serverTimestamp(),
        'file_name': fileName,
        'file_size': isWeb
            ? optimizedImage!.lengthInBytes
            : optimizedFile!.lengthSync(),
        'metadata': {
          'uploaded_at': FieldValue.serverTimestamp(),
          'app_version': '1.0.0',
          'platform': kIsWeb ? 'web' : Platform.operatingSystem,
        },
      });
    } catch (e) {
      print('Upload failed: $e');
      rethrow;
    }
  }

  // Enhanced batch upload with progress tracking
  Future<List<String>> uploadBatchScans({
    required List<BatchUploadItem> items,
    Function(double overallProgress)? onOverallProgress,
    Function(String itemId, double progress)? onItemProgress,
  }) async {
    if (items.length > AppConstants.batchUploadLimit) {
      throw Exception(AppErrors.batchUploadLimitExceeded);
    }

    final uploadUrls = <String>[];
    int completed = 0;
    int total = items.length;

    for (final item in items) {
      try {
        // Update item status to uploading
        // In a real app, you'd update this through a state management system

        // Optimize and upload image
        Uint8List? optimizedWebImage;
        File? optimizedMobileImage;

        if (item.isWeb && item.webImage != null) {
          optimizedWebImage = await ImageOptimizationService.optimizeWebImage(
            item.webImage!,
          );
        } else if (!item.isWeb && item.mobileImage != null) {
          optimizedMobileImage =
              await ImageOptimizationService.optimizeImageFile(
                item.mobileImage!,
              );
        }

        final fileName = await ImageOptimizationService.getOptimizedFileName(
          item.studentName,
          item.isWeb,
        );

        String downloadUrl = await _uploadImage(
          fileName: fileName,
          isWeb: item.isWeb,
          webImage: optimizedWebImage,
          mobileImage: optimizedMobileImage,
          onProgress: (progress) => onItemProgress?.call(item.id, progress),
        );

        // Save to Firestore
        await _firestore.collection(AppConstants.examScansCollection).add({
          'student_name': item.studentName.trim(),
          'image_url': downloadUrl,
          'status': 'processing',
          'result_score': null,
          'timestamp': FieldValue.serverTimestamp(),
          'file_name': fileName,
          'file_size': item.isWeb
              ? optimizedWebImage!.lengthInBytes
              : optimizedMobileImage!.lengthSync(),
          'metadata': {
            'uploaded_at': FieldValue.serverTimestamp(),
            'batch_upload': true,
            'app_version': '1.0.0',
            'platform': kIsWeb ? 'web' : Platform.operatingSystem,
          },
        });

        uploadUrls.add(downloadUrl);
        completed++;

        // Report overall progress
        final overallProgress = completed / total;
        onOverallProgress?.call(overallProgress);
      } catch (e) {
        print('Batch upload item failed (${item.id}): $e');
        // Continue with other items even if one fails
        uploadUrls.add(''); // Empty string for failed upload
      }
    }

    return uploadUrls;
  }

  // Get submissions by student name for analytics
  Future<List<ExamSubmission>> getSubmissionsByStudent(
    String studentName,
  ) async {
    final snapshot = await _firestore
        .collection(AppConstants.examScansCollection)
        .where('student_name', isEqualTo: studentName)
        .orderBy('timestamp', descending: true)
        .get();

    return _mapSnapshotToSubmissions(snapshot);
  }

  // Get submissions within date range
  Future<List<ExamSubmission>> getSubmissionsInDateRange({
    required DateTime startDate,
    required DateTime endDate,
    String? studentName,
  }) async {
    Query query = _firestore
        .collection(AppConstants.examScansCollection)
        .where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        )
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('timestamp', descending: true);

    if (studentName != null && studentName.isNotEmpty) {
      query = query.where('student_name', isEqualTo: studentName);
    }

    final snapshot = await query.get();
    return _mapSnapshotToSubmissions(snapshot);
  }

  // Update submission status (for processing completion)
  Future<void> updateSubmissionStatus(
    String submissionId, {
    required String status,
    dynamic resultScore,
    String? errorMessage,
  }) async {
    final updateData = {
      'status': status,
      'result_score': resultScore,
      if (errorMessage != null) 'error_message': errorMessage,
    };

    await _firestore
        .collection(AppConstants.examScansCollection)
        .doc(submissionId)
        .update(updateData);
  }

  // Delete submission
  Future<void> deleteSubmission(String submissionId) async {
    // First, get the submission to find the image URL
    final doc = await _firestore
        .collection(AppConstants.examScansCollection)
        .doc(submissionId)
        .get();

    if (doc.exists) {
      final data = doc.data();
      if (data != null && data['image_url'] != null) {
        // Delete image from storage
        try {
          final imageUrl = data['image_url'] as String;
          final uri = Uri.parse(imageUrl);
          final path = 'scans/${uri.pathSegments.last}';
          await _storage.ref().child(path).delete();
        } catch (e) {
          print('Failed to delete image from storage: $e');
        }
      }

      // Delete document from Firestore
      await _firestore
          .collection(AppConstants.examScansCollection)
          .doc(submissionId)
          .delete();
    }
  }

  // Private helper methods
  Future<String> _uploadImage({
    required String fileName,
    required bool isWeb,
    Uint8List? webImage,
    File? mobileImage,
    Function(double)? onProgress,
  }) async {
    final storageRef = _storage.ref().child('scans/$fileName');

    UploadTask uploadTask;
    if (isWeb && webImage != null) {
      uploadTask = storageRef.putData(webImage);
    } else if (!isWeb && mobileImage != null) {
      uploadTask = storageRef.putFile(mobileImage);
    } else {
      throw Exception('No image provided');
    }

    // Track upload progress
    uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
      if (onProgress != null && snapshot.totalBytes != null) {
        double progress = snapshot.bytesTransferred / snapshot.totalBytes!;
        onProgress(progress);
      }
    });

    // Wait for upload to complete
    await uploadTask.whenComplete(() => null);

    return await storageRef.getDownloadURL();
  }

  List<ExamSubmission> _mapSnapshotToSubmissions(QuerySnapshot snapshot) {
    return snapshot.docs
        .map((doc) => ExamSubmission.fromSnapshot(doc))
        .toList();
  }
}
