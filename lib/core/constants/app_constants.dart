
// App Constants and Configuration
class AppConstants {
  // Firebase Collections
  static const String examScansCollection = 'exam_scans';
  static const String usersCollection = 'users';
  static const String scanImagesFolder = 'scan_images';

  // Image Settings
  static const int maxImageWidth = 1920;
  static const int maxImageHeight = 1920;
  static const int imageQuality = 85;
  static const List<String> supportedImageFormats = [
    'jpg',
    'jpeg',
    'png',
    'webp',
  ];

  // Pagination
  static const int scansPerPage = 20;
  static const int batchUploadLimit = 10;

  // File Upload
  static const int maxFileSizeMB = 10;
  static const int uploadTimeoutSeconds = 300;

  // Cache Settings
  static const int cacheExpirationDays = 7;
  static const int maxCacheSizeMB = 100;

  // Analytics
  static const String analyticsScreenView = 'screen_view';
  static const String analyticsUploadEvent = 'scan_upload';
  static const String analyticsBatchEvent = 'batch_upload';
  static const String analyticsExportEvent = 'report_export';
}

// App Error Messages
class AppErrors {
  static const String noInternet =
      'No internet connection. Please check your network.';
  static const String uploadFailed = 'Upload failed. Please try again.';
  static const String imageTooLarge =
      'Image is too large. Please select a smaller image.';
  static const String invalidImageFormat =
      'Invalid image format. Please select JPG, PNG, or WebP.';
  static const String cameraPermissionDenied =
      'Camera permission denied. Please enable it in settings.';
  static const String storagePermissionDenied =
      'Storage permission denied. Please enable it in settings.';
  static const String batchUploadLimitExceeded =
      'You can upload maximum 10 images at once.';
  static const String authenticationFailed =
      'Authentication failed. Please try again.';
  static const String exportFailed = 'Export failed. Please try again.';
  static const String dataSyncFailed =
      'Data sync failed. Changes will be synced when online.';
}

// User Roles
enum UserRole { teacher, student, admin }

// Scan Status
enum ScanStatus { pending, processing, completed, failed }

// Export Format
enum ExportFormat { pdf, excel, csv }
