import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:mongo_dart/mongo_dart.dart' as mongo;

import '../../core/config/mongodb_config.dart';
import '../models/folder_model.dart';
import '../services/hive_service.dart';
import 'mongodb_service.dart';

class FolderSyncService {
  /// Sync a single folder to MongoDB
  static Future<bool> syncFolderToMongoDB(FolderModel folder) async {
    if (kIsWeb) return false;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final collection = await MongoDBService.getUserCollection(
          MongoDBConfig.foldersCollection);
      if (collection == null) return false;

      final data = {
        '_id': folder.id,
        'userId': user.uid,
        'name': folder.name,
        'createdAt': folder.createdAt.toIso8601String(),
        'updatedAt': folder.updatedAt.toIso8601String(),
        'documentCount': folder.documentCount,
        'description': folder.description,
        'iconName': folder.iconName,
        'isSystemFolder': folder.isSystemFolder,
      };

      // Use a compound query with $and to ensure both conditions match
      final query = {
        '\$and': [
          {'_id': folder.id},
          {'userId': user.uid}
        ]
      };

      await collection.replaceOne(
        query,
        data,
        upsert: true,
      );

      return true;
    } catch (e) {
      print('❌ Error syncing folder to MongoDB: $e');
      return false;
    }
  }

  /// Delete a folder from MongoDB
  static Future<bool> deleteFolderFromMongoDB(String folderId) async {
    if (kIsWeb) return false;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final collection = await MongoDBService.getUserCollection(
          MongoDBConfig.foldersCollection);
      if (collection == null) return false;

      final query = {
        '\$and': [
          {'_id': folderId},
          {'userId': user.uid}
        ]
      };

      await collection.deleteOne(query);

      return true;
    } catch (e) {
      print('❌ Error deleting folder from MongoDB: $e');
      return false;
    }
  }

  /// Sync all local folders to MongoDB
  static Future<int> syncAllFoldersToMongoDB() async {
    if (kIsWeb) return 0;

    try {
      final folders = HiveService.getAllFolders();
      int synced = 0;

      for (final folder in folders) {
        final success = await syncFolderToMongoDB(folder);
        if (success) synced++;
      }

      print('✅ Synced $synced folders to MongoDB');
      return synced;
    } catch (e) {
      print('❌ Error syncing folders to MongoDB: $e');
      return 0;
    }
  }

  /// Download folders from MongoDB
  static Future<List<FolderModel>> downloadFoldersFromMongoDB() async {
    if (kIsWeb) return [];

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final collection = await MongoDBService.getUserCollection(
          MongoDBConfig.foldersCollection);
      if (collection == null) return [];

      final docs =
          await collection.find(mongo.where.eq('userId', user.uid)).toList();

      final folders = <FolderModel>[];
      for (final doc in docs) {
        try {
          folders.add(FolderModel(
            id: doc['_id'] as String,
            name: doc['name'] as String,
            createdAt: DateTime.parse(doc['createdAt'] as String),
            updatedAt: DateTime.parse(doc['updatedAt'] as String),
            documentCount: doc['documentCount'] as int? ?? 0,
            description: doc['description'] as String?,
            iconName: doc['iconName'] as String?,
            isSystemFolder: doc['isSystemFolder'] as bool? ?? false,
          ));
        } catch (e) {
          print('⚠️ Error parsing folder: $e');
        }
      }

      print('✅ Downloaded ${folders.length} folders from MongoDB');
      return folders;
    } catch (e) {
      print('❌ Error downloading folders from MongoDB: $e');
      return [];
    }
  }

  /// Perform full sync (upload local, download remote, merge without duplicates)
  static Future<bool> performFullSync() async {
    if (kIsWeb) {
      print('ℹ️ MongoDB sync not available (web)');
      return false;
    }

    try {
      print('🔄 Starting folder full sync...');

      // 1. Upload all local folders to MongoDB (upsert prevents duplicates in DB)
      await syncAllFoldersToMongoDB();

      // 2. Download all folders from MongoDB
      final remoteFolders = await downloadFoldersFromMongoDB();

      // 3. Get all local folder IDs for quick lookup
      final localFolders = HiveService.getAllFolders();
      final localFolderIds = localFolders.map((f) => f.id).toSet();

      print(
          'ℹ️ Local folders: ${localFolders.length}, Remote folders: ${remoteFolders.length}');

      // 4. Merge remote folders into local storage (avoid duplicates)
      int added = 0;
      int updated = 0;
      int skipped = 0;

      for (final remoteFolder in remoteFolders) {
        if (localFolderIds.contains(remoteFolder.id)) {
          // Folder exists locally, check if remote is newer
          final localFolder = HiveService.getFolder(remoteFolder.id);
          if (localFolder != null &&
              remoteFolder.updatedAt.isAfter(localFolder.updatedAt)) {
            await HiveService.updateFolder(remoteFolder);
            updated++;
            print('   📝 Updated: ${remoteFolder.name}');
          } else {
            skipped++;
          }
        } else {
          // New folder from server, add it locally
          await HiveService.addFolder(remoteFolder);
          added++;
          print('   ➕ Added: ${remoteFolder.name}');
        }
      }

      print('✅ Folder sync completed');
      print('   Added: $added, Updated: $updated, Skipped: $skipped');
      return true;
    } catch (e) {
      print('❌ Error during folder full sync: $e');
      return false;
    }
  }
}
