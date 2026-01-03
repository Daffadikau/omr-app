import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../models/image_processing_result.dart';

class AdvancedImageProcessor {
  static const int MAX_IMAGE_SIZE = 1920;
  static const int MIN_IMAGE_SIZE = 200;
  static const double QUALITY_THRESHOLD = 0.7;
  static const List<String> SUPPORTED_FORMATS = ['JPEG', 'JPG', 'PNG', 'WEBP'];

  /// Process image with advanced preprocessing techniques
  static Future<ImageProcessingResult> processImage({
    required File imageFile,
    bool enhanceQuality = true,
    bool autoRotate = true,
    bool reduceNoise = true,
    Function(double)? onProgress,
  }) async {
    try {
      onProgress?.call(0.1);

      // Read image bytes
      final imageBytes = await imageFile.readAsBytes();
      onProgress?.call(0.2);

      // Decode image
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        throw Exception('Failed to decode image');
      }
      onProgress?.call(0.3);

      // Auto-rotate if enabled
      img.Image processedImage = image;
      if (autoRotate) {
        processedImage = _autoRotateImage(processedImage);
      }
      onProgress?.call(0.5);

      // Noise reduction
      if (reduceNoise) {
        processedImage = _reduceNoise(processedImage);
      }
      onProgress?.call(0.6);

      // Quality enhancement
      if (enhanceQuality) {
        processedImage = _enhanceQuality(processedImage);
      }
      onProgress?.call(0.8);

      // Resize if necessary
      processedImage = _resizeIfNeeded(processedImage);
      onProgress?.call(0.9);

      // Calculate metrics
      final metrics = _calculateImageMetrics(processedImage);
      onProgress?.call(1.0);

      return ImageProcessingResult(
        processedImage: processedImage,
        originalSize: imageBytes.length,
        processedSize: imageBytes.length,
        qualityScore: metrics['quality'] ?? 0.0,
        brightness: metrics['brightness'] ?? 0.0,
        contrast: metrics['contrast'] ?? 0.0,
        sharpness: metrics['sharpness'] ?? 0.0,
        processingTime: DateTime.now(),
      );
    } catch (e) {
      throw Exception('Image processing failed: $e');
    }
  }

  /// Process web image bytes with advanced preprocessing
  static Future<ImageProcessingResult> processWebImage({
    required Uint8List imageBytes,
    bool enhanceQuality = true,
    bool autoRotate = true,
    bool reduceNoise = true,
    Function(double)? onProgress,
  }) async {
    try {
      onProgress?.call(0.1);

      // Decode image
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        throw Exception('Failed to decode image');
      }
      onProgress?.call(0.3);

      // Auto-rotate if enabled
      img.Image processedImage = image;
      if (autoRotate) {
        processedImage = _autoRotateImage(processedImage);
      }
      onProgress?.call(0.5);

      // Noise reduction
      if (reduceNoise) {
        processedImage = _reduceNoise(processedImage);
      }
      onProgress?.call(0.6);

      // Quality enhancement
      if (enhanceQuality) {
        processedImage = _enhanceQuality(processedImage);
      }
      onProgress?.call(0.8);

      // Resize if necessary
      processedImage = _resizeIfNeeded(processedImage);
      onProgress?.call(0.9);

      // Calculate metrics
      final metrics = _calculateImageMetrics(processedImage);
      onProgress?.call(1.0);

      return ImageProcessingResult(
        processedImage: processedImage,
        originalSize: imageBytes.length,
        processedSize: imageBytes.length,
        qualityScore: metrics['quality'] ?? 0.0,
        brightness: metrics['brightness'] ?? 0.0,
        contrast: metrics['contrast'] ?? 0.0,
        sharpness: metrics['sharpness'] ?? 0.0,
        processingTime: DateTime.now(),
      );
    } catch (e) {
      throw Exception('Image processing failed: $e');
    }
  }

  /// Auto-rotate image based on content analysis
  static img.Image _autoRotateImage(img.Image image) {
    // Simple auto-rotation based on image dimensions
    // In a full implementation, this would analyze the content
    return image;
  }

  /// Reduce noise in the image using simple averaging filter
  static img.Image _reduceNoise(img.Image image) {
    final width = image.width;
    final height = image.height;
    final noiseReduced = img.Image(width: width, height: height);

    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        int r = 0, g = 0, b = 0;

        // 3x3 averaging filter
        for (int dy = -1; dy <= 1; dy++) {
          for (int dx = -1; dx <= 1; dx++) {
            final pixel = image.getPixel(x + dx, y + dy);
            final rgba = pixel.r.toInt();
            final green = pixel.g.toInt();
            final blue = pixel.b.toInt();
            r += rgba;
            g += green;
            b += blue;
          }
        }

        r = (r / 9).round();
        g = (g / 9).round();
        b = (b / 9).round();

        noiseReduced.setPixel(x, y, img.ColorRgb8(r, g, b));
      }
    }

    return noiseReduced;
  }

  /// Enhance image quality using contrast and brightness adjustments
  static img.Image _enhanceQuality(img.Image image) {
    // Apply basic contrast and brightness enhancement
    final contrast = 1.2; // Increase contrast by 20%
    final brightness = 10; // Increase brightness by 10
    final enhanced = img.Image(width: image.width, height: image.height);

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();

        // Apply contrast and brightness
        final newR = ((r - 128) * contrast + 128 + brightness)
            .clamp(0, 255)
            .toInt();
        final newG = ((g - 128) * contrast + 128 + brightness)
            .clamp(0, 255)
            .toInt();
        final newB = ((b - 128) * contrast + 128 + brightness)
            .clamp(0, 255)
            .toInt();

        enhanced.setPixel(x, y, img.ColorRgb8(newR, newG, newB));
      }
    }

    return enhanced;
  }

  /// Resize image if it exceeds maximum dimensions
  static img.Image _resizeIfNeeded(img.Image image) {
    if (image.width <= MAX_IMAGE_SIZE && image.height <= MAX_IMAGE_SIZE) {
      return image;
    }

    final ratio = image.width / image.height;
    int newWidth, newHeight;

    if (image.width > image.height) {
      newWidth = MAX_IMAGE_SIZE;
      newHeight = (MAX_IMAGE_SIZE / ratio).round();
    } else {
      newHeight = MAX_IMAGE_SIZE;
      newWidth = (MAX_IMAGE_SIZE * ratio).round();
    }

    return img.copyResize(
      image,
      width: newWidth,
      height: newHeight,
      interpolation: img.Interpolation.linear,
    );
  }

  /// Calculate image quality metrics
  static Map<String, double> _calculateImageMetrics(img.Image image) {
    double totalBrightness = 0;
    double totalContrast = 0;
    double totalSharpness = 0;
    final pixelCount = image.width * image.height;

    // Calculate brightness (average of all pixel values)
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r;
        final g = pixel.g;
        final b = pixel.b;
        final gray = (r + g + b) / 3;
        totalBrightness += gray;
      }
    }
    final brightness = totalBrightness / pixelCount / 255.0;

    // Calculate contrast (variance of pixel values)
    double variance = 0;
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r;
        final g = pixel.g;
        final b = pixel.b;
        final gray = (r + g + b) / 3;
        variance += (gray - totalBrightness / pixelCount).abs();
      }
    }
    final contrast = variance / pixelCount / 255.0;

    // Simple sharpness measure using edge detection
    for (int y = 1; y < image.height - 1; y++) {
      for (int x = 1; x < image.width - 1; x++) {
        final current = image.getPixel(x, y);
        final right = image.getPixel(x + 1, y);
        final below = image.getPixel(x, y + 1);

        final currentGray = (current.r + current.g + current.b) / 3;
        final rightGray = (right.r + right.g + right.b) / 3;
        final belowGray = (below.r + below.g + below.b) / 3;

        totalSharpness +=
            ((currentGray - rightGray).abs() + (currentGray - belowGray).abs());
      }
    }
    final sharpness = (totalSharpness / (pixelCount * 2)) / 255.0;

    // Overall quality score (weighted average)
    final quality = (brightness * 0.3 + contrast * 0.4 + sharpness * 0.3);

    return {
      'brightness': brightness,
      'contrast': contrast,
      'sharpness': sharpness,
      'quality': quality.clamp(0.0, 1.0),
    };
  }

  /// Detect OMR sheet quality and suitability for processing
  static Future<OMRSheetQuality> detectSheetQuality(File imageFile) async {
    try {
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);

      if (image == null) {
        return OMRSheetQuality.poor;
      }

      final metrics = _calculateImageMetrics(image);
      final quality = metrics['quality'] ?? 0.0;
      final brightness = metrics['brightness'] ?? 0.0;
      final contrast = metrics['contrast'] ?? 0.0;

      // Quality assessment logic
      if (quality > 0.8 &&
          brightness > 0.4 &&
          brightness < 0.8 &&
          contrast > 0.2) {
        return OMRSheetQuality.excellent;
      } else if (quality > 0.6 &&
          brightness > 0.3 &&
          brightness < 0.9 &&
          contrast > 0.1) {
        return OMRSheetQuality.good;
      } else if (quality > 0.4) {
        return OMRSheetQuality.fair;
      } else {
        return OMRSheetQuality.poor;
      }
    } catch (e) {
      return OMRSheetQuality.poor;
    }
  }

  /// Get recommended processing settings based on image quality
  static ProcessingSettings getRecommendedSettings(OMRSheetQuality quality) {
    switch (quality) {
      case OMRSheetQuality.excellent:
        return ProcessingSettings(
          enhanceQuality: true,
          autoRotate: true,
          reduceNoise: false,
          targetQuality: 85,
          resizeLarge: true,
        );
      case OMRSheetQuality.good:
        return ProcessingSettings(
          enhanceQuality: true,
          autoRotate: true,
          reduceNoise: true,
          targetQuality: 80,
          resizeLarge: true,
        );
      case OMRSheetQuality.fair:
        return ProcessingSettings(
          enhanceQuality: true,
          autoRotate: true,
          reduceNoise: true,
          targetQuality: 75,
          resizeLarge: true,
        );
      case OMRSheetQuality.poor:
        return ProcessingSettings(
          enhanceQuality: true,
          autoRotate: true,
          reduceNoise: true,
          targetQuality: 70,
          resizeLarge: false,
        );
    }
  }
}

enum OMRSheetQuality { excellent, good, fair, poor }

class ProcessingSettings {
  final bool enhanceQuality;
  final bool autoRotate;
  final bool reduceNoise;
  final int targetQuality;
  final bool resizeLarge;

  ProcessingSettings({
    required this.enhanceQuality,
    required this.autoRotate,
    required this.reduceNoise,
    required this.targetQuality,
    required this.resizeLarge,
  });
}
