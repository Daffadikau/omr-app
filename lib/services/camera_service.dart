import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/image_processing_result.dart';
import 'advanced_image_processor.dart';

class CameraService {
  static CameraService? _instance;
  static CameraService get instance => _instance ??= CameraService._();
  CameraService._();

  // Camera controller and cameras list
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  CameraDescription? _selectedCamera;

  // State variables
  bool _isInitialized = false;
  bool _isCapturing = false;
  String _flashMode = 'auto'; // 'off', 'auto', 'on'
  bool _gridEnabled = true;
  String _focusMode = 'auto'; // 'auto', 'locked'

  // Stream controllers for camera events
  final StreamController<String> _cameraStateController =
      StreamController.broadcast();
  final StreamController<double> _qualityController =
      StreamController.broadcast();

  // Getters
  Stream<String> get cameraStateStream => _cameraStateController.stream;
  Stream<double> get qualityStream => _qualityController.stream;

  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized;
  bool get isCapturing => _isCapturing;
  String get flashMode => _flashMode;
  bool get gridEnabled => _gridEnabled;
  String get focusMode => _focusMode;
  List<CameraDescription>? get cameras => _cameras;
  CameraDescription? get selectedCamera => _selectedCamera;

  /// Initialize camera service
  Future<bool> initialize() async {
    try {
      // Request camera permission
      final permission = await Permission.camera.request();
      if (permission != PermissionStatus.granted) {
        _cameraStateController.add('permission_denied');
        return false;
      }

      // Get available cameras
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        _cameraStateController.add('no_camera');
        return false;
      }

      // Select rear camera by default
      _selectedCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );

      // Initialize controller
      await _initializeController(_selectedCamera!);

