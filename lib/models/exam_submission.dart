import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/app_constants.dart';

class ExamSubmission {
  final String id;
  final String studentName;
  final String imageUrl;
  final String status;
  final dynamic resultScore;
  final DateTime? timestamp;
  final String? fileName;
  final int? fileSize;
  final String? errorMessage;
  final Map<String, dynamic>? metadata;
  final String? subject;

  ExamSubmission({
    required this.id,
    required this.studentName,
    required this.imageUrl,
    required this.status,
    this.resultScore,
    this.timestamp,
    this.fileName,
    this.fileSize,
    this.errorMessage,
    this.metadata,
    this.subject,
  });

  factory ExamSubmission.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ExamSubmission(
      id: doc.id,
      studentName: data['student_name'] ?? 'Unknown',
      imageUrl: data['image_url'] ?? '',
      status: data['status'] ?? 'pending',
      resultScore: data['result_score'],
      timestamp: data['timestamp'] != null
          ? (data['timestamp'] as Timestamp).toDate()
          : null,
      fileName: data['file_name'],
      fileSize: data['file_size'],
      errorMessage: data['error_message'],
      metadata: data['metadata'],
      subject: data['subject'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'student_name': studentName,
      'image_url': imageUrl,
      'status': status,
      'result_score': resultScore,
      'timestamp': timestamp != null ? Timestamp.fromDate(timestamp!) : null,
      'file_name': fileName,
      'file_size': fileSize,
      'error_message': errorMessage,
      'metadata': metadata,
      'subject': subject,
    };
  }

  factory ExamSubmission.fromMap(Map<String, dynamic> map) {
    return ExamSubmission(
      id: '', // ID should be set separately when creating from database
      studentName: map['student_name'] ?? 'Unknown',
      imageUrl: map['image_url'] ?? '',
      status: map['status'] ?? 'pending',
      resultScore: map['result_score'],
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] is Timestamp
                ? (map['timestamp'] as Timestamp).toDate()
                : (map['timestamp'] is String
                      ? DateTime.parse(map['timestamp'])
                      : null))
          : null,
      fileName: map['file_name'],
      fileSize: map['file_size'] != null
          ? (map['file_size'] is int
                ? map['file_size']
                : int.tryParse(map['file_size'].toString()))
          : null,
      errorMessage: map['error_message'],
      metadata: map['metadata'],
      subject: map['subject'],
    );
  }

  ExamSubmission copyWith({
    String? id,
    String? studentName,
    String? imageUrl,
    String? status,
    dynamic resultScore,
    DateTime? timestamp,
    String? fileName,
    int? fileSize,
    String? errorMessage,
    Map<String, dynamic>? metadata,
    String? subject,
  }) {
    return ExamSubmission(
      id: id ?? this.id,
      studentName: studentName ?? this.studentName,
      imageUrl: imageUrl ?? this.imageUrl,
      status: status ?? this.status,
      resultScore: resultScore ?? this.resultScore,
      timestamp: timestamp ?? this.timestamp,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      errorMessage: errorMessage ?? this.errorMessage,
      metadata: metadata ?? this.metadata,
      subject: subject ?? this.subject,
    );
  }

  bool get isCompleted => status == 'completed';
  bool get isProcessing => status == 'processing';
  bool get hasError => status == 'failed' && errorMessage != null;

  String get displayStatus {
    switch (status) {
      case 'completed':
        return 'Completed';
      case 'processing':
        return 'Processing';
      case 'failed':
        return 'Failed';
      default:
        return 'Pending';
    }
  }
}

class StudentAnalytics {
  final String studentName;
  final int totalScans;
  final int completedScans;
  final int failedScans;
  final double averageScore;
  final List<double> scoreHistory;
  final DateTime lastActivity;
  final Map<String, int> subjectPerformance;

  StudentAnalytics({
    required this.studentName,
    required this.totalScans,
    required this.completedScans,
    required this.failedScans,
    required this.averageScore,
    required this.scoreHistory,
    required this.lastActivity,
    required this.subjectPerformance,
  });

  factory StudentAnalytics.fromSubmissions(
    List<ExamSubmission> submissions,
    String studentName,
  ) {
    final studentSubmissions = submissions.where(
      (s) => s.studentName == studentName,
    );
    final completed = studentSubmissions.where((s) => s.isCompleted).toList();
    final scores = completed
        .where((s) => s.resultScore != null)
        .map((s) => (s.resultScore as num).toDouble())
        .toList();

    return StudentAnalytics(
      studentName: studentName,
      totalScans: studentSubmissions.length,
      completedScans: completed.length,
      failedScans: studentSubmissions.where((s) => s.status == 'failed').length,
      averageScore: scores.isNotEmpty
          ? scores.reduce((a, b) => a + b) / scores.length
          : 0.0,
      scoreHistory: scores,
      lastActivity: studentSubmissions.isNotEmpty
          ? studentSubmissions
                .map((s) => s.timestamp)
                .whereType<DateTime>()
                .reduce((a, b) => a.isAfter(b) ? a : b)
          : DateTime.now(),
      subjectPerformance: {}, // Would be populated based on exam metadata
    );
  }

