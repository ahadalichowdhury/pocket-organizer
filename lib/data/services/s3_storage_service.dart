import 'dart:io';
import 'dart:typed_data';

import 'package:aws_s3_upload_lite/aws_s3_upload_lite.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Service for uploading and managing document images in AWS S3
/// Using aws_s3_upload_lite package for simplified S3 operations
/// Images are compressed before upload (WhatsApp-style: 90% quality JPEG)
class S3StorageService {
  static String? _accessKey;
  static String? _secretKey;
  static String? _region;
  static String? _bucket;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Initialize S3 configuration
  static Future<void> init() async {
    try {
      _accessKey = dotenv.env['AWS_ACCESS_KEY_ID'];
      _secretKey = dotenv.env['AWS_SECRET_ACCESS_KEY'];
      _region = dotenv.env['AWS_S3_REGION'] ?? 'us-east-1';
      _bucket = dotenv.env['AWS_S3_BUCKET'] ?? 'bucketorganizer';

      if (_accessKey == null || _secretKey == null) {
        print(
            '⚠️ [S3] AWS credentials not configured - using local storage only');
        return;
      }

      print('✅ [S3] Initialized successfully');
      print('   Region: $_region');
      print('   Bucket: $_bucket');
    } catch (e) {
      print('❌ [S3] Initialization failed: $e');
      _accessKey = null;
      _secretKey = null;
    }
  }

  /// Check if S3 is configured and available
  static bool get isConfigured => _accessKey != null && _secretKey != null;

  /// Compress image before upload (WhatsApp-style: 90% quality, max 1920px width)
  /// This maintains visual quality while reducing file size significantly
  static Future<Uint8List?> _compressImage(String imagePath) async {
    try {
      final file = File(imagePath);
      final fileSize = await file.length();

      print('🗜️ [S3] Compressing image...');
      print('   Original size: ${formatBytes(fileSize)}');

      // Get temp directory for compressed file
      final tempDir = await getTemporaryDirectory();
      final targetPath =
          '${tempDir.path}/compressed_${path.basename(imagePath)}';

      // Compress with high quality (90%) - WhatsApp uses 90-92%
      // Max width 1920px to handle high-res images without losing quality
      final result = await FlutterImageCompress.compressAndGetFile(
        imagePath,
        targetPath,
        quality: 90, // High quality, similar to WhatsApp
        minWidth: 1920, // Max width to maintain good quality
        minHeight: 1920,
        format: CompressFormat.jpeg,
      );

      if (result == null) {
        print('⚠️ [S3] Compression failed, using original');
        return await file.readAsBytes();
      }

      final compressedBytes = await result.readAsBytes();
      final compressedSize = compressedBytes.length;
      final reduction =
          ((fileSize - compressedSize) / fileSize * 100).toStringAsFixed(1);

      print('✅ [S3] Image compressed');
      print('   Compressed size: ${formatBytes(compressedSize)}');
      print('   Reduction: $reduction%');

      // Clean up temp file
      try {
        await File(targetPath).delete();
      } catch (_) {}

      return compressedBytes;
    } catch (e) {
      print('❌ [S3] Compression error: $e');
      print('   Falling back to original image');
      return await File(imagePath).readAsBytes();
    }
  }

  /// Upload a document image to S3 using aws_s3_upload_lite
  /// Image is automatically compressed before upload
  static Future<String?> uploadDocumentImage({
    required String localImagePath,
    required String documentId,
  }) async {
    if (!isConfigured) {
      print('⚠️ [S3] Not configured - skipping upload');
      return null;
    }

    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('❌ [S3] No user logged in');
        return null;
      }

      final file = File(localImagePath);
      if (!await file.exists()) {
        print('❌ [S3] Local file not found: $localImagePath');
        return null;
      }

      // Compress image before upload
      final compressedBytes = await _compressImage(localImagePath);
      if (compressedBytes == null) {
        print('❌ [S3] Failed to process image');
        return null;
      }

      final fileName = path.basename(localImagePath);
      final destDir = 'users/${user.uid}/documents/$documentId';

      print('📤 [S3] Uploading compressed image: $fileName');
      print('   Upload size: ${formatBytes(compressedBytes.length)}');
      print('   S3 destination: $destDir/$fileName');
      print('   Bucket: $_bucket');

      // Upload using aws_s3_upload_lite
      final result = await AwsS3.upload(
        accessKey: _accessKey!,
        secretKey: _secretKey!,
        file: compressedBytes,
        bucket: _bucket!,
        region: _region!,
        destDir: destDir,
        filename: fileName,
        metadata: {
          'user-id': user.uid,
          'document-id': documentId,
          'upload-timestamp': DateTime.now().toIso8601String(),
          'compressed': 'true',
        },
      );

      if (result.isNotEmpty) {
        // Construct the public URL
        final publicUrl =
            'https://$_bucket.s3.$_region.amazonaws.com/$destDir/$fileName';
        print('✅ [S3] Upload successful');
        print('   Public URL: $publicUrl');
        return publicUrl;
      } else {
        print('❌ [S3] Upload failed - no result returned');
        return null;
      }
    } catch (e) {
      print('❌ [S3] Upload failed: $e');
      print('   Error type: ${e.runtimeType}');

      final errorMsg = e.toString();
      if (errorMsg.contains('NoSuchBucket')) {
        print('   ⚠️ Bucket "$_bucket" does not exist in region "$_region"');
        print('   ⚠️ Create the bucket in AWS S3 Console');
      } else if (errorMsg.contains('InvalidAccessKeyId') ||
          errorMsg.contains('403') ||
          errorMsg.contains('Access Denied')) {
        print('   ⚠️ AWS credentials invalid or insufficient permissions');
        print('   ⚠️ Check AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY');
        print('   ⚠️ IAM user needs PutObject permission on bucket "$_bucket"');
      } else if (errorMsg.contains('SignatureDoesNotMatch')) {
        print('   ⚠️ AWS secret key is incorrect');
      }
      return null;
    }
  }

  /// Delete a document image from S3
  static Future<bool> deleteDocumentImage({
    required String documentId,
  }) async {
    if (!isConfigured) return false;

    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      print('🗑️ [S3] Delete operation - images remain in S3');
      print('   ℹ️ Manual cleanup: Delete folder in S3 console');
      print('   ℹ️ Path: users/${user.uid}/documents/$documentId/');

      // aws_s3_upload_lite doesn't have a delete method
      // Images will remain in S3 but won't be linked to any document
      // You can implement lifecycle rules in S3 to auto-delete orphaned files

      return true;
    } catch (e) {
      print('❌ [S3] Delete notification failed: $e');
      return false;
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
