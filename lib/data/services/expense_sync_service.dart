import 'package:firebase_auth/firebase_auth.dart';
import 'package:mongo_dart/mongo_dart.dart';

import '../../core/config/mongodb_config.dart';
import '../models/expense_model.dart';
import 'hive_service.dart';
import 'mongodb_service.dart';

/// Expense sync service using MongoDB instead of Firebase Firestore
/// Much more reliable and flexible than Firestore
class ExpenseSyncService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get the expenses collection for the current user
  Future<DbCollection?> _getExpensesCollection() async {
    return await MongoDBService.getUserCollection(
        MongoDBConfig.expensesCollection);
  }

  /// Sync local expense to MongoDB
  Future<void> syncExpenseToMongoDB(ExpenseModel expense) async {
    try {
      final collection = await _getExpensesCollection();
      if (collection == null) {
        print('⚠️ [ExpenseSync] MongoDB not available or user not logged in');
        return;
      }

      final user = _auth.currentUser;
      if (user == null) {
        print('⚠️ [ExpenseSync] No user logged in');
        return;
      }

      // Prepare data for MongoDB
      final data = {
        '_id': expense.id, // Use expense ID as MongoDB _id
        'userId': user.uid,
        'amount': expense.amount,
        'category': expense.category,
        'paymentMethod': expense.paymentMethod,
        'date': expense.date.toIso8601String(),
        'createdAt': expense.createdAt.toIso8601String(),
        'updatedAt': expense.updatedAt.toIso8601String(),
        'tags': expense.tags,
        'isRecurring': expense.isRecurring,
      };

      // Only add optional fields if they're not null
      if (expense.note != null && expense.note!.isNotEmpty) {
        data['note'] = expense.note!;
      }
      if (expense.linkedDocumentId != null &&
          expense.linkedDocumentId!.isNotEmpty) {
        data['linkedDocumentId'] = expense.linkedDocumentId!;
      }
      if (expense.storeName != null && expense.storeName!.isNotEmpty) {
        data['storeName'] = expense.storeName!;
      }
      if (expense.recurringPeriod != null &&
          expense.recurringPeriod!.isNotEmpty) {
        data['recurringPeriod'] = expense.recurringPeriod!;
      }

      print('📤 [ExpenseSync] Uploading expense ${expense.id} to MongoDB...');

      // Use a compound query with $and to ensure both conditions match
      final query = {
        '\$and': [
          {'_id': expense.id},
          {'userId': user.uid}
        ]
      };

      await collection.replaceOne(
        query,
        data,
        upsert: true,
      );

      print('✅ [ExpenseSync] Synced expense ${expense.id} to MongoDB');
    } catch (e, stackTrace) {
      print('❌ [ExpenseSync] Error syncing expense to MongoDB: $e');
      print('Stack trace: $stackTrace');
      // Don't throw - allow app to continue in local-only mode
    }
  }

  /// Delete expense from MongoDB
  Future<void> deleteExpenseFromMongoDB(String expenseId) async {
    try {
      final collection = await _getExpensesCollection();
      if (collection == null) return;

      final user = _auth.currentUser;
      if (user == null) return;

      final query = {
        '\$and': [
          {'_id': expenseId},
          {'userId': user.uid}
        ]
      };

      await collection.deleteOne(query);

      print('✅ [ExpenseSync] Deleted expense $expenseId from MongoDB');
    } catch (e) {
      print('❌ [ExpenseSync] Error deleting expense from MongoDB: $e');
    }
  }

  /// Sync all local expenses to MongoDB
  Future<void> syncAllExpensesToMongoDB() async {
    try {
      final collection = await _getExpensesCollection();
      if (collection == null) {
        print('⚠️ [ExpenseSync] MongoDB not available, skipping upload');
        return;
      }

      final localExpenses = HiveService.getAllExpenses();
      print(
          '📤 [ExpenseSync] Syncing ${localExpenses.length} expenses to MongoDB...');

      for (final expense in localExpenses) {
        await syncExpenseToMongoDB(expense);
      }

      print('✅ [ExpenseSync] All expenses synced to MongoDB');
    } catch (e) {
      print('❌ [ExpenseSync] Error syncing all expenses: $e');
    }
  }

  /// Download all expenses from MongoDB to local storage
  Future<void> downloadExpensesFromMongoDB() async {
    try {
      final collection = await _getExpensesCollection();
      if (collection == null) {
        print(
            '⚠️ [ExpenseSync] MongoDB not available, cannot download expenses');
        return;
      }

      final user = _auth.currentUser;
      if (user == null) {
        print('⚠️ [ExpenseSync] No user logged in');
        return;
      }

      print('📥 [ExpenseSync] Downloading expenses from MongoDB...');

      // Query expenses for current user
      final cursor = collection.find(where.eq('userId', user.uid));
      final documents = await cursor.toList();

      int newCount = 0;
      int updatedCount = 0;

      for (final doc in documents) {
        try {
          final expense = ExpenseModel(
            id: doc['_id'] as String,
            amount: (doc['amount'] as num).toDouble(),
            category: doc['category'] as String,
            paymentMethod: doc['paymentMethod'] as String,
            date: DateTime.parse(doc['date'] as String),
            createdAt: DateTime.parse(doc['createdAt'] as String),
            updatedAt: DateTime.parse(doc['updatedAt'] as String),
            note: doc['note'] as String?,
            linkedDocumentId: doc['linkedDocumentId'] as String?,
            storeName: doc['storeName'] as String?,
            tags: List<String>.from(doc['tags'] ?? []),
            isRecurring: doc['isRecurring'] as bool? ?? false,
            recurringPeriod: doc['recurringPeriod'] as String?,
          );

          // Check if expense exists locally
          final localExpense = HiveService.getExpense(expense.id);
          if (localExpense == null) {
            await HiveService.addExpense(expense);
            newCount++;
          } else {
            // Update if MongoDB version is newer
            if (expense.updatedAt.isAfter(localExpense.updatedAt)) {
              await HiveService.updateExpense(expense);
              updatedCount++;
            }
          }
        } catch (e) {
          print('⚠️ [ExpenseSync] Error parsing expense: $e');
          continue;
        }
      }

      print(
          '✅ [ExpenseSync] Download complete: $newCount new, $updatedCount updated');
    } catch (e, stackTrace) {
      print('❌ [ExpenseSync] Error downloading expenses: $e');
      print('Stack trace: $stackTrace');
    }
  }

  /// Perform full sync (upload local changes, then download remote changes)
  Future<void> performFullSync() async {
    try {
      print('🔄 [ExpenseSync] Starting full MongoDB sync...');

      // Check if MongoDB is available
      if (!MongoDBService.isConnected) {
        print(
            '⚠️ [ExpenseSync] MongoDB not connected, working in local-only mode');
        return;
      }

      // First, upload all local expenses
      await syncAllExpensesToMongoDB();

      // Then, download any new expenses from MongoDB
      await downloadExpensesFromMongoDB();

      // Save last sync time
      await HiveService.saveSetting(
          'last_expense_sync_time', DateTime.now().millisecondsSinceEpoch);

      print('✅ [ExpenseSync] Full MongoDB sync complete');
    } catch (e) {
      print('❌ [ExpenseSync] Error during full sync: $e');
      // Don't rethrow - allow app to work in local-only mode
    }
  }

  /// Get last sync time
  DateTime? getLastSyncTime() {
    final timestamp =
        HiveService.getSetting('last_expense_sync_time', defaultValue: 0)
            as int;
    if (timestamp == 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }
}
