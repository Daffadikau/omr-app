import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// Stub implementation for non-web platforms
// This file is used when the app is not running on web
class WebCameraCapture {
  static Future<XFile?> captureImage(BuildContext context) async {
    // This should never be called on non-web platforms
    throw UnsupportedError('WebCameraCapture is only supported on web platforms');
  }
}
