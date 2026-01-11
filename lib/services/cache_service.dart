import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static CacheService? _instance;
  static CacheService get instance => _instance ??= CacheService._();
  CacheService._();

  // Cache directories
  Directory? _cacheDirectory;
  Directory? _imageCacheDirectory;
  SharedPreferences? _prefs;

  // Cache configuration
  static const String _imageCacheKey = 'image_cache_info';
  static const int _maxImageCacheSize = 50 * 1024 * 1024; // 50MB
  static const Duration _defaultCacheExpiry = Duration(hours: 24);

  /// Initialize cache service
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();

      // Get cache directory
      final tempDir = await getTemporaryDirectory();
      _cacheDirectory = Directory('${tempDir.path}/omr_cache');
      await _cacheDirectory!.create(recursive: true);

      // Get image cache directory
      final imageCacheDir = Directory('${tempDir.path}/omr_images');
      _imageCacheDirectory = imageCacheDir;
      await imageCacheDir.create(recursive: true);

      // Start cache cleanup timer
      _startCleanupTimer();

      print('Cache service initialized');
    } catch (e) {
      print('Cache service initialization error: $e');
    }
  }

  /// Start periodic cache cleanup
  void _startCleanupTimer() {
    Timer.periodic(const Duration(hours: 6), (timer) {
      _performCleanup();
    });
  }

  /// Cache image data
  Future<String> cacheImage({
    required String key,
    required List<int> imageData,
    String? metadata,
  }) async {
    if (_imageCacheDirectory == null) {
      throw Exception('Cache service not initialized');
    }

    try {
      // Generate file path
      final fileName = '$key.jpg';
      final filePath = '${_imageCacheDirectory!.path}/$fileName';
      final file = File(filePath);

      // Write image data
      await file.writeAsBytes(imageData);

      // Save metadata
      await _saveImageMetadata(key, metadata);

      // Update cache info
      await _updateCacheInfo(key, filePath);

      // Check cache size and cleanup if needed
      await _checkCacheSize();

      return filePath;
    } catch (e) {
      print('Error caching image: $e');
      rethrow;
    }
  }

  /// Get cached image data
  Future<CachedImage?> getCachedImage(String key) async {
    if (_imageCacheDirectory == null) return null;

    try {
      final fileName = '$key.jpg';
      final filePath = '${_imageCacheDirectory!.path}/$fileName';
      final file = File(filePath);

      if (!await file.exists()) return null;

      // Check if file is expired
      final fileStat = await file.stat();
      final age = DateTime.now().difference(fileStat.modified);
      if (age > _defaultCacheExpiry) {
        await file.delete();
        return null;
      }

      // Read image data
      final imageData = await file.readAsBytes();
      final metadata = await _getImageMetadata(key);

      return CachedImage(
        key: key,
        data: imageData,
        filePath: filePath,
        metadata: metadata,
        lastAccessed: DateTime.now(),
      );
    } catch (e) {
      print('Error getting cached image: $e');
      return null;
    }
  }

  /// Cache JSON data
  Future<void> cacheJson({
    required String key,
    required Map<String, dynamic> data,
    Duration? expiry,
  }) async {
    try {
      final jsonString = jsonEncode(data);
      final expiryTime = expiry ?? _defaultCacheExpiry;
      final expiryTimestamp = DateTime.now()
          .add(expiryTime)
          .millisecondsSinceEpoch;

      await _prefs?.setString('json_cache_$key', jsonString);
      await _prefs?.setInt('json_cache_expiry_$key', expiryTimestamp);
    } catch (e) {
      print('Error caching JSON: $e');
    }
  }

  /// Get cached JSON data
  Future<Map<String, dynamic>?> getCachedJson(String key) async {
    try {
      final jsonString = _prefs?.getString('json_cache_$key');
      final expiryTimestamp = _prefs?.getInt('json_cache_expiry_$key');

      if (jsonString == null) return null;

      // Check expiry
      if (expiryTimestamp != null &&
          DateTime.now().millisecondsSinceEpoch > expiryTimestamp) {
        await _prefs?.remove('json_cache_$key');
        await _prefs?.remove('json_cache_expiry_$key');
        return null;
      }

      return jsonDecode(jsonString);
    } catch (e) {
      print('Error getting cached JSON: $e');
      return null;
    }
  }

  /// Cache file data
  Future<String> cacheFile({
    required String key,
    required List<int> fileData,
    String? fileName,
    String? extension,
  }) async {
    if (_cacheDirectory == null) {
      throw Exception('Cache service not initialized');
    }

    try {
      final safeFileName = fileName ?? key;
      final fileExtension = extension ?? '.dat';
      final finalFileName = '$safeFileName$fileExtension';
      final filePath = '${_cacheDirectory!.path}/$key/$finalFileName';
      final file = File(filePath);

      // Create directory if needed
      await file.parent.create(recursive: true);

      // Write file data
      await file.writeAsBytes(fileData);

      // Update cache info
      await _updateCacheInfo(key, filePath);

      return filePath;
    } catch (e) {
      print('Error caching file: $e');
      rethrow;
    }
  }

  /// Get cached file data
  Future<List<int>?> getCachedFile(String key, {String? fileName}) async {
    if (_cacheDirectory == null) return null;

    try {
      final safeFileName = fileName ?? 'data.dat';
      final filePath = '${_cacheDirectory!.path}/$key/$safeFileName';
      final file = File(filePath);

      if (!await file.exists()) return null;

      return await file.readAsBytes();
    } catch (e) {
      print('Error getting cached file: $e');
      return null;
    }
  }

  /// Check cache size and cleanup if needed
  Future<void> _checkCacheSize() async {
    if (_imageCacheDirectory == null) return;

    try {
      final cacheInfo = await _getCacheInfo();
      final totalSize = cacheInfo.values.fold<int>(
        0,
        (sum, info) => sum + (info['size'] as int? ?? 0),
      );

      if (totalSize > _maxImageCacheSize) {
        await _performImageCacheCleanup(totalSize - _maxImageCacheSize);
      }
    } catch (e) {
      print('Error checking cache size: $e');
    }
  }

  /// Perform cache cleanup
  Future<void> _performCleanup() async {
    await _performImageCacheCleanup();
    await _cleanExpiredJsonCache();
  }

  /// Perform image cache cleanup
  Future<void> _performImageCacheCleanup([int? targetSize]) async {
    if (_imageCacheDirectory == null) return;

    try {
      final cacheInfo = await _getCacheInfo();
      final cacheList = cacheInfo.entries.toList()
        ..sort(
          (a, b) =>
              a.value['last_accessed'].compareTo(b.value['last_accessed']),
        );

      int deletedSize = 0;
      final List<String> keysToDelete = [];

      for (final entry in cacheList) {
        final key = entry.key;
        final info = entry.value;
        final filePath = info['path'] as String;

        try {
          final file = File(filePath);
          if (await file.exists()) {
            final fileSize = await file.length();
            await file.delete();
            deletedSize += fileSize;
            keysToDelete.add(key);

            if (targetSize != null && deletedSize >= targetSize) {
              break;
            }
          }
        } catch (e) {
          print('Error deleting cached file: $e');
        }
      }

      // Remove from cache info
      for (final key in keysToDelete) {
        cacheInfo.remove(key);
      }

      await _saveCacheInfo(cacheInfo);

      print(
        'Cache cleanup completed: ${keysToDelete.length} files deleted, ${(deletedSize / 1024 / 1024).toStringAsFixed(2)}MB freed',
      );
    } catch (e) {
      print('Error during cache cleanup: $e');
    }
  }

  /// Clean expired JSON cache
  Future<void> _cleanExpiredJsonCache() async {
    if (_prefs == null) return;

    try {
      final keys = _prefs!
          .getKeys()
          .where((key) => key.startsWith('json_cache_expiry_'))
          .toList();
      final now = DateTime.now().millisecondsSinceEpoch;

      for (final key in keys) {
        final expiryTimestamp = _prefs!.getInt(key);
        if (expiryTimestamp != null && now > expiryTimestamp) {
          final cacheKey = key.replaceFirst('json_cache_expiry_', '');
          await _prefs?.remove('json_cache_$cacheKey');
          await _prefs?.remove(key);
        }
      }
    } catch (e) {
      print('Error cleaning expired JSON cache: $e');
    }
  }

  /// Save image metadata
  Future<void> _saveImageMetadata(String key, String? metadata) async {
    if (metadata == null) return;
    await _prefs?.setString('image_metadata_$key', metadata);
  }

  /// Get image metadata
  Future<String?> _getImageMetadata(String key) async {
    return _prefs?.getString('image_metadata_$key');
  }

  /// Update cache info
  Future<void> _updateCacheInfo(String key, String filePath) async {
    final cacheInfo = await _getCacheInfo();

    final file = File(filePath);
    final size = await file.length();

    cacheInfo[key] = {
      'path': filePath,
      'size': size,
      'last_accessed': DateTime.now().millisecondsSinceEpoch,
      'created': DateTime.now().millisecondsSinceEpoch,
    };

    await _saveCacheInfo(cacheInfo);
  }

  /// Get cache info
  Future<Map<String, Map<String, dynamic>>> _getCacheInfo() async {
    try {
      final cacheJson = _prefs?.getString(_imageCacheKey);
      if (cacheJson == null) return {};

      final cacheData = jsonDecode(cacheJson) as Map<String, dynamic>;
      return cacheData.map(
        (key, value) => MapEntry(key, value as Map<String, dynamic>),
      );
    } catch (e) {
      print('Error getting cache info: $e');
      return {};
    }
  }

  /// Save cache info
  Future<void> _saveCacheInfo(
    Map<String, Map<String, dynamic>> cacheInfo,
  ) async {
    try {
      final cacheJson = jsonEncode(cacheInfo);
      await _prefs?.setString(_imageCacheKey, cacheJson);
    } catch (e) {
      print('Error saving cache info: $e');
    }
  }

  /// Clear all cache
  Future<void> clearAllCache() async {
    try {
      // Clear image cache
      if (_imageCacheDirectory != null &&
          await _imageCacheDirectory!.exists()) {
        await _imageCacheDirectory!.delete(recursive: true);
        await _imageCacheDirectory!.create();
      }

      // Clear file cache
      if (_cacheDirectory != null && await _cacheDirectory!.exists()) {
        await _cacheDirectory!.delete(recursive: true);
        await _cacheDirectory!.create();
      }

      // Clear JSON cache
      final Set<String> keys = _prefs?.getKeys() ?? <String>{};
      for (final key in keys) {
        if (key.startsWith('json_cache_') ||
            key.startsWith('json_cache_expiry_') ||
            key.startsWith('image_metadata_') ||
            key == _imageCacheKey) {
          await _prefs?.remove(key);
        }
      }

      print('All cache cleared');
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }

  /// Get cache statistics
  Future<CacheStatistics> getCacheStatistics() async {
    try {
      final cacheInfo = await _getCacheInfo();
      int totalSize = 0;
      int fileCount = cacheInfo.length;

      for (final info in cacheInfo.values) {
        totalSize += info['size'] as int;
      }

      // Calculate JSON cache size
      final jsonKeys =
          _prefs
              ?.getKeys()
              .where((key) => key.startsWith('json_cache_'))
              .toList() ??
          [];
      int jsonCacheSize = 0;
      for (final key in jsonKeys) {
        final value = _prefs?.getString(key);
        if (value != null) {
          jsonCacheSize += value.length;
        }
      }

      return CacheStatistics(
        imageCacheSize: totalSize,
        imageCacheCount: fileCount,
        jsonCacheSize: jsonCacheSize,
        jsonCacheCount: jsonKeys.length,
        maxImageCacheSize: _maxImageCacheSize,
        cacheDirectory: _imageCacheDirectory?.path ?? '',
      );
    } catch (e) {
      print('Error getting cache statistics: $e');
      return CacheStatistics.empty();
    }
  }

  /// Preload data for offline use
  Future<void> preloadData({
    required List<String> imageKeys,
    Map<String, Map<String, dynamic>>? jsonData,
  }) async {
    try {
      // Preload JSON data
      if (jsonData != null) {
        for (final entry in jsonData.entries) {
          await cacheJson(key: entry.key, data: entry.value);
        }
      }

      print('Data preloading completed');
    } catch (e) {
      print('Error preloading data: $e');
    }
  }

  /// Check if data is cached
  Future<bool> isCached(
    String key, {
    bool checkJson = true,
    bool checkImages = true,
  }) async {
    if (checkImages) {
      final cachedImage = await getCachedImage(key);
      if (cachedImage != null) return true;
    }

    if (checkJson) {
      final cachedJson = await getCachedJson(key);
      if (cachedJson != null) return true;
    }

    return false;
  }
}

