import 'dart:io';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Script to remove duplicate folders from MongoDB
/// This script identifies duplicate folders based on userId + name
/// and keeps only the most recently updated one.
Future<void> main() async {
  print('🔧 MongoDB Duplicate Folder Removal Script');
  print('==========================================\n');

  // Load environment variables
  try {
    await dotenv.load(fileName: '.env');
    print('✅ Loaded .env file');
  } catch (e) {
    print('❌ Error loading .env file: $e');
    exit(1);
  }

  // Get MongoDB connection string
  final mongoUri = dotenv.env['MONGODB_CONNECTION_STRING'];
  final dbName = dotenv.env['MONGODB_DATABASE_NAME'] ?? 'pocket_organizer';

  if (mongoUri == null || mongoUri.isEmpty) {
    print('❌ MONGODB_CONNECTION_STRING not found in .env');
    exit(1);
  }

  Db? db;
  try {
    // Connect to MongoDB
    print('🔌 Connecting to MongoDB...');
    db = await Db.create(mongoUri);
    await db.open();
    print('✅ Connected to MongoDB\n');

    // Get folders collection
    final collection = db.collection('$dbName.folders');

    // Find all folders
    print('📂 Fetching all folders...');
    final allFolders = await collection.find().toList();
    print('   Found ${allFolders.length} folders\n');

    if (allFolders.isEmpty) {
      print('ℹ️  No folders found in database');
      return;
    }

    // Group folders by userId + name
    final Map<String, List<Map<String, dynamic>>> groupedFolders = {};
    
    for (var folder in allFolders) {
      final userId = folder['userId'] as String?;
      final name = folder['name'] as String?;
      
      if (userId == null || name == null) {
        print('⚠️  Skipping folder with missing userId or name: ${folder['_id']}');
        continue;
      }

      final key = '$userId|$name';
      groupedFolders.putIfAbsent(key, () => []);
      groupedFolders[key]!.add(folder);
    }

    // Find and remove duplicates
    int duplicatesFound = 0;
    int duplicatesRemoved = 0;
    int errors = 0;

    print('🔍 Searching for duplicates...\n');

    for (var entry in groupedFolders.entries) {
      final key = entry.key;
      final folders = entry.value;
      
      if (folders.length > 1) {
        duplicatesFound++;
        final parts = key.split('|');
        final userId = parts[0];
        final name = parts[1];
        
        print('📋 Found ${folders.length} duplicates for user: $userId, folder: "$name"');
        
        // Sort by updatedAt (most recent first)
        folders.sort((a, b) {
          final aUpdated = a['updatedAt'] as DateTime?;
          final bUpdated = b['updatedAt'] as DateTime?;
          
          if (aUpdated == null && bUpdated == null) return 0;
          if (aUpdated == null) return 1;
          if (bUpdated == null) return -1;
          
          return bUpdated.compareTo(aUpdated);
        });

        // Keep the first (most recent), delete the rest
        final toKeep = folders.first;
        final toDelete = folders.skip(1).toList();

        print('   ✓ Keeping: ${toKeep['_id']} (updated: ${toKeep['updatedAt']})');
        
        for (var duplicate in toDelete) {
          try {
            final result = await collection.deleteOne(where.eq('_id', duplicate['_id']));
            if (result.isSuccess) {
              duplicatesRemoved++;
              print('   ✗ Deleted: ${duplicate['_id']} (updated: ${duplicate['updatedAt']})');
            } else {
              errors++;
              print('   ❌ Failed to delete: ${duplicate['_id']}');
            }
          } catch (e) {
            errors++;
            print('   ❌ Error deleting ${duplicate['_id']}: $e');
          }
        }
        print('');
      }
    }

    // Print summary
    print('📊 Summary');
    print('==========================================');
    print('Total folders: ${allFolders.length}');
    print('Duplicate groups found: $duplicatesFound');
    print('Duplicates removed: $duplicatesRemoved');
    if (errors > 0) {
      print('⚠️  Errors encountered: $errors');
    }
    print('✅ Cleanup complete!\n');

  } catch (e) {
    print('❌ Error: $e');
    exit(1);
  } finally {
    // Close database connection
    if (db != null && db.isConnected) {
      await db.close();
      print('🔌 Disconnected from MongoDB');
    }
  }
}