      _cameraStateController.add('initialized');
      return true;
    } catch (e) {
      _cameraStateController.add('error');
      return false;
    }
  }

  /// Initialize camera controller
  Future<void> _initializeController(CameraDescription camera) async {
    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    await _controller!.initialize();
    _isInitialized = true;

    // Set up listeners
    _controller!.addListener(() {
      if (_controller!.value.hasError) {
        _cameraStateController.add('error');
      }
    });
  }

  /// Switch camera (front/back)
  Future<void> switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;

    final currentDirection = _selectedCamera?.lensDirection;
    _selectedCamera = _cameras!.firstWhere(
      (camera) => camera.lensDirection != currentDirection,
      orElse: () => _cameras!.first,
    );

    await _initializeController(_selectedCamera!);
  }

  /// Toggle flash mode
  Future<void> toggleFlashMode() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    switch (_flashMode) {
      case 'off':
        _flashMode = 'auto';
        break;
      case 'auto':
        _flashMode = 'on';
        break;
      case 'on':
        _flashMode = 'off';
        break;
    }

    _cameraStateController.add('flash_mode_changed');
  }

  /// Toggle focus mode
  Future<void> toggleFocusMode() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    switch (_focusMode) {
      case 'auto':
        _focusMode = 'locked';
        break;
      case 'locked':
        _focusMode = 'auto';
        break;
    }

    _cameraStateController.add('focus_mode_changed');
  }

  /// Set focus point
  Future<void> setFocusPoint(Offset point) async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      // Note: This requires camera controller support for focus points
      // Implementation depends on camera plugin version
      _cameraStateController.add('focus_point_set');
    } catch (e) {
      print('Focus point error: $e');
    }
  }

  /// Capture image with enhanced processing
  Future<ImageProcessingResult?> captureImage() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isCapturing) {
      return null;
    }

    _isCapturing = true;
    _cameraStateController.add('capturing');

    try {
      // Capture image
      final image = await _controller!.takePicture();

      // Read image bytes
      final bytes = await image.readAsBytes();

      // Process image with advanced processor
      final result = await AdvancedImageProcessor.processImage(
        imageFile: File(image.path),
      );

      _cameraStateController.add('captured');
      return result;
    } catch (e) {
      _cameraStateController.add('error');
      print('Capture error: $e');
      return null;
    } finally {
      _isCapturing = false;
    }
  }

  /// Capture image from bytes (for web or gallery)
  Future<ImageProcessingResult?> captureImageFromBytes(Uint8List bytes) async {
    if (_isCapturing) return null;

    _isCapturing = true;
    _cameraStateController.add('capturing');

    try {
      // Create temporary file from bytes
      final tempDir = await Directory.systemTemp.createTemp();
      final tempFile = File(
        '${tempDir.path}/temp_image_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await tempFile.writeAsBytes(bytes);

      // Process image with advanced processor
      final result = await AdvancedImageProcessor.processImage(
        imageFile: tempFile,
      );

      // Clean up temp file
      await tempFile.delete();

      _cameraStateController.add('captured');
      return result;
    } catch (e) {
      _cameraStateController.add('error');
      print('Capture error: $e');
      return null;
    } finally {
      _isCapturing = false;
    }
  }

  /// Analyze current frame for quality assessment
  Future<ImageQualityAssessment?> analyzeCurrentFrame() async {
    if (_controller == null || !_controller!.value.isInitialized) return null;

    try {
      // Capture a frame for analysis
      final image = await _controller!.takePicture();
      final bytes = await image.readAsBytes();

      // Quick quality assessment
      return await _performQualityAssessment(bytes);
    } catch (e) {
      print('Frame analysis error: $e');
      return null;
    }
  }

  /// Perform quality assessment on image bytes
  Future<ImageQualityAssessment> _performQualityAssessment(
    Uint8List bytes,
  ) async {
    // Basic quality assessment without complex image processing
    double qualityScore = 75.0; // Default score
    final List<String> suggestions = [];

    // Simple heuristics based on image size
    if (bytes.length < 50000) {
      qualityScore = 50.0;
      suggestions.add(
        'Image might be too small. Try moving closer to the OMR sheet.',
      );
    } else if (bytes.length > 2000000) {
      qualityScore = 60.0;
      suggestions.add(
        'Image is very large. Consider reducing quality for faster processing.',
      );
    } else {
      qualityScore = 80.0;
    }

    // Check if image seems reasonable for OMR processing
    final isGoodQuality = qualityScore >= 70;

    return ImageQualityAssessment(
      qualityScore: qualityScore,
      brightness: 128.0, // Placeholder
      contrast: 64.0, // Placeholder
      sharpness: 128.0, // Placeholder
      suggestions: suggestions,
      isGoodQuality: isGoodQuality,
    );
  }

  /// Toggle grid overlay
  void toggleGrid() {
    _gridEnabled = !_gridEnabled;
    _cameraStateController.add('grid_toggled');
  }

  /// Get camera preview widget
  Widget getCameraPreview() {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return AspectRatio(
      aspectRatio: _controller!.value.aspectRatio,
      child: CameraPreview(_controller!),
    );
  }

  /// Get camera controls widget
  Widget getCameraControls({
    required VoidCallback onCapture,
    VoidCallback? onSwitchCamera,
    VoidCallback? onToggleFlash,
    VoidCallback? onToggleGrid,
  }) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Grid toggle
          IconButton(
            onPressed: onToggleGrid,
            icon: Icon(_gridEnabled ? Icons.grid_on : Icons.grid_off),
            color: Colors.white,
          ),

          // Capture button
          GestureDetector(
            onTap: onCapture,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                color: Colors.transparent,
              ),
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          // Camera switch and flash controls
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Flash mode indicator
              IconButton(
                onPressed: onToggleFlash,
                icon: Icon(
                  _flashMode == 'on'
                      ? Icons.flash_on
                      : _flashMode == 'auto'
                      ? Icons.flash_auto
                      : Icons.flash_off,
                ),
                color: Colors.white,
              ),

              // Camera switch
              if (_cameras != null && _cameras!.length > 1)
                IconButton(
                  onPressed: onSwitchCamera,
                  icon: const Icon(Icons.flip_camera_android),
                  color: Colors.white,
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Dispose camera resources
  void dispose() {
    _controller?.dispose();
    _cameraStateController.close();
    _qualityController.close();
    _isInitialized = false;
  }
}

/// Image quality assessment
class ImageQualityAssessment {
  final double qualityScore; // 0-100
  final double brightness; // 0-255
  final double contrast; // 0-255
  final double sharpness; // 0-255
  final List<String> suggestions;
  final bool isGoodQuality;

  const ImageQualityAssessment({
    required this.qualityScore,
    required this.brightness,
    required this.contrast,
    required this.sharpness,
    required this.suggestions,
    required this.isGoodQuality,
  });
}