  double get completionRate =>
      totalScans > 0 ? (completedScans / totalScans) * 100 : 0.0;
  bool get hasRecentActivity =>
      DateTime.now().difference(lastActivity).inDays < 7;
}

class ClassAnalytics {
  final String className;
  final int totalStudents;
  final int totalScans;
  final double classAverageScore;
  final Map<String, int> performanceDistribution;
  final List<String> topPerformers;
  final List<String> strugglingStudents;
  final Map<String, int> subjectAnalytics;

  ClassAnalytics({
    required this.className,
    required this.totalStudents,
    required this.totalScans,
    required this.classAverageScore,
    required this.performanceDistribution,
    required this.topPerformers,
    required this.strugglingStudents,
    required this.subjectAnalytics,
  });

  factory ClassAnalytics.fromSubmissions(
    List<ExamSubmission> submissions,
    String className,
  ) {
    final students = submissions.map((s) => s.studentName).toSet().toList();
    final studentAnalytics = students
        .map((name) => StudentAnalytics.fromSubmissions(submissions, name))
        .toList();

    final completedScores = submissions
        .where((s) => s.isCompleted && s.resultScore != null)
        .map((s) => (s.resultScore as num).toDouble())
        .toList();
    final classAvg = completedScores.isNotEmpty
        ? completedScores.reduce((a, b) => a + b) / completedScores.length
        : 0.0;

    final sortedByScore =
        studentAnalytics.where((a) => a.averageScore > 0).toList()
          ..sort((a, b) => b.averageScore.compareTo(a.averageScore));

    final topPerformers = sortedByScore
        .take(3)
        .map((a) => a.studentName)
        .toList();
    final struggling = sortedByScore
        .where((a) => a.averageScore < 60)
        .map((a) => a.studentName)
        .toList();

    return ClassAnalytics(
      className: className,
      totalStudents: students.length,
      totalScans: submissions.length,
      classAverageScore: classAvg,
      performanceDistribution: {
        'Excellent (90-100)': studentAnalytics
            .where((a) => a.averageScore >= 90)
            .length,
        'Good (80-89)': studentAnalytics
            .where((a) => a.averageScore >= 80 && a.averageScore < 90)
            .length,
        'Average (70-79)': studentAnalytics
            .where((a) => a.averageScore >= 70 && a.averageScore < 80)
            .length,
        'Below Average (60-69)': studentAnalytics
            .where((a) => a.averageScore >= 60 && a.averageScore < 70)
            .length,
        'Poor (<60)': studentAnalytics.where((a) => a.averageScore < 60).length,
      },
      topPerformers: topPerformers,
      strugglingStudents: struggling,
      subjectAnalytics: {}, // Would be populated based on exam subjects
    );
  }
}

class BatchUploadItem {
  final String id;
  final String studentName;
  final File? mobileImage;
  final Uint8List? webImage;
  final bool isWeb;
  final String? error;
  final double progress;
  final String status; // 'pending', 'uploading', 'completed', 'failed'

  BatchUploadItem({
    required this.id,
    required this.studentName,
    this.mobileImage,
    this.webImage,
    required this.isWeb,
    this.error,
    this.progress = 0.0,
    this.status = 'pending',
  });

  BatchUploadItem copyWith({
    String? id,
    String? studentName,
    File? mobileImage,
    Uint8List? webImage,
    bool? isWeb,
    String? error,
    double? progress,
    String? status,
  }) {
    return BatchUploadItem(
      id: id ?? this.id,
      studentName: studentName ?? this.studentName,
      mobileImage: mobileImage ?? this.mobileImage,
      webImage: webImage ?? this.webImage,
      isWeb: isWeb ?? this.isWeb,
      error: error ?? this.error,
      progress: progress ?? this.progress,
      status: status ?? this.status,
    );
  }

  bool get isCompleted => status == 'completed';
  bool get hasError => error != null;
  bool get isUploading => status == 'uploading';
}

class ExportRequest {
  final String id;
  final ExportFormat format;
  final List<String> studentIds;
  final DateTime dateRangeStart;
  final DateTime dateRangeEnd;
  final Map<String, dynamic> options;
  final DateTime createdAt;

  ExportRequest({
    required this.id,
    required this.format,
    required this.studentIds,
    required this.dateRangeStart,
    required this.dateRangeEnd,
    required this.options,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'format': format.name,
      'student_ids': studentIds,
      'date_range_start': Timestamp.fromDate(dateRangeStart),
      'date_range_end': Timestamp.fromDate(dateRangeEnd),
      'options': options,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }
}
