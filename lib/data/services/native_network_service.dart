import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

import 'automated_report_service.dart';
import 'document_sync_service.dart';
import 'expense_sync_service.dart';
import 'folder_sync_service.dart';
import 'hive_service.dart';

/// Native network monitoring service
/// This receives callbacks from native Android BroadcastReceiver
/// Similar to how WhatsApp monitors network changes
///
/// NOW WITH ALARMMANAGER-BASED SCHEDULING!
/// Can work even when app is killed (like WhatsApp)
class NativeNetworkService {
  static const MethodChannel _channel =
      MethodChannel('com.example.pocket_organizer/network');

  static const MethodChannel _serviceChannel =
      MethodChannel('com.example.pocket_organizer/service');

  static const MethodChannel _alarmChannel =
      MethodChannel('com.example.pocket_organizer/alarm');

  static const MethodChannel _progressChannel =
      MethodChannel('com.example.pocket_organizer/progress');

  /// Initialize native network monitoring
  static Future<void> initialize() async {
    try {
      print('📡 [NativeNetwork] Setting up native network monitoring...');
      print('📡 [NativeNetwork] This uses native Android BroadcastReceiver');
      print('📡 [NativeNetwork] Similar to WhatsApp\'s WiFi monitoring');

      // Set up method call handler to receive callbacks from native code
      _channel.setMethodCallHandler(_handleMethodCall);

      print('✅ [NativeNetwork] Native network monitoring initialized');
    } catch (e) {
      print('❌ [NativeNetwork] Failed to initialize: $e');
    }
  }

  /// Schedule periodic backup using native AlarmManager (like WhatsApp)
  static Future<void> schedulePeriodicBackup(int intervalMinutes) async {
    try {
      print('⏰ [NativeNetwork] Scheduling periodic backup via AlarmManager...');
      print('⏰ [NativeNetwork] Interval: $intervalMinutes minutes');
      print('⏰ [NativeNetwork] This uses native AlarmManager (like WhatsApp)');

      await _alarmChannel.invokeMethod('schedulePeriodicBackup', {
        'intervalMinutes': intervalMinutes,
      });

      print('✅ [NativeNetwork] Periodic backup scheduled successfully!');
      print('💡 [NativeNetwork] Will trigger even if app is killed');
    } catch (e) {
      print('❌ [NativeNetwork] Failed to schedule periodic backup: $e');
      rethrow;
    }
  }

  /// Cancel periodic backup
  static Future<void> cancelPeriodicBackup() async {
    try {
      print('🛑 [NativeNetwork] Cancelling periodic backup...');

      await _alarmChannel.invokeMethod('cancelPeriodicBackup');

      print('✅ [NativeNetwork] Periodic backup cancelled');
    } catch (e) {
      print('❌ [NativeNetwork] Failed to cancel periodic backup: $e');
      rethrow;
    }
  }

  /// Schedule daily email report using native AlarmManager (like WhatsApp)
  static Future<void> scheduleDailyEmailReport(
      {int hour = 11, int minute = 0}) async {
    try {
      print(
          '📧 [NativeNetwork] Scheduling daily email report via AlarmManager...');
      print(
          '📧 [NativeNetwork] Time: ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}');
      print('📧 [NativeNetwork] This uses native AlarmManager (like WhatsApp)');

      await _alarmChannel.invokeMethod('scheduleDailyEmailReport', {
        'hour': hour,
        'minute': minute,
      });

      print('✅ [NativeNetwork] Daily email report scheduled successfully!');
      print('💡 [NativeNetwork] Will trigger even if app is killed');
    } catch (e) {
      print('❌ [NativeNetwork] Failed to schedule daily email report: $e');
      rethrow;
    }
  }

  /// Cancel daily email report
  static Future<void> cancelDailyEmailReport() async {
    try {
      print('🛑 [NativeNetwork] Cancelling daily email report...');

      await _alarmChannel.invokeMethod('cancelDailyEmailReport');

      print('✅ [NativeNetwork] Daily email report cancelled');
    } catch (e) {
      print('❌ [NativeNetwork] Failed to cancel daily email report: $e');
      rethrow;
    }
  }

  /// Start foreground service for background monitoring
  /// This keeps the app alive even when killed (like WhatsApp)
  static Future<void> startForegroundService() async {
    try {
      print('🚀 [NativeNetwork] Starting foreground service...');
      print('📱 [NativeNetwork] This will show a persistent notification');
      print('🔄 [NativeNetwork] Service will run even when app is killed');

      await _serviceChannel.invokeMethod('startForegroundService');

      // Save state
      await HiveService.saveSetting('foreground_service_enabled', true);

      print('✅ [NativeNetwork] Foreground service started!');
      print(
          '💡 [NativeNetwork] You can now close the app - service keeps running');
    } catch (e) {
      print('❌ [NativeNetwork] Failed to start foreground service: $e');
      rethrow;
    }
  }

  /// Stop foreground service
  static Future<void> stopForegroundService() async {
    try {
      print('🛑 [NativeNetwork] Stopping foreground service...');

      await _serviceChannel.invokeMethod('stopForegroundService');

      // Save state
      await HiveService.saveSetting('foreground_service_enabled', false);

      print('✅ [NativeNetwork] Foreground service stopped');
    } catch (e) {
      print('❌ [NativeNetwork] Failed to stop foreground service: $e');
      rethrow;
    }
  }

