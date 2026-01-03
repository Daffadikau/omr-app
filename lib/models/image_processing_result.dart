import 'package:image/image.dart' as img;

class ImageProcessingResult {
  final img.Image processedImage;
  final int originalSize;
  final int processedSize;
  final double qualityScore;
  final double brightness;
  final double contrast;
  final double sharpness;
  final DateTime processingTime;
  final bool hasError;
  final String? errorMessage;

  ImageProcessingResult({
    required this.processedImage,
    required this.originalSize,
    required this.processedSize,
    required this.qualityScore,
    required this.brightness,
    required this.contrast,
    required this.sharpness,
    required this.processingTime,
    this.hasError = false,
    this.errorMessage,
  });

  ImageProcessingResult.error(this.errorMessage)
    : processedImage = img.Image(width: 0, height: 0),
      originalSize = 0,
      processedSize = 0,
      qualityScore = 0.0,
      brightness = 0.0,
      contrast = 0.0,
      sharpness = 0.0,
      processingTime = DateTime.now(),
      hasError = true;

  double get compressionRatio => processedSize / originalSize;
  bool get isHighQuality => qualityScore > 0.7;
  bool get isWellLit => brightness > 0.4 && brightness < 0.8;
  bool get hasGoodContrast => contrast > 0.2;
  bool get isSharp => sharpness > 0.3;

  Map<String, dynamic> toJson() {
    return {
      'originalSize': originalSize,
      'processedSize': processedSize,
      'qualityScore': qualityScore,
      'brightness': brightness,
      'contrast': contrast,
      'sharpness': sharpness,
      'processingTime': processingTime.toIso8601String(),
      'hasError': hasError,
      'errorMessage': errorMessage,
    };
  }

  factory ImageProcessingResult.fromJson(Map<String, dynamic> json) {
    return ImageProcessingResult(
      processedImage: img.Image(
        width: 0,
        height: 0,
      ), // Can't deserialize image easily
      originalSize: json['originalSize'],
      processedSize: json['processedSize'],
      qualityScore: json['qualityScore'],
      brightness: json['brightness'],
      contrast: json['contrast'],
      sharpness: json['sharpness'],
      processingTime: DateTime.parse(json['processingTime']),
      hasError: json['hasError'] ?? false,
      errorMessage: json['errorMessage'],
    );
  }
}
