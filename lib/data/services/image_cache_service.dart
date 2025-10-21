import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Service to cache cloud images locally for faster access
/// Cache is user-specific and persists across logout/login
class ImageCacheService {
  /// Download and cache an image from URL (user-specific cache)
  static Future<String?> getCachedImagePath(
      String? cloudUrl, String documentId, String userId) async {
    if (cloudUrl == null || cloudUrl.isEmpty) return null;

    try {
      // Get user-specific cache directory (persists across logout)
      final appDir = await getApplicationDocumentsDirectory();
      final userCacheDir = Directory('${appDir.path}/image_cache/$userId');
      if (!await userCacheDir.exists()) {
        await userCacheDir.create(recursive: true);
      }

      // Generate cache filename from document ID
      final cacheFileName = '$documentId.jpg';
      final cacheFile = File('${userCacheDir.path}/$cacheFileName');

      // If already cached, return the path
      if (await cacheFile.exists()) {
        print('✅ [ImageCache] Using cached image: $documentId (user: $userId)');
        return cacheFile.path;
      }

      // Download and cache the image
      print('📥 [ImageCache] Downloading image: $cloudUrl');
      final response = await http.get(Uri.parse(cloudUrl)).timeout(
            const Duration(seconds: 30),
          );

      if (response.statusCode == 200) {
        await cacheFile.writeAsBytes(response.bodyBytes);
        print(
            '✅ [ImageCache] Image cached: $documentId (${response.bodyBytes.length} bytes)');
        return cacheFile.path;
      } else {
        print('❌ [ImageCache] Download failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ [ImageCache] Error caching image: $e');
      return null;
    }
  }

  /// Get local file path (either original or cached)
  static Future<String?> getLocalImagePath(
      String localImagePath, String? cloudUrl, String documentId) async {
    // First, check if local file exists
    final localFile = File(localImagePath);
    if (await localFile.exists()) {
      return localImagePath;
    }

    // Get current user ID
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    // If not, try to get from cache or download from cloud
    if (cloudUrl != null && cloudUrl.isNotEmpty) {
      return await getCachedImagePath(cloudUrl, documentId, user.uid);
    }

    return null;
  }

  /// Clear cache for a specific document (user-specific)
  static Future<void> clearDocumentCache(String documentId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final appDir = await getApplicationDocumentsDirectory();
      final cacheFile =
          File('${appDir.path}/image_cache/${user.uid}/$documentId.jpg');
      if (await cacheFile.exists()) {
        await cacheFile.delete();
        print(
            '🗑️ [ImageCache] Cleared cache for: $documentId (user: ${user.uid})');
      }
    } catch (e) {
      print('❌ [ImageCache] Error clearing cache: $e');
    }
  }

  /// Clear cache for current user only
  static Future<void> clearUserCache() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final appDir = await getApplicationDocumentsDirectory();
      final userCacheDir = Directory('${appDir.path}/image_cache/${user.uid}');
      if (await userCacheDir.exists()) {
        await userCacheDir.delete(recursive: true);
        print('🗑️ [ImageCache] User cache cleared (user: ${user.uid})');
      }
    } catch (e) {
      print('❌ [ImageCache] Error clearing user cache: $e');
    }
  }

  /// Clear all cached images (all users - use sparingly!)
  static Future<void> clearAllCache() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${appDir.path}/image_cache');
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        print('🗑️ [ImageCache] All cache cleared');
      }
    } catch (e) {
      print('❌ [ImageCache] Error clearing all cache: $e');
    }
  }

  /// Get cache size for current user
  static Future<int> getCacheSize() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 0;

      final appDir = await getApplicationDocumentsDirectory();
      final userCacheDir = Directory('${appDir.path}/image_cache/${user.uid}');
      if (!await userCacheDir.exists()) return 0;

      int totalSize = 0;
      await for (var entity in userCacheDir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      return totalSize;
    } catch (e) {
      print('❌ [ImageCache] Error getting cache size: $e');
      return 0;
    }
  }

  /// Format bytes to human-readable string
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
