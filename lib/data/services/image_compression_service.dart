import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Service for compressing images locally before saving
/// Maintains high quality while reducing file size significantly
class ImageCompressionService {
  /// Compress image with high quality settings
  /// Quality: 92% (optimal balance between quality and size)
  /// Max dimension: 2048px (maintains excellent quality for documents)
  ///
  /// This ensures:
  /// - Fast local saves (smaller files)
  /// - Fast MongoDB sync (smaller payload)
  /// - No visible quality loss for document photos
  static Future<String?> compressImage(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        print('❌ [ImageCompression] File not found: $imagePath');
        return null;
      }

      final fileSize = await file.length();
      print('🗜️ [ImageCompression] Compressing image...');
      print('   Original size: ${_formatBytes(fileSize)}');

      // Get app's documents directory for compressed files
      final directory = await getApplicationDocumentsDirectory();
      final compressedDir = Directory('${directory.path}/compressed_images');
      if (!await compressedDir.exists()) {
        await compressedDir.create(recursive: true);
      }

      final fileName = path.basename(imagePath);
      final targetPath =
          '${compressedDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}_$fileName';

      // Compress with high quality settings
      // Quality 92%: Excellent quality with good compression (recommended for documents)
      // Max dimension 2048px: Maintains very high quality for all use cases
      final result = await FlutterImageCompress.compressAndGetFile(
        imagePath,
        targetPath,
        quality: 92, // 92% quality - optimal for documents
        minWidth: 2048, // Max width - maintains excellent quality
        minHeight: 2048, // Max height - maintains excellent quality
        format: CompressFormat.jpeg, // JPEG for smaller file size
      );

      if (result == null) {
        print('⚠️ [ImageCompression] Compression failed, using original');
        return imagePath;
      }

      final compressedSize = await result.length();
      final reduction =
          ((fileSize - compressedSize) / fileSize * 100).toStringAsFixed(1);

      print('✅ [ImageCompression] Image compressed successfully');
      print('   Compressed size: ${_formatBytes(compressedSize)}');
      print('   Reduction: $reduction%');
      print('   Saved at: ${result.path}');

      // Delete original file to save space
      try {
        await file.delete();
        print('🗑️ [ImageCompression] Original file deleted');
      } catch (e) {
        print('⚠️ [ImageCompression] Could not delete original: $e');
      }

      return result.path;
    } catch (e) {
      print('❌ [ImageCompression] Error: $e');
      print('   Falling back to original image');
      return imagePath;
    }
  }

  /// Format bytes to human-readable string
  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Clean up old compressed images (optional - call periodically)
  /// Removes compressed images older than 7 days
  static Future<void> cleanupOldCompressedImages() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final compressedDir = Directory('${directory.path}/compressed_images');

      if (!await compressedDir.exists()) return;

      final files = compressedDir.listSync();
      final now = DateTime.now();
      int deletedCount = 0;

      for (final file in files) {
        if (file is File) {
          final stat = await file.stat();
          final age = now.difference(stat.modified);

          if (age.inDays > 7) {
            await file.delete();
            deletedCount++;
          }
        }
      }

      if (deletedCount > 0) {
        print(
            '🗑️ [ImageCompression] Cleaned up $deletedCount old compressed images');
      }
    } catch (e) {
      print('⚠️ [ImageCompression] Cleanup error: $e');
    }
  }
}
