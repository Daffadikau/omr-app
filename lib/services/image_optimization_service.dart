import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import '../core/constants/app_constants.dart';
import '../models/exam_submission.dart';

class ImageOptimizationService {
  static Future<File> optimizeImageFile(File imageFile) async {
    try {
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);
      if (image == null) return imageFile;

      // Get original file size
      final originalSize = imageBytes.lengthInBytes;

      // Resize if too large
      if (image.width > AppConstants.maxImageWidth ||
          image.height > AppConstants.maxImageHeight) {
        img.Image resized = img.copyResize(
          image,
          width: AppConstants.maxImageWidth,
          height: AppConstants.maxImageHeight,
          interpolation: img.Interpolation.linear,
        );

        final optimizedBytes = Uint8List.fromList(
          img.encodeJpg(resized, quality: AppConstants.imageQuality),
        );

        // Write optimized file
        final optimizedFile = File(imageFile.path);
        await optimizedFile.writeAsBytes(optimizedBytes);

        return optimizedFile;
      }

      // If image is already within size limits, still compress it
      final optimizedBytes = Uint8List.fromList(
        img.encodeJpg(image, quality: AppConstants.imageQuality),
      );
      final optimizedFile = File(imageFile.path);
      await optimizedFile.writeAsBytes(optimizedBytes);

      return optimizedFile;
    } catch (e) {
      print('Image optimization failed: $e');
      return imageFile; // Return original if optimization fails
    }
  }

  static Future<Uint8List> optimizeWebImage(Uint8List imageBytes) async {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) return imageBytes;

      // Resize if too large
      if (image.width > AppConstants.maxImageWidth ||
          image.height > AppConstants.maxImageHeight) {
        img.Image resized = img.copyResize(
          image,
          width: AppConstants.maxImageWidth,
          height: AppConstants.maxImageHeight,
          interpolation: img.Interpolation.linear,
        );
        return Uint8List.fromList(
          img.encodeJpg(resized, quality: AppConstants.imageQuality),
        );
      }

      return Uint8List.fromList(
        img.encodeJpg(image, quality: AppConstants.imageQuality),
      );
    } catch (e) {
      print('Web image optimization failed: $e');
      return imageBytes; // Return original if optimization fails
    }
  }

  static Future<Map<String, dynamic>> validateImageFile(File file) async {
    final stats = await file.stat();
    final sizeInMB = stats.size / (1024 * 1024);

    return {
      'isValid': sizeInMB <= AppConstants.maxFileSizeMB,
      'sizeMB': sizeInMB,
      'errorMessage': sizeInMB > AppConstants.maxFileSizeMB
          ? 'Image size (${sizeInMB.toStringAsFixed(1)}MB) exceeds maximum allowed size (${AppConstants.maxFileSizeMB}MB)'
          : null,
    };
  }

  static Future<Map<String, dynamic>> validateWebImage(
    Uint8List imageBytes,
  ) async {
    final sizeInMB = imageBytes.lengthInBytes / (1024 * 1024);

    return {
      'isValid': sizeInMB <= AppConstants.maxFileSizeMB,
      'sizeMB': sizeInMB,
      'errorMessage': sizeInMB > AppConstants.maxFileSizeMB
          ? 'Image size (${sizeInMB.toStringAsFixed(1)}MB) exceeds maximum allowed size (${AppConstants.maxFileSizeMB}MB)'
          : null,
    };
  }

  static Future<bool> checkPermissions() async {
    // Check camera permission
    final cameraStatus = await Permission.camera.status;
    if (!cameraStatus.isGranted) {
      final cameraRequest = await Permission.camera.request();
      if (!cameraRequest.isGranted) return false;
    }

    // Check storage permission for Android
    if (!kIsWeb && Platform.isAndroid) {
      final storageStatus = await Permission.storage.status;
      if (!storageStatus.isGranted) {
        final storageRequest = await Permission.storage.request();
        if (!storageRequest.isGranted) return false;
      }
    }

    return true;
  }

  static Future<String> getOptimizedFileName(
    String originalName,
    bool isWeb,
  ) async {
    final extension = isWeb ? '.jpg' : '.jpg';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final sanitizedName = originalName.replaceAll(
      RegExp(r'[^a-zA-Z0-9_-]'),
      '_',
    );
    return 'scan_${timestamp}_$sanitizedName$extension';
  }
}
