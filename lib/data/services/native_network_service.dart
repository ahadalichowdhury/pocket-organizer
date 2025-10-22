import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

import 'app_logger.dart';
import 'automated_report_service.dart';
import 'document_sync_service.dart';
import 'expense_sync_service.dart';
import 'folder_sync_service.dart';
import 'hive_service.dart';
import 'simple_email_service.dart';

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
      case 'onWarrantyEmailTrigger':
        await _onWarrantyEmailTrigger(call.arguments);
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
    AppLogger.info('WiFi connected - checking for backup...');

    try {
      // Check if user boxes are open (prevent race condition during app startup)
      if (HiveService.currentUserId == null) {
        print('⚠️ [NativeNetwork] User not logged in yet, skipping backup');
        AppLogger.warning('User not logged in, skipping backup');
        return;
      }

      // Check if auto-sync is enabled
      final autoSyncEnabled =
          HiveService.getSetting('auto_sync_enabled', defaultValue: false)
              as bool;

      if (!autoSyncEnabled) {
        print('ℹ️ [NativeNetwork] Auto-sync is disabled, skipping');
        AppLogger.info('Auto-sync is disabled, skipping backup');
        return;
      }

      print('✅ [NativeNetwork] Auto-sync is enabled, starting backup...');
      AppLogger.success('Auto-sync enabled - starting backup...');

      // 1. Process pending email reports
      print('📧 [NativeNetwork] Processing pending email reports...');
      try {
        await AutomatedReportService.processPendingReports();
      } catch (e) {
        print('❌ [NativeNetwork] Failed to process pending reports: $e');
        AppLogger.error('Failed to process pending reports: $e');
      }

      // 2. Perform auto-sync
      print('☁️ [NativeNetwork] Starting auto-sync...');
      await _performSync();

      print('✅ [NativeNetwork] WiFi-triggered sync complete!');
      AppLogger.success('WiFi backup completed successfully!');
    } catch (e) {
      print('❌ [NativeNetwork] Error during WiFi sync: $e');
      AppLogger.error('WiFi sync failed: $e');
    }
  }

  /// Perform sync (same logic as manual backup)
  static Future<void> _performSync() async {
    try {
      AppLogger.info('Starting data sync...');

      // Show backup started notification (like WhatsApp)
      await _progressChannel.invokeMethod('showBackupStarted');
      print('📱 [NativeNetwork] Progress notification shown');

      int totalItemsSynced = 0;

      // 1. Sync folders
      print('☁️ [NativeNetwork] Syncing folders...');
      AppLogger.info('Syncing folders...');
      final folderCount = await FolderSyncService.syncAllFoldersToMongoDB();
      totalItemsSynced += folderCount;
      AppLogger.success('Synced $folderCount folders');

      // Update progress: Folders complete
      await _progressChannel.invokeMethod('updateProgress', {
        'title': 'folders',
        'current': folderCount,
        'total': folderCount,
      });

      // 2. Sync documents
      print('☁️ [NativeNetwork] Syncing documents...');
      AppLogger.info('Syncing documents...');
      final documentCount =
          await DocumentSyncService.syncAllDocumentsToMongoDB();
      totalItemsSynced += documentCount;
      AppLogger.success('Synced $documentCount documents');

      // Update progress: Documents complete
      await _progressChannel.invokeMethod('updateProgress', {
        'title': 'documents',
        'current': documentCount,
        'total': documentCount,
      });

      // 3. Sync expenses
      print('☁️ [NativeNetwork] Syncing expenses...');
      AppLogger.info('Syncing expenses...');
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
        AppLogger.success('Synced $expenseCount expenses');
      } catch (e) {
        print('⚠️ [NativeNetwork] Could not get expense count: $e');
        AppLogger.warning('Could not get expense count: $e');
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
      AppLogger.success('Backup complete: $totalItemsSynced items synced');

      // Show completion notification (like WhatsApp)
      await _progressChannel.invokeMethod('showBackupComplete', {
        'itemsSynced': totalItemsSynced,
      });
      print(
          '✅ [NativeNetwork] Progress notification completed: $totalItemsSynced items');
    } catch (e) {
      print('❌ [NativeNetwork] Sync failed: $e');
      AppLogger.error('Sync failed: $e');

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
    AppLogger.info('Daily email report alarm triggered');

    try {
      // Generate and send the daily report
      await generateAndSendReport('daily');

      print('✅ [NativeNetwork] Daily email report sent successfully!');
      AppLogger.success('Daily email report sent successfully');
    } catch (e) {
      print('❌ [NativeNetwork] Error during daily email report: $e');
      AppLogger.error('Daily email report failed: $e');
    }
  }

  /// Public wrapper for warranty email trigger (called from FCM service)
  static Future<void> handleWarrantyEmailTrigger(
      Map<String, dynamic> data) async {
    await _onWarrantyEmailTrigger(data);
  }

  /// Called when warranty email trigger is received via FCM data message
  static Future<void> _onWarrantyEmailTrigger(
      Map<dynamic, dynamic>? arguments) async {
    print('📧 [NativeNetwork] ==========================================');
    print(
        '📧 [NativeNetwork] WARRANTY EMAIL TRIGGER - FCM data message received!');
    print('📧 [NativeNetwork] ==========================================');
    AppLogger.info('Warranty email trigger received from MongoDB');

    try {
      if (arguments == null) {
        print('❌ [NativeNetwork] No arguments provided');
        return;
      }

      final recipientEmail = arguments['recipient_email'] as String?;
      final documentCount = arguments['document_count'] as String?;
      final notificationsJson = arguments['notifications_json'] as String?;

      if (recipientEmail == null || notificationsJson == null) {
        print('❌ [NativeNetwork] Missing required arguments');
        print('   recipient_email: $recipientEmail');
        print(
            '   notifications_json: ${notificationsJson != null ? "present" : "null"}');
        return;
      }

      print('📧 [NativeNetwork] Email Details:');
      print('   Recipient: $recipientEmail');
      print('   Document Count: $documentCount');
      AppLogger.info('Sending warranty email to: $recipientEmail');

      // Parse notifications JSON
      final List<dynamic> notificationsData = jsonDecode(notificationsJson);
      final List<Map<String, dynamic>> documents = notificationsData
          .map((doc) => Map<String, dynamic>.from(doc as Map))
          .toList();

      print('📧 [NativeNetwork] Parsed ${documents.length} documents');
      for (final doc in documents) {
        print('   - ${doc['documentName']}: ${doc['daysUntilExpiry']} days');
      }

      // Generate HTML email using WarrantyEmailService
      final emailHtml = _generateWarrantyEmailHtml(recipientEmail, documents);
      final emailSubject = documents.length == 1
          ? '⚠️ 1 Document Expiring Soon - Pocket Organizer'
          : '⚠️ ${documents.length} Documents Expiring Soon - Pocket Organizer';

      print('📤 [NativeNetwork] Sending email via Gmail SMTP...');
      AppLogger.info('Sending warranty email via Gmail SMTP...');

      // Send email using SimpleEmailService (uses existing Gmail SMTP config)
      final emailSent = await SimpleEmailService.sendHtmlEmail(
        recipientEmail: recipientEmail,
        subject: emailSubject,
        htmlBody: emailHtml,
      );

      if (emailSent) {
        print('✅ [NativeNetwork] Warranty email sent successfully!');
        AppLogger.success('Warranty email sent to: $recipientEmail');
      } else {
        print('❌ [NativeNetwork] Failed to send warranty email');
        AppLogger.error('Failed to send warranty email to: $recipientEmail');
      }
    } catch (e, stackTrace) {
      print('❌ [NativeNetwork] Error during warranty email trigger: $e');
      print('   Stack trace: $stackTrace');
      AppLogger.error('Warranty email trigger failed: $e');
    }
  }

  /// Generate HTML email for warranty reminders
  static String _generateWarrantyEmailHtml(
    String recipientEmail,
    List<Map<String, dynamic>> documents,
  ) {
    // Sort by urgency (most urgent first)
    documents.sort((a, b) =>
        (a['daysUntilExpiry'] as int).compareTo(b['daysUntilExpiry'] as int));

    // Generate document list HTML
    final documentListHtml = documents.map((doc) {
      final name = doc['documentName'] ?? 'Unknown Document';
      final days = doc['daysUntilExpiry'] as int? ?? 0;
      final expiryDate = doc['expiryDate'] ?? 'Unknown';
      final folder = doc['folderName'] ?? '';

      final String borderColor;
      final String bgColor;
      final String textColor;
      final String urgencyEmoji;

      if (days <= 1) {
        borderColor = '#D32F2F';
        bgColor = '#FFEBEE';
        textColor = '#C62828';
        urgencyEmoji = '🔴';
      } else if (days <= 7) {
        borderColor = '#F57C00';
        bgColor = '#FFF3E0';
        textColor = '#E65100';
        urgencyEmoji = '🟠';
      } else if (days <= 14) {
        borderColor = '#FBC02D';
        bgColor = '#FFFDE7';
        textColor = '#F57F17';
        urgencyEmoji = '🟡';
      } else {
        borderColor = '#388E3C';
        bgColor = '#F1F8E9';
        textColor = '#2E7D32';
        urgencyEmoji = '🟢';
      }

      return '''
        <div style="background-color: $bgColor; padding: 20px; border-radius: 10px; margin: 0 0 16px 0; border-left: 5px solid $borderColor; box-shadow: 0 1px 3px rgba(0,0,0,0.1);">
          <h3 style="margin: 0 0 12px 0; color: $textColor; font-size: 18px; font-weight: 600; line-height: 1.3;">
            $urgencyEmoji $name
          </h3>
          <div style="margin: 8px 0;">
            <p style="margin: 0; color: #616161; font-size: 14px; line-height: 1.6;">
              <strong style="color: #424242;">Expires in:</strong> <span style="color: $textColor; font-weight: 600;">$days ${days == 1 ? 'day' : 'days'}</span>
            </p>
          </div>
          <div style="margin: 8px 0;">
            <p style="margin: 0; color: #616161; font-size: 14px; line-height: 1.6;">
              <strong style="color: #424242;">Expiry Date:</strong> $expiryDate
            </p>
          </div>
          ${folder.isNotEmpty ? '''
          <div style="margin: 8px 0;">
            <p style="margin: 0; color: #9E9E9E; font-size: 12px; line-height: 1.6;">
              📁 $folder
            </p>
          </div>
          ''' : ''}
        </div>
      ''';
    }).join('\n');

    final timestamp = DateTime.now().toString().substring(0, 19);

    return '''
<!DOCTYPE html>
<html>
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Warranty Reminder - Pocket Organizer</title>
  </head>
  <body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #f5f5f5;">
    <div style="max-width: 600px; margin: 20px auto; background-color: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
      
      <!-- Header -->
      <div style="background: linear-gradient(135deg, #1976D2 0%, #1565C0 100%); padding: 40px 30px; text-align: center;">
        <h1 style="margin: 0; color: #ffffff; font-size: 28px; font-weight: 600; letter-spacing: -0.5px;">
          ⚠️ Warranty Expiry Alert
        </h1>
        <p style="margin: 12px 0 0 0; color: #E3F2FD; font-size: 15px; font-weight: 400;">
          Pocket Organizer - Document Reminders
        </p>
      </div>
      
      <!-- Content -->
      <div style="padding: 40px 30px;">
        <p style="color: #212121; font-size: 16px; line-height: 1.6; margin: 0 0 20px 0;">
          Hello,
        </p>
        <p style="color: #424242; font-size: 16px; line-height: 1.6; margin: 0 0 30px 0;">
          You have <strong style="color: #1976D2; font-weight: 600;">${documents.length} document${documents.length > 1 ? 's' : ''}</strong> expiring soon. Please review and take necessary action:
        </p>
        
        $documentListHtml
        
        <!-- Info Box -->
        <div style="background: linear-gradient(135deg, #E3F2FD 0%, #BBDEFB 100%); padding: 20px; border-radius: 8px; margin: 30px 0 0 0; border-left: 4px solid #1976D2;">
          <p style="margin: 0; color: #0D47A1; font-size: 14px; line-height: 1.6;">
            💡 <strong style="font-weight: 600;">Quick Tip:</strong> Open the Pocket Organizer app to view full document details, upload renewed warranties, or update expiry dates.
          </p>
        </div>
      </div>
      
      <!-- Footer -->
      <div style="background-color: #FAFAFA; padding: 30px; text-align: center; border-top: 1px solid #E0E0E0;">
        <p style="margin: 0 0 8px 0; color: #757575; font-size: 13px; line-height: 1.6;">
          This is an automated reminder from <strong style="color: #424242;">Pocket Organizer</strong>
        </p>
        <p style="margin: 0 0 8px 0; color: #9E9E9E; font-size: 12px;">
          You can manage warranty reminder settings in the app
        </p>
        <p style="margin: 0; color: #BDBDBD; font-size: 11px;">
          Sent: $timestamp
        </p>
      </div>
      
    </div>
  </body>
</html>
''';
  }
}
