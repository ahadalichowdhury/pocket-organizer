import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:workmanager/workmanager.dart';

import '../models/notification_model.dart';
import 'connectivity_service.dart';
import 'document_sync_service.dart';
import 'email_report_service.dart';
import 'expense_sync_service.dart';
import 'folder_sync_service.dart';
import 'hive_service.dart';
import 'pdf_report_service.dart';
import 'user_settings_sync_service.dart';

/// Task names for workmanager
class BackgroundTasks {
  static const String dailyReport = 'dailyReport';
  static const String weeklyReport = 'weeklyReport';
  static const String monthlyReport = 'monthlyReport';
  static const String autoSync = 'autoSync';
}

/// Background callback dispatcher - MUST be top-level function
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print('🔄 [Background] Task triggered: $task');

    try {
      // Initialize Hive for background task
      await HiveService.init();

      switch (task) {
        case BackgroundTasks.dailyReport:
          await _generateAndSendReport('daily');
          break;
        case BackgroundTasks.weeklyReport:
          await _generateAndSendReport('weekly');
          break;
        case BackgroundTasks.monthlyReport:
          await _generateAndSendReport('monthly');
          break;
        case BackgroundTasks.autoSync:
          await _performAutoSync();
          break;
        default:
          print('⚠️ [Background] Unknown task: $task');
      }

      return Future.value(true);
    } catch (e) {
      print('❌ [Background] Task failed: $e');
      return Future.value(false);
    }
  });
}

/// Perform auto-sync (MongoDB backup) in background
Future<void> _performAutoSync() async {
  try {
    print('☁️ [Auto-Sync] Starting background sync...');

    // Check if user is logged in
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('⚠️ [Auto-Sync] No user logged in, skipping sync');
      return;
    }

    // Check WiFi-only setting
    final wifiOnlyMode =
        HiveService.getSetting('sync_on_wifi_only', defaultValue: true) as bool;

    // Check connectivity
    final canProceed = await ConnectivityService.canProceedWithNetworkOperation(
      wifiOnlyMode: wifiOnlyMode,
    );

    if (!canProceed) {
      final connectionStatus = await ConnectivityService.getConnectionStatus();
      print('⚠️ [Auto-Sync] Cannot proceed with sync');
      print('   Connection: $connectionStatus');
      print('   WiFi-Only Mode: ${wifiOnlyMode ? "ON" : "OFF"}');
      return;
    }

    print('✅ [Auto-Sync] Connectivity check passed, proceeding with sync');

    // Sync folders
    print('📤 [Auto-Sync] Syncing folders...');
    await FolderSyncService.syncAllFoldersToMongoDB();

    // Sync documents
    print('📤 [Auto-Sync] Syncing documents...');
    await DocumentSyncService.syncAllDocumentsToMongoDB();

    // Sync expenses
    print('📤 [Auto-Sync] Syncing expenses...');
    await ExpenseSyncService().syncAllExpensesToMongoDB();

    print('✅ [Auto-Sync] Background sync complete');

    // Save sync time
    final syncTime = DateTime.now();
    await HiveService.saveSetting(
        'last_sync_time', syncTime.millisecondsSinceEpoch);

    // Update sync time in MongoDB
    await UserSettingsSyncService.updateSetting(
      userId: user.uid,
      lastSyncTime: syncTime,
    );

    // Show success notification
    await _showNotification(
      '✅ Auto-Sync Complete',
      'Your data has been backed up to the cloud',
      isError: false,
    );

    print('📱 [Auto-Sync] Success notification sent');
  } catch (e) {
    print('❌ [Auto-Sync] Background sync failed: $e');

    // Check if error is network-related
    final errorMsg = e.toString().toLowerCase();
    if (errorMsg.contains('socket') ||
        errorMsg.contains('network') ||
        errorMsg.contains('connection')) {
      print('   Network error detected - will retry at next scheduled time');
      return;
    }

    // Only show notification for non-network errors
    await _showNotification(
      'Auto-Sync Failed',
      'Failed to backup data: ${e.toString()}',
      isError: true,
    );
  }
}

