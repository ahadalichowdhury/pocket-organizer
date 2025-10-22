import 'package:flutter/foundation.dart' show kIsWeb;

import '../../core/config/mongodb_config.dart';
import 'mongodb_service.dart';

/// Service for syncing user profile to MongoDB
/// Creates/updates user document in the 'users' collection
class UserSyncService {
  /// Create or update user in MongoDB after signup or login
  /// This ensures the user document exists for MongoDB triggers and queries
  static Future<bool> createOrUpdateUser({
    required String userId,
    required String email,
    String? displayName,
    String? photoUrl,
  }) async {
    if (kIsWeb) {
      print('ℹ️ [UserSync] Web platform - skipping MongoDB sync');
      return false;
    }

    try {
      print('👤 [UserSync] ==========================================');
      print('👤 [UserSync] Creating/updating user in MongoDB');
      print('👤 [UserSync] User ID: $userId');
      print('👤 [UserSync] Email: $email');
      print('👤 [UserSync] Display Name: ${displayName ?? "Not set"}');
      print('👤 [UserSync] ==========================================');

      if (!MongoDBService.isConnected) {
        print('⚠️ [UserSync] MongoDB not connected');
        return false;
      }

      final collection =
          await MongoDBService.getUserCollection(MongoDBConfig.usersCollection);
      if (collection == null) {
        print('⚠️ [UserSync] Users collection not available');
        return false;
      }

      // Check if user already exists
      final existingUser = await collection.findOne({'userId': userId});
      final now = DateTime.now().toIso8601String();

      // Use replaceOne with upsert to avoid race conditions
      // This is atomic - if multiple calls happen simultaneously, only one document is created
      final userDocument = {
        'userId': userId,
        'email': email,
        'displayName': displayName ?? email.split('@')[0],
        'photoUrl': photoUrl,
        'updatedAt': now,
      };

      // If user exists, preserve createdAt and FCM token
      if (existingUser != null) {
        print('👤 [UserSync] User exists, updating...');
        userDocument['createdAt'] = existingUser['createdAt'] ?? now;
        // Keep existing FCM token if present (don't overwrite)
        if (existingUser['fcmToken'] != null) {
          userDocument['fcmToken'] = existingUser['fcmToken'];
          userDocument['fcmTokenUpdatedAt'] = existingUser['fcmTokenUpdatedAt'];
          userDocument['platform'] = existingUser['platform'];
        }
      } else {
        print('👤 [UserSync] User does not exist, creating...');
        userDocument['createdAt'] = now;
        userDocument['fcmToken'] = null;
        userDocument['fcmTokenUpdatedAt'] = null;
        userDocument['platform'] = null;
      }

      // Atomic upsert - prevents duplicates even with concurrent calls
      await collection.replaceOne(
        {'userId': userId},
        userDocument,
        upsert: true,
      );
      print('✅ [UserSync] User saved successfully (atomic operation)');

      // Verify user was saved
      final savedUser = await collection.findOne({'userId': userId});
      if (savedUser != null) {
        print('✅ [UserSync] User verified in MongoDB');
        print('   Email: ${savedUser['email']}');
        print('   Display Name: ${savedUser['displayName']}');
        print(
            '   FCM Token: ${savedUser['fcmToken'] != null ? "Present" : "Not set yet"}');
      } else {
        print('⚠️ [UserSync] User not found after save!');
      }

      return true;
    } catch (e, stackTrace) {
      print('❌ [UserSync] Failed to create/update user: $e');
      print('   Stack trace: $stackTrace');
      return false;
    }
  }

  /// Update user's FCM token in MongoDB
  /// This is called after FCM token is obtained
  static Future<bool> updateFCMToken({
    required String userId,
    required String fcmToken,
    required String platform,
  }) async {
    if (kIsWeb) return false;

    try {
      print('📱 [UserSync] Updating FCM token for user: $userId');

      if (!MongoDBService.isConnected) {
        print('⚠️ [UserSync] MongoDB not connected');
        return false;
      }

      final collection =
          await MongoDBService.getUserCollection(MongoDBConfig.usersCollection);
      if (collection == null) {
        print('⚠️ [UserSync] Users collection not available');
        return false;
      }

      await collection.updateOne(
        {'userId': userId},
        {
          '\$set': {
            'fcmToken': fcmToken,
            'fcmTokenUpdatedAt': DateTime.now().toIso8601String(),
            'platform': platform,
          }
        },
        upsert: true,
      );

      print('✅ [UserSync] FCM token updated successfully');
      return true;
    } catch (e) {
      print('❌ [UserSync] Failed to update FCM token: $e');
      return false;
    }
  }

  /// Get user from MongoDB
  static Future<Map<String, dynamic>?> getUser(String userId) async {
    if (kIsWeb) return null;

    try {
      if (!MongoDBService.isConnected) {
        print('⚠️ [UserSync] MongoDB not connected');
        return null;
      }

      final collection =
          await MongoDBService.getUserCollection(MongoDBConfig.usersCollection);
      if (collection == null) {
        print('⚠️ [UserSync] Users collection not available');
        return null;
      }

      final user = await collection.findOne({'userId': userId});
      return user;
    } catch (e) {
      print('❌ [UserSync] Failed to get user: $e');
      return null;
    }
  }

  /// Delete user from MongoDB (called on account deletion)
  static Future<bool> deleteUser(String userId) async {
    if (kIsWeb) return false;

    try {
      print('🗑️ [UserSync] Deleting user from MongoDB: $userId');

      if (!MongoDBService.isConnected) {
        print('⚠️ [UserSync] MongoDB not connected');
        return false;
      }

      final collection =
          await MongoDBService.getUserCollection(MongoDBConfig.usersCollection);
      if (collection == null) {
        print('⚠️ [UserSync] Users collection not available');
        return false;
      }

      await collection.deleteOne({'userId': userId});

      print('✅ [UserSync] User deleted successfully');
      return true;
    } catch (e) {
      print('❌ [UserSync] Failed to delete user: $e');
      return false;
    }
  }
}
