import 'package:firebase_auth/firebase_auth.dart';

import '../../core/config/mongodb_config.dart';
import 'hive_service.dart';
import 'mongodb_service.dart';

/// Service for clearing all user data from both local and cloud storage
/// This is a destructive operation and should require authentication
class DataClearService {
  /// Clear ALL user data from both local Hive and MongoDB
  /// This includes: folders, documents, expenses, and budget alerts
  /// NOTE: User settings (preferences, budget limits, etc.) are NOT deleted
  ///
  /// IMPORTANT: This is a destructive operation that cannot be undone!
  /// Only deletes data for the currently logged-in user (filtered by userId)
  static Future<Map<String, dynamic>> clearAllData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return {
          'success': false,
          'error': 'No user logged in',
        };
      }

      print('🗑️ [DataClear] ==========================================');
      print('🗑️ [DataClear] Starting complete data deletion');
      print('🗑️ [DataClear] User ID: ${user.uid}');
      print('🗑️ [DataClear] This will delete ALL data from local and cloud');
      print('🗑️ [DataClear] ==========================================');

      int localItemsDeleted = 0;
      int cloudItemsDeleted = 0;

      // ==========================================
      // STEP 1: Clear Local Hive Database
      // ==========================================
      print('🗑️ [DataClear] Step 1: Clearing local Hive database...');

      try {
        // Get counts before deletion
        final folderCount = HiveService.getAllFolders().length;
        final documentCount = HiveService.getAllDocuments().length;
        final expenseCount = HiveService.getAllExpenses().length;

        localItemsDeleted = folderCount + documentCount + expenseCount;

        print('🗑️ [DataClear] Local data found:');
        print('   - Folders: $folderCount');
        print('   - Documents: $documentCount');
        print('   - Expenses: $expenseCount');
        print('   - Total: $localItemsDeleted items');

        // Clear all user data from Hive
        await HiveService.clearAllData();

        print('✅ [DataClear] Local data cleared: $localItemsDeleted items');
      } catch (e) {
        print('❌ [DataClear] Error clearing local data: $e');
        return {
          'success': false,
          'error': 'Failed to clear local data: $e',
        };
      }

      // ==========================================
      // STEP 2: Clear Cloud MongoDB Database
      // ==========================================
      print('🗑️ [DataClear] Step 2: Clearing cloud MongoDB database...');

      if (!MongoDBService.isConnected) {
        print(
            '⚠️ [DataClear] MongoDB not connected - only local data was cleared');
        return {
          'success': true,
          'localItemsDeleted': localItemsDeleted,
          'cloudItemsDeleted': 0,
          'warning':
              'Cloud database not available - only local data was deleted',
        };
      }

      try {
        // Reconnect if needed (handles connection issues)
        if (!MongoDBService.isConnected) {
          print('🔄 [DataClear] Reconnecting to MongoDB...');
          await MongoDBService.init();
          if (!MongoDBService.isConnected) {
            throw Exception('Could not reconnect to MongoDB');
          }
        }

        // Delete folders from MongoDB
        final foldersCollection = await MongoDBService.getUserCollection(
            MongoDBConfig.foldersCollection);
        if (foldersCollection != null) {
          final folderResult = await foldersCollection.deleteMany({
            'userId': user.uid,
          });
          final foldersDeleted = folderResult.nRemoved;
          cloudItemsDeleted += foldersDeleted;
          print('   ✅ Deleted $foldersDeleted folders from MongoDB');
        }

        // Delete documents from MongoDB
        final documentsCollection = await MongoDBService.getUserCollection(
            MongoDBConfig.documentsCollection);
        if (documentsCollection != null) {
          final documentResult = await documentsCollection.deleteMany({
            'userId': user.uid,
          });
          final documentsDeleted = documentResult.nRemoved;
          cloudItemsDeleted += documentsDeleted;
          print('   ✅ Deleted $documentsDeleted documents from MongoDB');
        }

        // Delete expenses from MongoDB
        final expensesCollection = await MongoDBService.getUserCollection(
            MongoDBConfig.expensesCollection);
        if (expensesCollection != null) {
          final expenseResult = await expensesCollection.deleteMany({
            'userId': user.uid,
          });
          final expensesDeleted = expenseResult.nRemoved;
          cloudItemsDeleted += expensesDeleted;
          print('   ✅ Deleted $expensesDeleted expenses from MongoDB');
        }

        // NOTE: User settings are NOT deleted - they should persist
        // User preferences (budget limits, notifications, etc.) remain intact

        // Delete budget alerts from MongoDB
        final budgetAlertsCollection = await MongoDBService.getUserCollection(
            MongoDBConfig.budgetAlertsCollection);
        if (budgetAlertsCollection != null) {
          final alertsResult = await budgetAlertsCollection.deleteMany({
            'userId': user.uid,
          });
          final alertsDeleted = alertsResult.nRemoved;
          cloudItemsDeleted += alertsDeleted;
          print('   ✅ Deleted $alertsDeleted budget alerts from MongoDB');
        }

        print('✅ [DataClear] Cloud data cleared: $cloudItemsDeleted items');
      } catch (e, stackTrace) {
        print('❌ [DataClear] Error clearing cloud data: $e');
        print('   Stack trace: $stackTrace');

        // Return partial success - local data was cleared
        print(
            '⚠️ [DataClear] Returning partial success (local cleared, cloud failed)');
        return {
          'success': true, // Still success because local data was cleared
          'partialSuccess': true,
          'error': 'Cloud data deletion failed: $e',
          'localItemsDeleted': localItemsDeleted,
          'cloudItemsDeleted': 0,
          'warning':
              'Local data deleted successfully, but cloud deletion failed. You can manually delete from MongoDB or try again when connection is stable.',
        };
      }

      // ==========================================
      // STEP 3: Summary
      // ==========================================
      print('🗑️ [DataClear] ==========================================');
      print('🗑️ [DataClear] Data deletion complete!');
      print('🗑️ [DataClear] Local items deleted: $localItemsDeleted');
      print('🗑️ [DataClear] Cloud items deleted: $cloudItemsDeleted');
      print(
          '🗑️ [DataClear] Total items deleted: ${localItemsDeleted + cloudItemsDeleted}');
      print('🗑️ [DataClear] ==========================================');

      return {
        'success': true,
        'localItemsDeleted': localItemsDeleted,
        'cloudItemsDeleted': cloudItemsDeleted,
        'totalItemsDeleted': localItemsDeleted + cloudItemsDeleted,
      };
    } catch (e, stackTrace) {
      print('❌ [DataClear] Unexpected error: $e');
      print('   Stack trace: $stackTrace');
      return {
        'success': false,
        'error': 'Unexpected error: $e',
      };
    }
  }

  /// Check if user can clear data (must be logged in)
  static bool canClearData() {
    return FirebaseAuth.instance.currentUser != null;
  }

  /// Get a count of items that will be deleted
  static Map<String, int> getDataCounts() {
    try {
      return {
        'folders': HiveService.getAllFolders().length,
        'documents': HiveService.getAllDocuments().length,
        'expenses': HiveService.getAllExpenses().length,
      };
    } catch (e) {
      print('⚠️ [DataClear] Error getting data counts: $e');
      return {
        'folders': 0,
        'documents': 0,
        'expenses': 0,
      };
    }
  }
}