/// Generate and send report (called from background task)
Future<void> _generateAndSendReport(String reportType) async {
  try {
    print('📊 [Report] Generating $reportType report...');

    // Get user email
    final userEmail = FirebaseAuth.instance.currentUser?.email;
    if (userEmail == null) {
      print('⚠️ [Report] No user logged in, skipping report');
      return;
    }

    // Check WiFi-only setting
    final wifiOnlyMode =
        HiveService.getSetting('sync_on_wifi_only', defaultValue: true) as bool;

    // Check connectivity
    final canProceed = await ConnectivityService.canProceedWithNetworkOperation(
      wifiOnlyMode: wifiOnlyMode,
    );

    if (!canProceed) {
      final connectionStatus = await ConnectivityService.getConnectionStatus();
      print('⚠️ [Report] Cannot proceed with email report - QUEUING FOR LATER');
      print('   Connection: $connectionStatus');
      print('   WiFi-Only Mode: ${wifiOnlyMode ? "ON" : "OFF"}');

      // Queue the report for later (when online)
      await HiveService.saveSetting('pending_${reportType}_report', true);
      print(
          '📋 [Report] $reportType report queued for when connection is restored');

      // Show notification that report is queued
      await _showNotification(
        'Report Queued 📋',
        'Your $reportType report will be sent when you\'re back online',
        isError: false,
      );
      return;
    }

    print('✅ [Report] Connectivity check passed, proceeding with report');

    // Get date range based on report type
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate = now;

    switch (reportType) {
      case 'daily':
        startDate = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 1));
        endDate = DateTime(now.year, now.month, now.day);
        break;
      case 'weekly':
        startDate = now.subtract(const Duration(days: 7));
        break;
      case 'monthly':
        startDate = now.subtract(const Duration(days: 30));
        break;
      default:
        startDate = DateTime(now.year, now.month, now.day);
    }

    // Get expenses for the period
    final allExpenses = HiveService.getAllExpenses();
    final expenses = allExpenses.where((expense) {
      return expense.date.isAfter(startDate) && expense.date.isBefore(endDate);
    }).toList();

    print(
        '📊 [Report] Found ${expenses.length} expenses for $reportType report');

    if (expenses.isEmpty) {
      print('ℹ️ [Report] No expenses to report for $reportType');

      // Add to in-app notifications
      await _addInAppNotification(
        title: 'No Expenses ℹ️',
        message: 'No expenses found for $reportType report',
        isSuccess: true,
      );

      // Show push notification
      await _showNotification(
        'No Expenses',
        'No expenses found for $reportType report',
        isError: false,
      );
      return;
    }

    // Generate PDF
    final pdfFile = await PdfReportService.generateExpenseReport(
      expenses: expenses,
      reportType: reportType,
      startDate: startDate,
      endDate: endDate,
    );

    print('✅ [Report] PDF generated: ${pdfFile.path}');

    // Calculate total
    final total = expenses.fold<double>(0.0, (sum, e) => sum + e.amount);
    final currencySymbol =
        HiveService.getSetting('currency_symbol', defaultValue: '\$') as String;

    // Create email subject and body
    final subject =
        '${_capitalize(reportType)} Expense Report - ${_formatDate(now)}';
    final body = '''
Hello!

Here is your $reportType expense report.

📊 Summary:
• Total Spent: $currencySymbol${total.toStringAsFixed(2)}
• Transactions: ${expenses.length}
• Period: ${_formatDate(startDate)} to ${_formatDate(endDate)}

The detailed report is attached as a PDF.

Best regards,
Pocket Organizer
    ''';

    // Send email
    final emailSent = await EmailReportService.sendReportEmail(
      recipientEmail: userEmail,
      subject: subject,
      body: body,
      pdfFile: pdfFile,
    );

    if (emailSent) {
      print('✅ [Report] Email sent successfully');

      // Clear pending flag (report successfully sent)
      await HiveService.saveSetting('pending_${reportType}_report', false);

      // Add to in-app notifications
      await _addInAppNotification(
        title: 'Report Sent! 📧',
        message: 'Your $reportType expense report has been sent to $userEmail',
        isSuccess: true,
      );

      // Show push notification
      await _showNotification(
        'Report Sent! 📧',
        'Your $reportType expense report has been sent to $userEmail',
        isError: false,
      );
    } else {
      print('❌ [Report] Email failed to send');

      // Add to in-app notifications
      await _addInAppNotification(
        title: 'Report Failed ❌',
        message:
            'Failed to send $reportType report. Check your email settings.',
        isSuccess: false,
      );

      // Show push notification
      await _showNotification(
        'Report Failed',
        'Failed to send $reportType report. Check your email settings.',
        isError: true,
      );
    }

    // Clean up temp file
    await pdfFile.delete();
  } catch (e) {
    print('❌ [Report] Error: $e');

    // Check if error is network-related
    final errorMsg = e.toString().toLowerCase();
    if (errorMsg.contains('socket') ||
        errorMsg.contains('network') ||
        errorMsg.contains('connection')) {
      print('   Network error detected - will retry at next scheduled time');
      return;
    }

    // Only show notification for non-network errors
    await _showNotification(
      'Report Failed',
      'Error generating report: $e',
      isError: true,
    );
  }
}

