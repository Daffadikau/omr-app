import 'dart:io';
import 'package:flutter/foundation.dart';

class BatchUploadItem {
  String id;
  String studentName;
  File? mobileImage;
  Uint8List? webImage;
  bool isWeb;
  String? error;
  double progress;
  String status;

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
  bool get isUploading => status == 'processing';
  bool get isPending => status == 'pending';

  double get fileSize {
    if (isWeb && webImage != null) {
      return webImage!.lengthInBytes / (1024 * 1024); // MB
    } else if (!isWeb && mobileImage != null) {
      return mobileImage!.lengthSync() / (1024 * 1024); // MB
    }
    return 0.0;
  }

  String get displaySize => '${fileSize.toStringAsFixed(2)} MB';

  String get displayName {
    if (isWeb && webImage != null) {
      return 'Web Image $id';
    } else if (!isWeb && mobileImage != null) {
      return mobileImage!.path.split('/').last;
    }
    return 'Unknown';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'studentName': studentName,
      'isWeb': isWeb,
      'error': error,
      'progress': progress,
      'status': status,
      'fileSize': fileSize,
    };
  }

  factory BatchUploadItem.fromJson(Map<String, dynamic> json) {
    return BatchUploadItem(
      id: json['id'],
      studentName: json['studentName'],
      isWeb: json['isWeb'],
      error: json['error'],
      progress: json['progress'].toDouble(),
      status: json['status'],
    );
  }
}
