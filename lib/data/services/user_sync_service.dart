import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../core/config/mongodb_config.dart';
import 'mongodb_service.dart';

/// User Sync Service
/// Creates and updates user profile documents in MongoDB
/// This ensures the user document exists for FCM token storage and triggers
class UserSyncService {
  /// Create or update user profile in MongoDB
  /// Call this after signup or login to ensure user document exists
  static Future<bool> syncUserToMongoDB() async {
    if (kIsWeb) return false;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('⚠️ [UserSync] No user logged in');
        return false;
      }

      if (!MongoDBService.isConnected) {
        print('⚠️ [UserSync] MongoDB not connected');
        return false;
      }

      final usersCollection =
          await MongoDBService.getUserCollection(MongoDBConfig.usersCollection);
      if (usersCollection == null) {
        print('⚠️ [UserSync] Users collection not available');
        return false;
      }

      print('📤 [UserSync] Syncing user profile to MongoDB...');
      print('   User ID: ${user.uid}');
      print('   Email: ${user.email}');

      // Prepare user data
      final userData = {
        'userId': user.uid,
        'email': user.email,
        'displayName': user.displayName ?? user.email?.split('@')[0] ?? 'User',
        'emailVerified': user.emailVerified,
        'createdAt': user.metadata.creationTime?.toIso8601String() ??
            DateTime.now().toIso8601String(),
        'lastLogin': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'photoUrl': user.photoURL,
        'phoneNumber': user.phoneNumber,
      };

      // Update or insert user document
      // Use userId as the query field (not _id) for consistency with other collections
      await usersCollection.updateOne(
        {'userId': user.uid},
        {
          '\$set': userData,
          '\$setOnInsert': {
            'firstLoginAt': DateTime.now().toIso8601String(),
          }
        },
        upsert: true,
      );

      print('✅ [UserSync] User profile synced to MongoDB');

      // Verify the document was created
      final savedUser = await usersCollection.findOne({'userId': user.uid});
      if (savedUser != null) {
        print('✅ [UserSync] User document verified in MongoDB');
        if (savedUser['fcmToken'] != null) {
          print(
              '✅ [UserSync] FCM token exists: ${(savedUser['fcmToken'] as String).substring(0, 20)}...');
        } else {
          print('ℹ️ [UserSync] No FCM token yet (will be added by FCMService)');
        }
        return true;
      } else {
        print('❌ [UserSync] User document not found after save!');
        return false;
      }
    } catch (e, stackTrace) {
      print('❌ [UserSync] Failed to sync user to MongoDB: $e');
      print('   Stack trace: $stackTrace');
      return false;
    }
  }

  /// Update user's last login time
  static Future<void> updateLastLogin() async {
    if (kIsWeb) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      if (!MongoDBService.isConnected) return;

      final usersCollection =
          await MongoDBService.getUserCollection(MongoDBConfig.usersCollection);
      if (usersCollection == null) return;

      await usersCollection.updateOne(
        {'userId': user.uid},
        {
          '\$set': {'lastLogin': DateTime.now().toIso8601String()}
        },
      );

      print('✅ [UserSync] Last login updated');
    } catch (e) {
      print('❌ [UserSync] Failed to update last login: $e');
    }
  }

  /// Delete user profile from MongoDB (call on account deletion)
  static Future<bool> deleteUserFromMongoDB(String userId) async {
    if (kIsWeb) return false;

    try {
      if (!MongoDBService.isConnected) {
        print('⚠️ [UserSync] MongoDB not connected');
        return false;
      }

      final usersCollection =
          await MongoDBService.getUserCollection(MongoDBConfig.usersCollection);
      if (usersCollection == null) return false;

      await usersCollection.deleteOne({'userId': userId});

      print('✅ [UserSync] User profile deleted from MongoDB');
      return true;
    } catch (e) {
      print('❌ [UserSync] Failed to delete user from MongoDB: $e');
      return false;
    }
  }

  /// Get user profile from MongoDB
  static Future<Map<String, dynamic>?> getUserProfile() async {
    if (kIsWeb) return null;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      if (!MongoDBService.isConnected) return null;

      final usersCollection =
          await MongoDBService.getUserCollection(MongoDBConfig.usersCollection);
      if (usersCollection == null) return null;

      final userDoc = await usersCollection.findOne({'userId': user.uid});
      return userDoc;
    } catch (e) {
      print('❌ [UserSync] Failed to get user profile: $e');
      return null;
    }
  }

  /// Update user profile fields
  static Future<bool> updateUserProfile({
    String? displayName,
    String? photoUrl,
    String? phoneNumber,
  }) async {
    if (kIsWeb) return false;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      if (!MongoDBService.isConnected) return false;

      final usersCollection =
          await MongoDBService.getUserCollection(MongoDBConfig.usersCollection);
      if (usersCollection == null) return false;

      final updates = <String, dynamic>{
        'updatedAt': DateTime.now().toIso8601String(),
      };

      if (displayName != null) updates['displayName'] = displayName;
      if (photoUrl != null) updates['photoUrl'] = photoUrl;
      if (phoneNumber != null) updates['phoneNumber'] = phoneNumber;

      await usersCollection.updateOne(
        {'userId': user.uid},
        {'\$set': updates},
      );

      print('✅ [UserSync] User profile updated');
      return true;
    } catch (e) {
      print('❌ [UserSync] Failed to update user profile: $e');
      return false;
    }
  }
}