/// Cached image model
class CachedImage {
  final String key;
  final List<int> data;
  final String filePath;
  final String? metadata;
  final DateTime lastAccessed;

  const CachedImage({
    required this.key,
    required this.data,
    required this.filePath,
    this.metadata,
    required this.lastAccessed,
  });
}

/// Cache statistics model
class CacheStatistics {
  final int imageCacheSize;
  final int imageCacheCount;
  final int jsonCacheSize;
  final int jsonCacheCount;
  final int maxImageCacheSize;
  final String cacheDirectory;

  CacheStatistics({
    required this.imageCacheSize,
    required this.imageCacheCount,
    required this.jsonCacheSize,
    required this.jsonCacheCount,
    required this.maxImageCacheSize,
    required this.cacheDirectory,
  });

  factory CacheStatistics.empty() => CacheStatistics(
    imageCacheSize: 0,
    imageCacheCount: 0,
    jsonCacheSize: 0,
    jsonCacheCount: 0,
    maxImageCacheSize: 0,
    cacheDirectory: '',
  );

  double get imageCacheUsagePercent => maxImageCacheSize > 0
      ? (imageCacheSize / maxImageCacheSize * 100).clamp(0.0, 100.0)
      : 0.0;

  String get imageCacheSizeFormatted => _formatBytes(imageCacheSize);
  String get jsonCacheSizeFormatted => _formatBytes(jsonCacheSize);
  String get maxImageCacheSizeFormatted => _formatBytes(maxImageCacheSize);

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}
