import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'automated_report_service.dart';
import 'expense_sync_service.dart';
import 'mongodb_service.dart';
import 'user_settings_sync_service.dart';

/// Smart background sync service that:
/// - Syncs changes immediately when online
/// - Queues changes when offline
/// - Auto-syncs when connection is restored
/// - Prevents UI blocking by running in background
class SmartSyncService {
  static final Connectivity _connectivity = Connectivity();
  static StreamSubscription<List<ConnectivityResult>>?
      _connectivitySubscription;
  static bool _isOnline = true;
  static bool _isSyncing = false;

  // Service instances
  static final ExpenseSyncService _expenseSync = ExpenseSyncService();

  // Pending sync flags
  static bool _hasPendingExpenseSync = false;
  static bool _hasPendingSettingsSync = false;

  /// Initialize the smart sync service
  /// Call this once in main.dart after MongoDB initialization
  static Future<void> initialize() async {
    print('🔄 [SmartSync] Initializing...');

    // Check initial connectivity
    final connectivityResult = await _connectivity.checkConnectivity();
    _isOnline = !connectivityResult.contains(ConnectivityResult.none);
    print(
        '🔄 [SmartSync] Initial connectivity: ${_isOnline ? "Online" : "Offline"}');

    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
    );

    // If online and MongoDB connected, sync any pending changes
    if (_isOnline && MongoDBService.isConnected) {
      await _syncPendingChanges();
    }

    print('✅ [SmartSync] Initialized successfully');
  }

  /// Dispose the service (call when app closes)
  static Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  /// Called when connectivity changes
  static Future<void> _onConnectivityChanged(
      List<ConnectivityResult> results) async {
    final wasOnline = _isOnline;
    _isOnline = !results.contains(ConnectivityResult.none);

    print(
        '🔄 [SmartSync] Connectivity changed: ${_isOnline ? "Online" : "Offline"}');

    // If we just came back online, sync pending changes
    if (!wasOnline && _isOnline) {
      print('🔄 [SmartSync] Back online! Syncing pending changes...');
      await _syncPendingChanges();
    }
  }

  /// Sync all pending changes to MongoDB
  static Future<void> _syncPendingChanges() async {
    if (_isSyncing) {
      print('⏭️ [SmartSync] Already syncing, skipping...');
      return;
    }

    if (!MongoDBService.isConnected) {
      print('⚠️ [SmartSync] MongoDB not connected, skipping sync');
      return;
    }

    _isSyncing = true;

    try {
      // Sync expenses if pending
      if (_hasPendingExpenseSync) {
        print('📤 [SmartSync] Syncing pending expenses...');
        await _expenseSync.syncAllExpensesToMongoDB();
        _hasPendingExpenseSync = false;
        print('✅ [SmartSync] Expenses synced');
      }

      // Sync settings if pending
      if (_hasPendingSettingsSync) {
        print('📤 [SmartSync] Syncing pending settings...');
        final settings =
            await UserSettingsSyncService.downloadSettingsFromMongoDB();
        if (settings != null) {
          await UserSettingsSyncService.uploadSettingsToMongoDB(settings);
        }
        _hasPendingSettingsSync = false;
        print('✅ [SmartSync] Settings synced');
      }

      // Process pending reports (emails)
      print('📧 [SmartSync] Checking for pending reports...');
      await AutomatedReportService.processPendingReports();

      print('✅ [SmartSync] All pending changes synced');
    } catch (e) {
      print('❌ [SmartSync] Error syncing: $e');
      // Keep pending flags true so we retry later
    } finally {
      _isSyncing = false;
    }
  }

  /// Trigger expense sync (called after expense create/update/delete)
  static Future<void> syncExpenses() async {
    print('🔄 [SmartSync] Expense change detected');

    if (_isOnline && MongoDBService.isConnected && !_isSyncing) {
      // Online: Sync immediately in background
      print('📤 [SmartSync] Syncing expense immediately (background)...');
      _syncInBackground(() async {
        await _expenseSync.syncAllExpensesToMongoDB();
        print('✅ [SmartSync] Expense synced in background');
      });
    } else {
      // Offline or already syncing: Queue for later
      print('📋 [SmartSync] Queued expense sync for later (offline or busy)');
      _hasPendingExpenseSync = true;
    }
  }

  /// Trigger settings sync (called after settings/budget changes)
  static Future<void> syncSettings() async {
    print('🔄 [SmartSync] Settings change detected');

    if (_isOnline && MongoDBService.isConnected && !_isSyncing) {
      // Online: Sync immediately in background
      print('📤 [SmartSync] Syncing settings immediately (background)...');
      _syncInBackground(() async {
        final settings =
            await UserSettingsSyncService.downloadSettingsFromMongoDB();
        if (settings != null) {
          await UserSettingsSyncService.uploadSettingsToMongoDB(settings);
        }
        print('✅ [SmartSync] Settings synced in background');
      });
    } else {
      // Offline or already syncing: Queue for later
      print('📋 [SmartSync] Queued settings sync for later (offline or busy)');
      _hasPendingSettingsSync = true;
    }
  }

  /// Run sync operation in background (non-blocking)
  static void _syncInBackground(Future<void> Function() syncOperation) {
    // Run in background without awaiting
    syncOperation().catchError((error) {
      print('❌ [SmartSync] Background sync error: $error');
      // Mark as pending to retry later
      _hasPendingExpenseSync = true;
      _hasPendingSettingsSync = true;
    });
  }

  /// Manually trigger sync (for pull-to-refresh, etc.)
  static Future<void> forceSyncAll() async {
    print('🔄 [SmartSync] Force sync requested');

    if (!_isOnline) {
      print('⚠️ [SmartSync] Cannot force sync - offline');
      throw Exception('No internet connection');
    }

    if (!MongoDBService.isConnected) {
      print('⚠️ [SmartSync] Cannot force sync - MongoDB not connected');
      throw Exception('MongoDB not connected');
    }

    // Sync everything
    await _expenseSync.performFullSync();

    final settings =
        await UserSettingsSyncService.downloadSettingsFromMongoDB();
    if (settings != null) {
      await UserSettingsSyncService.uploadSettingsToMongoDB(settings);
    }

    _hasPendingExpenseSync = false;
    _hasPendingSettingsSync = false;

    print('✅ [SmartSync] Force sync completed');
  }

  /// Check if online
  static bool get isOnline => _isOnline;

  /// Check if syncing
  static bool get isSyncing => _isSyncing;

  /// Check if has pending changes
  static bool get hasPendingChanges =>
      _hasPendingExpenseSync || _hasPendingSettingsSync;
}
