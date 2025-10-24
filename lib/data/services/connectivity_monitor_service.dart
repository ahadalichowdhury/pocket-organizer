import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'automated_report_service.dart';
import 'document_sync_service.dart';
import 'expense_sync_service.dart';
import 'folder_sync_service.dart';
import 'hive_service.dart';
import 'user_settings_sync_service.dart';

/// Service to monitor connectivity changes and trigger auto-sync when coming online
class ConnectivityMonitorService {
  static StreamSubscription<List<ConnectivityResult>>? _subscription;
  static bool _wasOffline = false;
  static bool _isSyncing = false;
  static DateTime? _lastAutoSyncAttempt;

  /// Start monitoring connectivity changes
  static void startMonitoring() {
    print('📡 [ConnectivityMonitor] Starting connectivity monitoring...');

    // Cancel existing subscription if any
    _subscription?.cancel();

    final connectivity = Connectivity();

    // Listen to connectivity changes
    _subscription = connectivity.onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) async {
      await _handleConnectivityChange(results);
    });

    print('✅ [ConnectivityMonitor] Monitoring started');
  }

  /// Stop monitoring connectivity changes
  static void stopMonitoring() {
    print('🛑 [ConnectivityMonitor] Stopping connectivity monitoring...');
    _subscription?.cancel();
    _subscription = null;
  }

  /// Handle connectivity change event
  static Future<void> _handleConnectivityChange(
    List<ConnectivityResult> results,
  ) async {
    try {
      final isConnected = results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.mobile);

      final connectionType = results.contains(ConnectivityResult.wifi)
          ? 'WiFi'
          : results.contains(ConnectivityResult.mobile)
              ? 'Mobile Data'
              : 'Offline';

      print('📡 [ConnectivityMonitor] Connectivity changed: $connectionType');

      // If coming online from offline state
      if (isConnected && _wasOffline) {
        print('✅ [ConnectivityMonitor] Device came online!');
        await _onComeOnline(connectionType);
      }

      // Update offline state
      _wasOffline = !isConnected;
    } catch (e) {
      print('❌ [ConnectivityMonitor] Error handling connectivity change: $e');
    }
  }

  /// Called when device comes online after being offline
  static Future<void> _onComeOnline(String connectionType) async {
    try {
      // Check if user is logged in
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('⚠️ [ConnectivityMonitor] No user logged in, skipping auto-sync');
        return;
      }

      // Check WiFi-only setting
      final wifiOnlyMode =
          HiveService.getSetting('sync_on_wifi_only', defaultValue: true)
              as bool;
      if (wifiOnlyMode && connectionType != 'WiFi') {
        print(
            '⚠️ [ConnectivityMonitor] WiFi-only mode is enabled, but connected to $connectionType');
        return;
      }

      // 1. FIRST: Process any pending email reports
      print('📧 [ConnectivityMonitor] Processing pending email reports...');
      try {
        await AutomatedReportService.processPendingReports();
      } catch (e) {
        print('❌ [ConnectivityMonitor] Failed to process pending reports: $e');
      }

      // 2. SECOND: Check if auto-sync is enabled and perform sync
      final autoSyncEnabled =
          HiveService.getSetting('auto_sync_enabled', defaultValue: false)
              as bool;
      if (!autoSyncEnabled) {
        print('ℹ️ [ConnectivityMonitor] Auto-sync is disabled, skipping sync');
        return;
      }

      // Rate limiting - don't sync more than once every 5 minutes
      if (_lastAutoSyncAttempt != null) {
        final timeSinceLastSync =
            DateTime.now().difference(_lastAutoSyncAttempt!);
        if (timeSinceLastSync.inMinutes < 5) {
          print(
              '⏳ [ConnectivityMonitor] Skipping sync - last attempt was ${timeSinceLastSync.inMinutes} minutes ago');
          return;
        }
      }

      // Prevent concurrent syncs
      if (_isSyncing) {
        print('⏳ [ConnectivityMonitor] Sync already in progress');
        return;
      }

      print('🔄 [ConnectivityMonitor] Triggering smart retry sync...');
      _isSyncing = true;
      _lastAutoSyncAttempt = DateTime.now();

      // Perform sync
      await _performSmartRetrySync(user.uid);

      _isSyncing = false;
    } catch (e) {
      print('❌ [ConnectivityMonitor] Error in onComeOnline: $e');
      _isSyncing = false;
    }
  }

  /// Perform a smart retry sync (only syncs if there's been changes since last sync)
  static Future<void> _performSmartRetrySync(String userId) async {
    try {
      print('☁️ [SmartRetry] Starting smart retry sync...');

      // Get last sync time
      final lastSyncMillis =
          HiveService.getSetting('last_sync_time', defaultValue: 0) as int;
      final lastSyncTime = lastSyncMillis > 0
          ? DateTime.fromMillisecondsSinceEpoch(lastSyncMillis)
          : null;

      if (lastSyncTime != null) {
        final hoursSinceLastSync =
            DateTime.now().difference(lastSyncTime).inHours;
        print('ℹ️ [SmartRetry] Last sync was $hoursSinceLastSync hours ago');
      } else {
        print('ℹ️ [SmartRetry] No previous sync found');
      }

      // Perform FULL SYNC (upload + download)
      print('📤 [SmartRetry] Syncing folders...');
      await FolderSyncService.performFullSync();

      print('📤 [SmartRetry] Syncing documents...');
      await DocumentSyncService.performFullSync();

      print('📤 [SmartRetry] Syncing expenses...');
      await ExpenseSyncService().performFullSync();

      // Update sync time
      final syncTime = DateTime.now();
      await HiveService.saveSetting(
          'last_sync_time', syncTime.millisecondsSinceEpoch);

      await UserSettingsSyncService.updateSetting(
        userId: userId,
        lastSyncTime: syncTime,
      );

      print('✅ [SmartRetry] Smart retry sync complete!');
    } catch (e) {
      print('❌ [SmartRetry] Sync failed: $e');
      throw e;
    }
  }

  /// Manual trigger for testing
  static Future<void> triggerManualRetry() async {
    print('🔧 [ConnectivityMonitor] Manual retry triggered');
    _wasOffline = true; // Simulate coming online
    await _handleConnectivityChange([ConnectivityResult.wifi]);
  }
}