/// Show local notification
Future<void> _showNotification(String title, String body,
    {required bool isError}) async {
  try {
    final FlutterLocalNotificationsPlugin notificationsPlugin =
        FlutterLocalNotificationsPlugin();

    const androidDetails = AndroidNotificationDetails(
      'report_channel',
      'Expense Reports',
      channelDescription: 'Automated expense report notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
    );
  } catch (e) {
    print('⚠️ [Notification] Failed to show: $e');
  }
}

/// Add notification to in-app notification page
Future<void> _addInAppNotification({
  required String title,
  required String message,
  required bool isSuccess,
}) async {
  try {
    final notification = NotificationModel(
      id: const Uuid().v4(),
      title: title,
      message: message,
      createdAt: DateTime.now(),
      isRead: false,
      type: isSuccess ? 'report_success' : 'report_error',
      data: {'source': 'automated_report'},
    );

    await HiveService.addNotification(notification);
    print('✅ [Notification] Added to in-app notifications');
  } catch (e) {
    print('⚠️ [Notification] Failed to add to in-app: $e');
  }
}

/// Helper function to capitalize first letter
String _capitalize(String text) {
  if (text.isEmpty) return text;
  return text[0].toUpperCase() + text.substring(1);
}

/// Helper function to format date
String _formatDate(DateTime date) {
  return DateFormat('MMM d, yyyy').format(date);
}