  /// Check if foreground service is running
  static Future<bool> isForegroundServiceRunning() async {
    try {
      final result =
          await _serviceChannel.invokeMethod<bool>('isServiceRunning');
      return result ?? false;
    } catch (e) {
      print('❌ [NativeNetwork] Failed to check service status: $e');
      return false;
    }
  }

  /// Handle method calls from native Android code
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    print('📱 [NativeNetwork] Received native callback: ${call.method}');

    switch (call.method) {
      case 'onWiFiConnected':
        await _onWiFiConnected();
        break;
      case 'onDailyEmailReport':
        await _onDailyEmailReport();
        break;
      default:
        print('⚠️ [NativeNetwork] Unknown method: ${call.method}');
    }
  }

  /// Called when WiFi connection is detected by native Android code
  static Future<void> _onWiFiConnected() async {
    print('📡 [NativeNetwork] ==========================================');
    print('📡 [NativeNetwork] WiFi CONNECTED - Native callback received!');
    print('📡 [NativeNetwork] ==========================================');

    try {
      // Check if user boxes are open (prevent race condition during app startup)
      if (HiveService.currentUserId == null) {
        print('⚠️ [NativeNetwork] User not logged in yet, skipping backup');
        return;
      }

      // Check if auto-sync is enabled
      final autoSyncEnabled =
          HiveService.getSetting('auto_sync_enabled', defaultValue: false)
              as bool;

      if (!autoSyncEnabled) {
        print('ℹ️ [NativeNetwork] Auto-sync is disabled, skipping');
        return;
      }

      print('✅ [NativeNetwork] Auto-sync is enabled, starting backup...');

      // 1. Process pending email reports
      print('📧 [NativeNetwork] Processing pending email reports...');
      try {
        await AutomatedReportService.processPendingReports();
      } catch (e) {
        print('❌ [NativeNetwork] Failed to process pending reports: $e');
      }

      // 2. Perform auto-sync
      print('☁️ [NativeNetwork] Starting auto-sync...');
      await _performSync();

      print('✅ [NativeNetwork] WiFi-triggered sync complete!');
    } catch (e) {
      print('❌ [NativeNetwork] Error during WiFi sync: $e');
    }
  }

  /// Perform sync (same logic as manual backup)
  static Future<void> _performSync() async {
    try {
      // Show backup started notification (like WhatsApp)
      await _progressChannel.invokeMethod('showBackupStarted');
      print('📱 [NativeNetwork] Progress notification shown');

      int totalItemsSynced = 0;

      // 1. Sync folders
      print('☁️ [NativeNetwork] Syncing folders...');
      final folderCount = await FolderSyncService.syncAllFoldersToMongoDB();
      totalItemsSynced += folderCount;

      // Update progress: Folders complete
      await _progressChannel.invokeMethod('updateProgress', {
        'title': 'folders',
        'current': folderCount,
        'total': folderCount,
      });

      // 2. Sync documents
      print('☁️ [NativeNetwork] Syncing documents...');
      final documentCount =
          await DocumentSyncService.syncAllDocumentsToMongoDB();
      totalItemsSynced += documentCount;

      // Update progress: Documents complete
      await _progressChannel.invokeMethod('updateProgress', {
        'title': 'documents',
        'current': documentCount,
        'total': documentCount,
      });

      // 3. Sync expenses
      print('☁️ [NativeNetwork] Syncing expenses...');
      await ExpenseSyncService().syncAllExpensesToMongoDB();

      // Get expense count from Hive (open if needed)
      int expenseCount = 0;
      try {
        if (!Hive.isBoxOpen('expenses')) {
          print('📦 [NativeNetwork] Opening expenses box to get count...');
          await Hive.openBox('expenses');
        }
        final expenseBox = Hive.box('expenses');
        expenseCount = expenseBox.length;
        print('✅ [NativeNetwork] Got expense count: $expenseCount');
      } catch (e) {
        print('⚠️ [NativeNetwork] Could not get expense count: $e');
        expenseCount = 0;
      }
      totalItemsSynced += expenseCount;

      // Update progress: Expenses complete
      await _progressChannel.invokeMethod('updateProgress', {
        'title': 'expenses',
        'current': expenseCount,
        'total': expenseCount,
      });

      // Save sync time
      final syncTime = DateTime.now();
      await HiveService.saveSetting(
          'last_sync_time', syncTime.millisecondsSinceEpoch);

      print('✅ [NativeNetwork] Sync complete!');

      // Show completion notification (like WhatsApp)
      await _progressChannel.invokeMethod('showBackupComplete', {
        'itemsSynced': totalItemsSynced,
      });
      print(
          '✅ [NativeNetwork] Progress notification completed: $totalItemsSynced items');
    } catch (e) {
      print('❌ [NativeNetwork] Sync failed: $e');

      // Show error notification
      await _progressChannel.invokeMethod('showBackupError', {
        'error': e.toString(),
      });

      throw e;
    }
  }

  /// Called when daily email report alarm triggers from native Android code
  static Future<void> _onDailyEmailReport() async {
    print('📧 [NativeNetwork] ==========================================');
    print('📧 [NativeNetwork] DAILY EMAIL REPORT - Alarm triggered!');
    print('📧 [NativeNetwork] ==========================================');

    try {
      // Generate and send the daily report
      await generateAndSendReport('daily');

      print('✅ [NativeNetwork] Daily email report sent successfully!');
    } catch (e) {
      print('❌ [NativeNetwork] Error during daily email report: $e');
    }
  }
}
