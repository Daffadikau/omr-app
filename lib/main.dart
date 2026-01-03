import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:cached_network_image/cached_network_image.dart';
import 'firebase_options.dart';
import 'widgets/web_camera_capture.dart' if (dart.library.io) 'widgets/web_camera_capture_stub.dart';
import 'features/analytics/analytics_dashboard.dart';
import 'models/exam_submission.dart';
import 'repositories/exam_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light
          ? ThemeMode.dark
          : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OMR Scanner Pro',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.indigo.shade700,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.indigo.shade800,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: OMRHomePage(
        onToggleTheme: _toggleTheme,
        isDarkMode: _themeMode == ThemeMode.dark,
      ),
    );
  }
}

class OMRHomePage extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const OMRHomePage({
    super.key,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  @override
  State<OMRHomePage> createState() => _OMRHomePageState();
}

class _OMRHomePageState extends State<OMRHomePage> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  // Image handling variables
  File? _imageFile;
  Uint8List? _webImage;
  XFile? _pickedFile;

  bool _isUploading = false;
  bool _isProcessing = false;
  double _uploadProgress = 0.0;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _studentNameController = TextEditingController();
  final ExamRepository _repository = ExamRepository();

  // 1. Enhanced Image Picker with Optimization
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (image != null) {
        setState(() {
          _pickedFile = image;
        });

        // Optimize image based on platform
        if (kIsWeb) {
          var imageBytes = await image.readAsBytes();
          var optimizedImage = await _optimizeImage(imageBytes);
          setState(() {
            _webImage = optimizedImage;
          });
        } else {
          var file = File(image.path);
          var optimizedFile = await _optimizeImageFile(file);
          setState(() {
            _imageFile = optimizedFile;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Web Camera Capture
  Future<void> _openWebCamera() async {
    if (!kIsWeb) return;
    
    final result = await WebCameraCapture.captureImage(context);
    
    if (result != null) {
      setState(() {
        _pickedFile = result;
      });
      
      var imageBytes = await result.readAsBytes();
      var optimizedImage = await _optimizeImage(imageBytes);
      setState(() {
        _webImage = optimizedImage;
      });
    }
  }

  // 2. Image Optimization for Web
  Future<Uint8List> _optimizeImage(Uint8List imageBytes) async {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) return imageBytes;

      // Resize if too large
      if (image.width > 1920 || image.height > 1920) {
        img.Image resized = img.copyResize(
          image,
          width: 1920,
          height: 1920,
          interpolation: img.Interpolation.linear,
        );
        return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
      }

      return Uint8List.fromList(img.encodeJpg(image, quality: 85));
    } catch (e) {
      return imageBytes; // Return original if optimization fails
    }
  }

  // 3. Image Optimization for Mobile
  Future<File> _optimizeImageFile(File imageFile) async {
    try {
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);
      if (image == null) return imageFile;

      // Resize if too large
      if (image.width > 1920 || image.height > 1920) {
        img.Image resized = img.copyResize(
          image,
          width: 1920,
          height: 1920,
          interpolation: img.Interpolation.linear,
        );
        final optimizedBytes = Uint8List.fromList(
          img.encodeJpg(resized, quality: 85),
        );
        final optimizedFile = File(imageFile.path);
        await optimizedFile.writeAsBytes(optimizedBytes);
        return optimizedFile;
      }

      return imageFile;
    } catch (e) {
      return imageFile; // Return original if optimization fails
    }
  }

  // 4. Enhanced Upload with Progress Tracking
  Future<void> _uploadAndScan() async {
    if (_pickedFile == null || _studentNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter name and pick an image'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _isProcessing = true;
      _uploadProgress = 0.0;
    });

    try {
      // Upload with progress tracking
      await _repository.uploadScanWithProgress(
        studentName: _studentNameController.text,
        isWeb: kIsWeb,
        webImage: _webImage,
        mobileImage: _imageFile,
        onProgress: (progress) {
          setState(() {
            _uploadProgress = progress;
          });
        },
      );

      // Cleanup
      setState(() {
        _imageFile = null;
        _webImage = null;
        _pickedFile = null;
        _studentNameController.clear();
        _isUploading = false;
        _isProcessing = false;
        _uploadProgress = 0.0;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Upload complete! Processing started...'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _isProcessing = false;
        _uploadProgress = 0.0;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 5. Image Preview Dialog with Zoom
  void _showImagePreview() {
    if (_pickedFile == null) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: EdgeInsets.all(16),
          child: Container(
            width: double.infinity,
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                AppBar(
                  title: const Text('Image Preview'),
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                Expanded(
                  child: kIsWeb
                      ? _webImage != null
                            ? Image.memory(
                                _webImage!,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(
                                    child: Icon(Icons.broken_image, size: 64),
                                  );
                                },
                              )
                            : const Center(child: CircularProgressIndicator())
                      : _imageFile != null
                      ? Image.file(
                          _imageFile!,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(Icons.broken_image, size: 64),
                            );
                          },
                        )
                      : const Center(child: CircularProgressIndicator()),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onTabTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: [_buildScannerPage(), const AnalyticsDashboard()],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.scanner),
            activeIcon: Icon(Icons.scanner),
            label: 'Scanner',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            activeIcon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
        ],
      ),
    );
  }

  Widget _buildScannerPage() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OMR Scanner Pro'),
        elevation: 2,
        actions: [
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.onToggleTheme,
            tooltip: widget.isDarkMode
                ? 'Switch to Light Mode'
                : 'Switch to Dark Mode',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with animation
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Text(
                      "OMR Grader Pro",
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ).animate().fadeIn().slideX(),
                    const SizedBox(height: 8),
                    Text(
                      "Advanced Optical Mark Recognition",
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ).animate().fadeIn(delay: 200.ms).slideX(),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Input Section with enhanced UI
            Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.camera_alt,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "New Scan",
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ).animate().fadeIn().slideX(),
                    const SizedBox(height: 20),

                    TextField(
                      controller: _studentNameController,
                      decoration: InputDecoration(
                        labelText: 'Student Name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.person),
                        filled: true,
                      ),
                    ).animate().fadeIn(delay: 100.ms).slideY(),
                    const SizedBox(height: 16),

                    // Enhanced Image Preview
                    GestureDetector(
                      onTap: _showImagePreview,
                      child: Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).colorScheme.surface,
                              Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        child: _pickedFile == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.camera_alt,
                                    size: 48,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Tap to select image",
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: kIsWeb
                                    ? _webImage != null
                                          ? Image.memory(
                                              _webImage!,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                    return const Center(
                                                      child: Icon(
                                                        Icons.broken_image,
                                                        size: 48,
                                                      ),
                                                    );
                                                  },
                                            )
                                          : const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            )
                                    : _imageFile != null
                                    ? Image.file(
                                        _imageFile!,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return const Center(
                                                child: Icon(
                                                  Icons.broken_image,
                                                  size: 48,
                                                ),
                                              );
                                            },
                                      )
                                    : const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                              ),
                      ),
                    ).animate().fadeIn(delay: 200.ms).scale(),

                    const SizedBox(height: 20),

                    // Enhanced Button Row
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => kIsWeb ? _openWebCamera() : _pickImage(ImageSource.camera),
                            icon: const Icon(Icons.camera),
                            label: const Text('Camera'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ).animate().fadeIn(delay: 300.ms).slideX(),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _pickImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Gallery'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ).animate().fadeIn(delay: 400.ms).slideX(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Upload Progress and Button
                    if (_isUploading) ...[
                      LinearProgressIndicator(
                        value: _uploadProgress,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ).animate().fadeIn().slideY(),
                      const SizedBox(height: 8),
                      Text(
                        'Uploading... ${(_uploadProgress * 100).toInt()}%',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ] else if (_isProcessing)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Processing...',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ).animate().fadeIn().slideY()
                    else
                      FilledButton.icon(
                        onPressed: _uploadAndScan,
                        icon: const Icon(Icons.cloud_upload),
                        label: const Text('UPLOAD & GRADE'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ).animate().fadeIn(delay: 500.ms).slideY(),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 25),

            // Enhanced Results Section
            Row(
              children: [
                Icon(
                  Icons.analytics,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  "Recent Results",
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ).animate().fadeIn(delay: 600.ms).slideX(),
            const SizedBox(height: 10),

            // Enhanced Results List with Cached Network Images
            StreamBuilder<List<ExamSubmission>>(
              stream: _repository.getScansStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 64,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No scans yet',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Upload your first answer sheet to get started',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final submission = snapshot.data![index];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(25),
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(25),
                            child: CachedNetworkImage(
                              imageUrl: submission.imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: Theme.of(
                                  context,
                                ).colorScheme.errorContainer,
                                child: Icon(
                                  Icons.broken_image,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          submission.studentName,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            _buildStatusWidget(submission),
                          ],
                        ),
                        trailing: _buildTrailingWidget(submission),
                        onTap: () => _showSubmissionDetails(submission),
                      ),
                    ).animate().fadeIn(delay: (700 + index * 100).ms).slideX();
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusWidget(ExamSubmission submission) {
    String statusText = submission.status;
    Color statusColor = Colors.orange;
    String scoreText = "Processing...";

    if (statusText == 'completed') {
      statusColor = Colors.green;
      scoreText = "Score: ${submission.resultScore ?? 'N/A'}";
    } else if (statusText == 'processing') {
      statusColor = Colors.blue;
      scoreText = "Processing...";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Text(
        scoreText,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: statusColor,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildTrailingWidget(ExamSubmission submission) {
    if (submission.status == 'processing') {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (submission.status == 'completed') {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.check_circle, color: Colors.green, size: 20),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.pending, color: Colors.orange, size: 20),
      );
    }
  }

  void _showSubmissionDetails(ExamSubmission submission) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              submission.studentName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildDetailCard('Status', submission.status, Icons.info),
                _buildDetailCard(
                  'Score',
                  submission.resultScore?.toString() ?? 'N/A',
                  Icons.score,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showImageDialog(submission.imageUrl);
                },
                icon: const Icon(Icons.image),
                label: const Text('View Image'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard(String label, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  void _showImageDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: double.infinity,
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              AppBar(
                title: const Text('Scan Image'),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Expanded(
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) =>
                      const Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) =>
                      const Center(child: Icon(Icons.broken_image, size: 64)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Enhanced Data Models & Repository

class ExamSubmission {
  final String id;
  final String studentName;
  final String imageUrl;
  final String status;
  final dynamic resultScore;
  final DateTime? timestamp;

  ExamSubmission({
    required this.id,
    required this.studentName,
    required this.imageUrl,
    required this.status,
    this.resultScore,
    this.timestamp,
  });

  factory ExamSubmission.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return ExamSubmission(
      id: doc.id,
      studentName: data['student_name'] ?? 'Unknown',
      imageUrl: data['image_url'] ?? '',
      status: data['status'] ?? 'pending',
      resultScore: data['result_score'],
      timestamp: data['timestamp'] != null
          ? (data['timestamp'] as Timestamp).toDate()
          : null,
    );
  }
}

class ExamRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Stream<List<ExamSubmission>> getScansStream() {
    return _firestore
        .collection('exam_scans')
        .orderBy('timestamp', descending: true)
        .limit(50) // Add pagination for better performance
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ExamSubmission.fromSnapshot(doc))
              .toList(),
        );
  }

  Future<void> uploadScanWithProgress({
    required String studentName,
    required bool isWeb,
    Uint8List? webImage,
    File? mobileImage,
    Function(double)? onProgress,
  }) async {
    String fileName = 'scans/${DateTime.now().millisecondsSinceEpoch}.jpg';
    Reference storageRef = _storage.ref().child(fileName);

    // Upload with progress tracking
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
      if (onProgress != null) {
        double progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress(progress);
      }
    });

    // Wait for upload to complete
    await uploadTask.whenComplete(() => null);

    String downloadUrl = await storageRef.getDownloadURL();

    await _firestore.collection('exam_scans').add({
      'student_name': studentName,
      'image_url': downloadUrl,
      'status': 'processing',
      'result_score': null,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Enhanced batch upload method (for Phase 2)
  Future<List<String>> uploadBatchScans({
    required List<Map<String, dynamic>> scans,
    Function(double)? onProgress,
  }) async {
    List<String> uploadUrls = [];
    int total = scans.length;
    int completed = 0;

    for (var scan in scans) {
      try {
        String fileName =
            'scans/batch_${DateTime.now().millisecondsSinceEpoch}_$completed.jpg';
        Reference storageRef = _storage.ref().child(fileName);

        UploadTask uploadTask;
        if (scan['isWeb'] && scan['webImage'] != null) {
          uploadTask = storageRef.putData(scan['webImage']);
        } else if (!scan['isWeb'] && scan['mobileImage'] != null) {
          uploadTask = storageRef.putFile(scan['mobileImage']);
        } else {
          continue;
        }

        await uploadTask.whenComplete(() => null);
        String downloadUrl = await storageRef.getDownloadURL();
        uploadUrls.add(downloadUrl);

        completed++;
        if (onProgress != null) {
          onProgress(completed / total);
        }
      } catch (e) {
        // Continue with other uploads even if one fails
        print('Error uploading scan: $e');
      }
    }

    return uploadUrls;
  }
}