/// Main service class for managing automated reports using Workmanager
/// Works on both iOS and Android!
class AutomatedReportService {
  /// Initialize the background task manager
  static Future<void> initialize() async {
    if (kIsWeb) {
      print(
          'ℹ️ [AutoReport] Web platform detected - automated reports not supported');
      print('   Use manual email reports from settings instead');
      return;
    }

    try {
      // Initialize Workmanager for both iOS and Android
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: kDebugMode,
      );

      final platform = Platform.isAndroid ? 'Android' : 'iOS';
      print('✅ [AutoReport] Workmanager initialized for $platform');
    } catch (e) {
      print('❌ [AutoReport] Initialization failed: $e');
    }
  }

  /// Schedule daily reports
  static Future<void> scheduleDailyReport({bool enabled = true}) async {
    try {
      // Cancel existing task
      await Workmanager().cancelByUniqueName(BackgroundTasks.dailyReport);

      if (!enabled) {
        print('🛑 [AutoReport] Daily reports disabled');
        await HiveService.saveSetting('daily_report_enabled', false);
        return;
      }

      // Get custom report time (default: 9:00 AM)
      final reportHour =
          HiveService.getSetting('daily_report_hour', defaultValue: 9) as int;
      final reportMinute =
          HiveService.getSetting('daily_report_minute', defaultValue: 0) as int;

      // Calculate initial delay to run at the specified time
      final now = DateTime.now();
      DateTime scheduledTime =
          DateTime(now.year, now.month, now.day, reportHour, reportMinute);

      // If scheduled time has passed today, schedule for tomorrow
      if (scheduledTime.isBefore(now)) {
        scheduledTime = scheduledTime.add(const Duration(days: 1));
      }

      final initialDelay = scheduledTime.difference(now);
      print(
          '📅 [AutoReport] Daily report will run at ${reportHour.toString().padLeft(2, '0')}:${reportMinute.toString().padLeft(2, '0')}');
      print(
          '   Initial delay: ${initialDelay.inHours}h ${initialDelay.inMinutes % 60}m');

      // Schedule periodic task (every 24 hours at the specified time)
      await Workmanager().registerPeriodicTask(
        BackgroundTasks.dailyReport,
        BackgroundTasks.dailyReport,
        frequency: const Duration(hours: 24),
        initialDelay: initialDelay,
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
      );

      await HiveService.saveSetting('daily_report_enabled', true);
      print('✅ [AutoReport] Daily reports scheduled');
    } catch (e) {
      print('❌ [AutoReport] Failed to schedule daily reports: $e');
    }
  }

  /// Schedule weekly reports
  static Future<void> scheduleWeeklyReport({bool enabled = true}) async {
    try {
      await Workmanager().cancelByUniqueName(BackgroundTasks.weeklyReport);

      if (!enabled) {
        print('🛑 [AutoReport] Weekly reports disabled');
        await HiveService.saveSetting('weekly_report_enabled', false);
        return;
      }

      // Schedule weekly (every 7 days)
      await Workmanager().registerPeriodicTask(
        BackgroundTasks.weeklyReport,
        BackgroundTasks.weeklyReport,
        frequency: const Duration(days: 7),
        initialDelay: const Duration(days: 7),
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
      );

      await HiveService.saveSetting('weekly_report_enabled', true);
      print('✅ [AutoReport] Weekly reports scheduled');
    } catch (e) {
      print('❌ [AutoReport] Failed to schedule weekly reports: $e');
    }
  }

  /// Schedule monthly reports
  static Future<void> scheduleMonthlyReport({bool enabled = true}) async {
    try {
      await Workmanager().cancelByUniqueName(BackgroundTasks.monthlyReport);

      if (!enabled) {
        print('🛑 [AutoReport] Monthly reports disabled');
        await HiveService.saveSetting('monthly_report_enabled', false);
        return;
      }

      // Schedule monthly (every 30 days)
      await Workmanager().registerPeriodicTask(
        BackgroundTasks.monthlyReport,
        BackgroundTasks.monthlyReport,
        frequency: const Duration(days: 30),
        initialDelay: const Duration(days: 30),
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
      );

      await HiveService.saveSetting('monthly_report_enabled', true);
      print('✅ [AutoReport] Monthly reports scheduled');
    } catch (e) {
      print('❌ [AutoReport] Failed to schedule monthly reports: $e');
    }
  }

  /// Schedule automatic sync (MongoDB backup)
  /// @param interval: '6h', '8h', '12h', '24h', or 'manual'
  static Future<void> scheduleAutoSync(String interval) async {
    try {
      // Cancel existing auto-sync task
      await Workmanager().cancelByUniqueName(BackgroundTasks.autoSync);

      // If manual mode, just cancel and return
      if (interval == 'manual') {
        print('🛑 [AutoSync] Manual mode - auto-sync disabled');
        await HiveService.saveSetting('auto_sync_enabled', false);
        return;
      }

      // Parse interval to hours
      final hours = _parseIntervalToHours(interval);
      if (hours == null) {
        print('❌ [AutoSync] Invalid interval: $interval');
        return;
      }

      print('📅 [AutoSync] Scheduling auto-sync every ${hours}h...');

      // Schedule periodic task
      // Note: iOS minimum is 15 minutes, but Android can do custom intervals
      await Workmanager().registerPeriodicTask(
        BackgroundTasks.autoSync,
        BackgroundTasks.autoSync,
        frequency: Duration(hours: hours),
        initialDelay: Duration(hours: hours),
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
      );

      await HiveService.saveSetting('auto_sync_enabled', true);
      await HiveService.saveSetting('auto_sync_interval', interval);
      print('✅ [AutoSync] Auto-sync scheduled every ${hours}h');
    } catch (e) {
      print('❌ [AutoSync] Failed to schedule auto-sync: $e');
    }
  }

  /// Parse interval string to hours
  static int? _parseIntervalToHours(String interval) {
    switch (interval) {
      case '2h':
        return 2;
      case '6h':
        return 6;
      case '8h':
        return 8;
      case '12h':
        return 12;
      case '24h':
        return 24;
      default:
        return null;
    }
  }

  /// Cancel all scheduled reports and auto-sync
  static Future<void> cancelAllReports() async {
    try {
      await Workmanager().cancelByUniqueName(BackgroundTasks.dailyReport);
      await Workmanager().cancelByUniqueName(BackgroundTasks.weeklyReport);
      await Workmanager().cancelByUniqueName(BackgroundTasks.monthlyReport);
      await Workmanager().cancelByUniqueName(BackgroundTasks.autoSync);

      await HiveService.saveSetting('daily_report_enabled', false);
      await HiveService.saveSetting('weekly_report_enabled', false);
      await HiveService.saveSetting('monthly_report_enabled', false);
      await HiveService.saveSetting('auto_sync_enabled', false);

      print('🛑 [AutoReport] All reports and auto-sync cancelled');
    } catch (e) {
      print('❌ [AutoReport] Failed to cancel reports: $e');
    }
  }

  /// Process any pending reports that were queued while offline
  /// This should be called when the app comes back online
  static Future<void> processPendingReports() async {
    try {
      print('🔄 [AutoReport] Checking for pending reports...');

      // Check WiFi-only setting
      final wifiOnlyMode =
          HiveService.getSetting('sync_on_wifi_only', defaultValue: true)
              as bool;

      // Check connectivity
      final canProceed =
          await ConnectivityService.canProceedWithNetworkOperation(
        wifiOnlyMode: wifiOnlyMode,
      );

      if (!canProceed) {
        print('⚠️ [AutoReport] Still offline, cannot process pending reports');
        return;
      }

      print('✅ [AutoReport] Online - processing pending reports...');

      // Check for pending daily report
      final pendingDaily =
          HiveService.getSetting('pending_daily_report', defaultValue: false)
              as bool;
      if (pendingDaily) {
        print('📧 [AutoReport] Sending pending daily report...');
        await _generateAndSendReport('daily');
      }

      // Check for pending weekly report
      final pendingWeekly =
          HiveService.getSetting('pending_weekly_report', defaultValue: false)
              as bool;
      if (pendingWeekly) {
        print('📧 [AutoReport] Sending pending weekly report...');
        await _generateAndSendReport('weekly');
      }

      // Check for pending monthly report
      final pendingMonthly =
          HiveService.getSetting('pending_monthly_report', defaultValue: false)
              as bool;
      if (pendingMonthly) {
        print('📧 [AutoReport] Sending pending monthly report...');
        await _generateAndSendReport('monthly');
      }

      if (!pendingDaily && !pendingWeekly && !pendingMonthly) {
        print('✅ [AutoReport] No pending reports to process');
      } else {
        print('✅ [AutoReport] All pending reports processed');
      }
    } catch (e) {
      print('❌ [AutoReport] Failed to process pending reports: $e');
    }
  }
}
