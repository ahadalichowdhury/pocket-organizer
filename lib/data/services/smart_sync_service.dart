import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import 'automated_report_service.dart';
import 'document_sync_service.dart';
import 'expense_sync_service.dart';
import 'folder_sync_service.dart';
import 'hive_service.dart';
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

  // Notifier for last sync time updates (so UI can react)
  static final ValueNotifier<int> lastSyncTimeNotifier = ValueNotifier<int>(0);

  // Service instances
  static final ExpenseSyncService _expenseSync = ExpenseSyncService();

  // Pending sync flags
  static bool _hasPendingExpenseSync = false;
  static bool _hasPendingDocumentSync = false;
  static bool _hasPendingFolderSync = false;
  static bool _hasPendingSettingsSync = false;

  // Track active background syncs
  static Future<void>? _activeExpenseSync;
  static Future<void>? _activeDocumentSync;
  static Future<void>? _activeFolderSync;
  static Future<void>? _activeSettingsSync;

  /// Initialize the smart sync service
  /// Call this once in main.dart after MongoDB initialization
  static Future<void> initialize() async {
    print('🔄 [SmartSync] Initializing...');

    // Initialize the last sync time notifier from Hive
    final savedTime =
        HiveService.getSetting('last_sync_time', defaultValue: 0) as int;
    lastSyncTimeNotifier.value = savedTime;
    print('🕐 [SmartSync] Loaded last sync time from Hive:');
    print('   📝 Timestamp: $savedTime');
    if (savedTime > 0) {
      print(
          '   📝 DateTime: ${DateTime.fromMillisecondsSinceEpoch(savedTime)}');
    }
    print('   📝 Notifier value set to: ${lastSyncTimeNotifier.value}');

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

      // Track the active sync so logout can wait for it
      _activeExpenseSync = _expenseSync.syncAllExpensesToMongoDB().then((_) {
        print('✅ [SmartSync] Expense synced in background');
        _updateLastSyncTime(); // Update last sync timestamp
        _activeExpenseSync = null; // Clear after completion
      }).catchError((error) {
        print('❌ [SmartSync] Background sync error: $error');
        _hasPendingExpenseSync = true; // Mark as pending to retry
        _activeExpenseSync = null;
      });
    } else {
      // Offline or already syncing: Queue for later
      print('📋 [SmartSync] Queued expense sync for later (offline or busy)');
      _hasPendingExpenseSync = true;
    }
  }

  /// Trigger document sync (called after document create/update/delete)
  static Future<void> syncDocuments() async {
    print('🔄 [SmartSync] Document change detected');

    if (_isOnline && MongoDBService.isConnected && !_isSyncing) {
      // Online: Sync immediately in background
      print('📤 [SmartSync] Syncing document immediately (background)...');

      // Track the active sync so logout can wait for it
      _activeDocumentSync = DocumentSyncService.performFullSync().then((_) {
        print('✅ [SmartSync] Document synced in background');
        _updateLastSyncTime(); // Update last sync timestamp
        _activeDocumentSync = null; // Clear after completion
      }).catchError((error) {
        print('❌ [SmartSync] Background sync error: $error');
        _hasPendingDocumentSync = true; // Mark as pending to retry
        _activeDocumentSync = null;
      });
    } else {
      // Offline or already syncing: Queue for later
      print('📋 [SmartSync] Queued document sync for later (offline or busy)');
      _hasPendingDocumentSync = true;
    }
  }

  /// Trigger folder sync (called after folder create/update/delete)
  static Future<void> syncFolders() async {
    print('🔄 [SmartSync] Folder change detected');

    if (_isOnline && MongoDBService.isConnected && !_isSyncing) {
      // Online: Sync immediately in background
      print('📤 [SmartSync] Syncing folder immediately (background)...');

      // Track the active sync so logout can wait for it
      _activeFolderSync = FolderSyncService.performFullSync().then((_) {
        print('✅ [SmartSync] Folder synced in background');
        _updateLastSyncTime(); // Update last sync timestamp
        _activeFolderSync = null; // Clear after completion
      }).catchError((error) {
        print('❌ [SmartSync] Background sync error: $error');
        _hasPendingFolderSync = true; // Mark as pending to retry
        _activeFolderSync = null;
      });
    } else {
      // Offline or already syncing: Queue for later
      print('📋 [SmartSync] Queued folder sync for later (offline or busy)');
      _hasPendingFolderSync = true;
    }
  }

  /// Trigger settings sync (called after settings/budget changes)
  static Future<void> syncSettings() async {
    print('🔄 [SmartSync] Settings change detected');

    if (_isOnline && MongoDBService.isConnected && !_isSyncing) {
      // Online: Sync immediately in background
      print('📤 [SmartSync] Syncing settings immediately (background)...');

      // Track the active sync so logout can wait for it
      _activeSettingsSync = Future(() async {
        final settings =
            await UserSettingsSyncService.downloadSettingsFromMongoDB();
        if (settings != null) {
          await UserSettingsSyncService.uploadSettingsToMongoDB(settings);
        }
      }).then((_) {
        print('✅ [SmartSync] Settings synced in background');
        _updateLastSyncTime(); // Update last sync timestamp
        _activeSettingsSync = null; // Clear after completion
      }).catchError((error) {
        print('❌ [SmartSync] Background sync error: $error');
        _hasPendingSettingsSync = true; // Mark as pending to retry
        _activeSettingsSync = null;
      });
    } else {
      // Offline or already syncing: Queue for later
      print('📋 [SmartSync] Queued settings sync for later (offline or busy)');
      _hasPendingSettingsSync = true;
    }
  }

  /// Update last sync timestamp in Hive
  static void _updateLastSyncTime() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    HiveService.saveSetting('last_sync_time', timestamp);

    print('🕐 [SmartSync] Updating last sync time...');
    print('   📝 Timestamp: $timestamp');
    print('   📝 DateTime: ${DateTime.fromMillisecondsSinceEpoch(timestamp)}');
    print('   📝 Old notifier value: ${lastSyncTimeNotifier.value}');

    lastSyncTimeNotifier.value = timestamp; // Notify UI listeners

    print('   ✅ New notifier value: ${lastSyncTimeNotifier.value}');
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

  /// Wait for any active background syncs to complete (for logout)
  static Future<void> waitForActiveSyncs({int timeoutSeconds = 10}) async {
    print('⏳ [SmartSync] Waiting for active background syncs...');

    final futures = <Future<void>>[];

    if (_activeExpenseSync != null) {
      print('   📤 Waiting for expense sync...');
      futures.add(_activeExpenseSync!);
    }

    if (_activeDocumentSync != null) {
      print('   📤 Waiting for document sync...');
      futures.add(_activeDocumentSync!);
    }

    if (_activeFolderSync != null) {
      print('   📤 Waiting for folder sync...');
      futures.add(_activeFolderSync!);
    }

    if (_activeSettingsSync != null) {
      print('   📤 Waiting for settings sync...');
      futures.add(_activeSettingsSync!);
    }

    if (futures.isEmpty) {
      print('✅ [SmartSync] No active syncs to wait for');
      return;
    }

    try {
      // Wait for all syncs with timeout
      await Future.wait(futures).timeout(
        Duration(seconds: timeoutSeconds),
        onTimeout: () {
          print('⏰ [SmartSync] Timeout waiting for syncs');
          throw TimeoutException('Sync timeout');
        },
      );
      print('✅ [SmartSync] All active syncs completed');
    } catch (e) {
      print('⚠️ [SmartSync] Error waiting for syncs: $e');
      // Continue anyway, syncs will be pending
    }
  }

  /// Check if online
  static bool get isOnline => _isOnline;

  /// Check if syncing
  static bool get isSyncing => _isSyncing;

  /// Check if has pending changes
  static bool get hasPendingChanges =>
      _hasPendingExpenseSync ||
      _hasPendingDocumentSync ||
      _hasPendingFolderSync ||
      _hasPendingSettingsSync;
}
