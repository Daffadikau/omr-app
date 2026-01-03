import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/camera_service.dart';
import '../services/advanced_image_processor.dart';
import '../models/image_processing_result.dart';

class EnhancedCameraWidget extends StatefulWidget {
  final Function(ImageProcessingResult) onImageProcessed;
  final VoidCallback? onClose;

  const EnhancedCameraWidget({
    super.key,
    required this.onImageProcessed,
    this.onClose,
  });

  @override
  State<EnhancedCameraWidget> createState() => _EnhancedCameraWidgetState();
}

class _EnhancedCameraWidgetState extends State<EnhancedCameraWidget>
    with TickerProviderStateMixin {
  late final CameraService _cameraService;
  late final AnimationController _flashAnimationController;
  late final AnimationController _captureAnimationController;

  // Animation objects
  late final Animation<double> _flashAnimation;
  late final Animation<double> _captureAnimation;

  // UI State
  bool _isInitialized = false;
  bool _isCapturing = false;
  String _currentState = 'initializing';
  ImageQualityAssessment? _qualityAssessment;
  Timer? _qualityTimer;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _setupAnimations();
    _startQualityMonitoring();
  }

  @override
  void dispose() {
    _flashAnimationController.dispose();
    _captureAnimationController.dispose();
    _qualityTimer?.cancel();
    _cameraService.dispose();
    super.dispose();
  }

  /// Initialize camera service
  Future<void> _initializeServices() async {
    _cameraService = CameraService.instance;

    // Listen to camera state changes
    _cameraService.cameraStateStream.listen((state) {
      setState(() {
        _currentState = state;
        if (state == 'initialized') {
          _isInitialized = true;
        }
      });
    });

    // Initialize camera
    final success = await _cameraService.initialize();
    if (!success) {
      _showErrorDialog(
        'Camera initialization failed. Please check permissions.',
      );
    }
  }

  /// Setup animations
  void _setupAnimations() {
    _flashAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _captureAnimationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _flashAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _flashAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _captureAnimation = Tween<double>(begin: 1.0, end: 0.8).animate(
      CurvedAnimation(
        parent: _captureAnimationController,
        curve: Curves.easeOut,
      ),
    );
  }

  /// Start quality monitoring
  void _startQualityMonitoring() {
    _qualityTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _analyzeImageQuality();
    });
  }

  /// Analyze current image quality
  Future<void> _analyzeImageQuality() async {
    if (!_cameraService.isInitialized) return;

    final assessment = await _cameraService.analyzeCurrentFrame();
    if (assessment != null) {
      setState(() {
        _qualityAssessment = assessment;
      });
    }
  }

  /// Capture image
  Future<void> _captureImage() async {
    if (!_cameraService.isInitialized || _isCapturing) return;

    setState(() {
      _isCapturing = true;
    });

    // Animate capture button
    _captureAnimationController.forward().then((_) {
      _captureAnimationController.reverse();
    });

    try {
      final result = await _cameraService.captureImage();
      if (result != null) {
        widget.onImageProcessed(result);
      } else {
        _showErrorDialog('Failed to capture image. Please try again.');
      }
    } catch (e) {
      _showErrorDialog('Capture error: ${e.toString()}');
    } finally {
      setState(() {
        _isCapturing = false;
      });
    }
  }

  /// Toggle flash mode
  Future<void> _toggleFlash() async {
    await _cameraService.toggleFlashMode();
    _flashAnimationController.forward().then((_) {
      _flashAnimationController.reverse();
    });
  }

  /// Switch camera
  Future<void> _switchCamera() async {
    await _cameraService.switchCamera();
  }

  /// Toggle grid
  void _toggleGrid() {
    _cameraService.toggleGrid();
  }

  /// Show error dialog
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Camera Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Camera preview
            _buildCameraPreview(),

            // Grid overlay
            if (_cameraService.gridEnabled) _buildGridOverlay(),

            // Top controls
            _buildTopControls(),

            // Quality indicator
            if (_qualityAssessment != null) _buildQualityIndicator(),

            // Bottom controls
            _buildBottomControls(),

            // State indicators
            _buildStateIndicators(),
          ],
        ),
      ),
    );
  }

  /// Build camera preview
  Widget _buildCameraPreview() {
    if (!_isInitialized) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Initializing camera...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return Positioned.fill(child: _cameraService.getCameraPreview());
  }

  /// Build grid overlay
  Widget _buildGridOverlay() {
    return Positioned.fill(child: CustomPaint(painter: GridPainter()));
  }

  /// Build top controls
  Widget _buildTopControls() {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Close button
          _buildControlButton(
            icon: Icons.close,
            onTap: widget.onClose ?? () => Navigator.of(context).pop(),
            backgroundColor: Colors.black54,
          ),

          // Flash indicator
          AnimatedBuilder(
            animation: _flashAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + (_flashAnimation.value * 0.2),
                child: _buildControlButton(
                  icon: _getFlashIcon(_cameraService.flashMode),
                  onTap: _toggleFlash,
                  backgroundColor: _getFlashColor(_cameraService.flashMode),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Build quality indicator
  Widget _buildQualityIndicator() {
    return Positioned(
      top: 80,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _qualityAssessment!.isGoodQuality
              ? Colors.green.withOpacity(0.8)
              : Colors.orange.withOpacity(0.8),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Quality: ${_qualityAssessment!.qualityScore.toInt()}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_qualityAssessment!.suggestions.isNotEmpty)
              const SizedBox(height: 4),
            if (_qualityAssessment!.suggestions.isNotEmpty)
              Text(
                _qualityAssessment!.suggestions.first,
                style: const TextStyle(color: Colors.white, fontSize: 10),
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }

  /// Build bottom controls
  Widget _buildBottomControls() {
    return Positioned(
      bottom: 32,
      left: 0,
      right: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Grid toggle
            _buildControlButton(
              icon: _cameraService.gridEnabled ? Icons.grid_on : Icons.grid_off,
              onTap: _toggleGrid,
            ),

            // Capture button
            AnimatedBuilder(
              animation: _captureAnimation,
              builder: (context, child) {
                return GestureDetector(
                  onTap: _isCapturing ? null : _captureImage,
                  child: Transform.scale(
                    scale: _isCapturing ? _captureAnimation.value : 1.0,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        color: Colors.transparent,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isCapturing ? Colors.grey : Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 5,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: _isCapturing
                            ? const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black54,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                );
              },
            ),

            // Camera switch
            if (_cameraService.cameras != null &&
                _cameraService.cameras!.length > 1)
              _buildControlButton(
                icon: Icons.flip_camera_android,
                onTap: _switchCamera,
              ),
          ],
        ),
      ),
    );
  }

  /// Build state indicators
  Widget _buildStateIndicators() {
    if (_currentState == 'capturing') {
      return Positioned.fill(
        child: Container(
          color: Colors.black54,
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
                SizedBox(height: 16),
                Text(
                  'Processing image...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  /// Build control button
  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    Color? backgroundColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor ?? Colors.black54,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  /// Get flash icon based on mode
  IconData _getFlashIcon(String flashMode) {
    switch (flashMode) {
      case 'on':
        return Icons.flash_on;
      case 'auto':
        return Icons.flash_auto;
      case 'off':
      default:
        return Icons.flash_off;
    }
  }

  /// Get flash color based on mode
  Color _getFlashColor(String flashMode) {
    switch (flashMode) {
      case 'on':
        return Colors.orange.withOpacity(0.8);
      case 'auto':
        return Colors.yellow.withOpacity(0.8);
      case 'off':
      default:
        return Colors.black54;
    }
  }
}

/// Grid overlay painter
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..strokeWidth = 1.0;

    final width = size.width;
    final height = size.height;

    // Rule of thirds grid
    final thirdWidth = width / 3;
    final thirdHeight = height / 3;

    // Vertical lines
    canvas.drawLine(Offset(thirdWidth, 0), Offset(thirdWidth, height), paint);
    canvas.drawLine(
      Offset(thirdWidth * 2, 0),
      Offset(thirdWidth * 2, height),
      paint,
    );

    // Horizontal lines
    canvas.drawLine(Offset(0, thirdHeight), Offset(width, thirdHeight), paint);
    canvas.drawLine(
      Offset(0, thirdHeight * 2),
      Offset(width, thirdHeight * 2),
      paint,
    );

    // Corner brackets for better framing
    final bracketSize = 20.0;
    final bracketPaint = Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..strokeWidth = 2.0;

    // Top-left corner
    canvas.drawLine(Offset(0, bracketSize), Offset(0, 0), bracketPaint);
    canvas.drawLine(Offset(0, 0), Offset(bracketSize, 0), bracketPaint);

    // Top-right corner
    canvas.drawLine(
      Offset(width - bracketSize, 0),
      Offset(width, 0),
      bracketPaint,
    );
    canvas.drawLine(Offset(width, 0), Offset(width, bracketSize), bracketPaint);

    // Bottom-left corner
    canvas.drawLine(
      Offset(0, height - bracketSize),
      Offset(0, height),
      bracketPaint,
    );
    canvas.drawLine(
      Offset(0, height),
      Offset(bracketSize, height),
      bracketPaint,
    );

    // Bottom-right corner
    canvas.drawLine(
      Offset(width - bracketSize, height),
      Offset(width, height),
      bracketPaint,
    );
    canvas.drawLine(
      Offset(width, height - bracketSize),
      Offset(width, height),
      bracketPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
