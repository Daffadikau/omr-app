import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ScanService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload LJK scan ke Firebase
  /// Returns scanId untuk tracking status
  Future<String> uploadScan({
    required File imageFile,
    required String studentName,
    required String answerKeyId,
  }) async {
    try {
      // 1. Generate scan ID
      final scanDoc = _firestore.collection('exam_scans').doc();
      final scanId = scanDoc.id;

      // 2. Upload image ke Storage
      final ref = _storage.ref('scans/$scanId/original.jpg');
      final uploadTask = ref.putFile(imageFile);
      
      // Track progress (optional)
      uploadTask.snapshotEvents.listen((snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        print('Upload progress: ${(progress * 100).toStringAsFixed(0)}%');
      });

      await uploadTask;
      final imageUrl = await ref.getDownloadURL();

      // 3. Buat dokumen Firestore dengan status "processing"
      await scanDoc.set({
        'student_name': studentName,
        'image_url': imageUrl,
        'answer_key_id': answerKeyId,
        'status': 'processing',
        'submitted_at': FieldValue.serverTimestamp(),
        'results': null,
        'score': null,
        'processed_at': null,
      });

      return scanId;
    } catch (e) {
      throw Exception('Failed to upload scan: $e');
    }
  }

  /// Get exam scan by ID
  Stream<DocumentSnapshot> getScanStream(String scanId) {
    return _firestore.collection('exam_scans').doc(scanId).snapshots();
  }

  /// Get all scans
  Stream<QuerySnapshot> getAllScans() {
    return _firestore
        .collection('exam_scans')
        .orderBy('submitted_at', descending: true)
        .snapshots();
  }

  /// Delete scan
  Future<void> deleteScan(String scanId) async {
    try {
      // Delete from Firestore
      await _firestore.collection('exam_scans').doc(scanId).delete();

      // Delete from Storage
      try {
        await _storage.ref('scans/$scanId/original.jpg').delete();
      } catch (e) {
        print('Failed to delete image from storage: $e');
      }
    } catch (e) {
      throw Exception('Failed to delete scan: $e');
    }
  }

  /// Calculate score by comparing results with answer key
  Future<int> calculateScore(String scanId, String answerKeyId) async {
    try {
      final scanDoc = await _firestore.collection('exam_scans').doc(scanId).get();
      final keyDoc = await _firestore.collection('answer_keys').doc(answerKeyId).get();

      if (!scanDoc.exists || !keyDoc.exists) {
        throw Exception('Scan or answer key not found');
      }

      final results = scanDoc.data()?['results'] as Map<String, dynamic>?;
      final correctAnswers = keyDoc.data()?['answers'] as Map<String, dynamic>?;

      if (results == null || correctAnswers == null) {
        return 0;
      }

      int correct = 0;
      for (int i = 1; i <= 100; i++) {
        final userAnswer = results[i.toString()];
        final correctAnswer = correctAnswers[i.toString()];
        if (userAnswer != null && userAnswer == correctAnswer) {
          correct++;
        }
      }

      return correct;
    } catch (e) {
      throw Exception('Failed to calculate score: $e');
    }
  }
}
