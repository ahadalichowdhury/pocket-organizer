import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';

import 'hive_service.dart';

/// Background service to monitor budget and send alerts
/// Checks budget status periodically, even when app is closed
class BudgetMonitorService {
  static const String _taskName = 'budget_monitor_task';
  static const String _taskIdentifier = 'com.pocketorganizer.budget_monitor';

  /// Initialize the budget monitor service
  static Future<void> initialize() async {
    if (kIsWeb) {
      print(
          'ℹ️ [BudgetMonitor] Web platform - background monitoring not supported');
      return;
    }

    if (Platform.isIOS) {
      print('ℹ️ [BudgetMonitor] iOS platform - limited background support');
    }

    try {
      await Workmanager().initialize(
        _callbackDispatcher,
        isInDebugMode: false,
      );
      print('✅ [BudgetMonitor] Service initialized');
    } catch (e) {
      print('❌ [BudgetMonitor] Initialization failed: $e');
    }
  }

  /// Start monitoring budget (check every 1 hour)
  static Future<void> startMonitoring() async {
    if (kIsWeb || Platform.isIOS) {
      return;
    }

    try {
      await Workmanager().registerPeriodicTask(
        _taskIdentifier,
        _taskName,
        frequency: const Duration(hours: 1), // Check every hour
        initialDelay: const Duration(minutes: 1), // First check after 1 minute
        constraints: Constraints(
          networkType: NetworkType.notRequired, // Works offline
        ),
      );
      print('✅ [BudgetMonitor] Monitoring started (checks every 1 hour)');
    } catch (e) {
      print('❌ [BudgetMonitor] Failed to start monitoring: $e');
    }
  }

  /// Stop monitoring budget
  static Future<void> stopMonitoring() async {
    if (kIsWeb || Platform.isIOS) {
      return;
    }

    try {
      await Workmanager().cancelByUniqueName(_taskIdentifier);
      print('✅ [BudgetMonitor] Monitoring stopped');
    } catch (e) {
      print('❌ [BudgetMonitor] Failed to stop monitoring: $e');
    }
  }
}

/// Background callback dispatcher
@pragma('vm:entry-point')
void _callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == BudgetMonitorService._taskName) {
      await _checkBudgetAndAlert();
    }
    return Future.value(true);
  });
}

/// Check budget status and send alerts if threshold crossed
Future<void> _checkBudgetAndAlert() async {
  try {
    print('🔍 [BudgetMonitor] Checking budget status...');

    // Initialize Hive
    await HiveService.init();

    // Get alert threshold
    final alertThreshold =
        HiveService.getSetting('alert_threshold', defaultValue: 80.0) as double;

    // Check daily budget
    await _checkDailyBudget(alertThreshold);

    // Check weekly budget
    await _checkWeeklyBudget(alertThreshold);

    // Check monthly budget
    await _checkMonthlyBudget(alertThreshold);

    print('✅ [BudgetMonitor] Budget check complete');
  } catch (e) {
    print('❌ [BudgetMonitor] Error checking budget: $e');
  }
}

/// Check daily budget and alert if threshold crossed
Future<void> _checkDailyBudget(double alertThreshold) async {
  final dailyBudget = HiveService.getSetting('daily_budget') as double?;
  if (dailyBudget == null || dailyBudget == 0.0) return;

  final expenses = HiveService.getAllExpenses();
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final todayEnd = todayStart.add(const Duration(days: 1));

  final todayExpenses = expenses.where((expense) {
    return expense.date.isAfter(todayStart) && expense.date.isBefore(todayEnd);
  }).toList();

  final spent = todayExpenses.fold<double>(
    0.0,
    (sum, expense) => sum + expense.amount,
  );

  final thresholdAmount = dailyBudget * (alertThreshold / 100);
  final shouldAlert = spent >= thresholdAmount && spent < dailyBudget;

  if (shouldAlert) {
    final lastAlertAmount = HiveService.getSetting(
      'last_budget_alert_daily_budget_amount',
      defaultValue: 0.0,
    ) as double;

    if (spent != lastAlertAmount) {
      await _sendBudgetNotification(
        'Daily Budget Alert',
        'You\'ve spent ${spent.toStringAsFixed(2)} of ${dailyBudget.toStringAsFixed(2)} (${alertThreshold.toInt()}% threshold reached)',
      );
      await HiveService.saveSetting(
        'last_budget_alert_daily_budget_amount',
        spent,
      );
    }
  }
}

/// Check weekly budget and alert if threshold crossed
Future<void> _checkWeeklyBudget(double alertThreshold) async {
  final weeklyBudget = HiveService.getSetting('weekly_budget') as double?;
  if (weeklyBudget == null || weeklyBudget == 0.0) return;

  final expenses = HiveService.getAllExpenses();
  final now = DateTime.now();
  final weekStart = now.subtract(Duration(days: now.weekday - 1));
  final weekStartMidnight =
      DateTime(weekStart.year, weekStart.month, weekStart.day);
  final weekEnd = weekStartMidnight.add(const Duration(days: 7));

  final weekExpenses = expenses.where((expense) {
    return expense.date.isAfter(weekStartMidnight) &&
        expense.date.isBefore(weekEnd);
  }).toList();

  final spent = weekExpenses.fold<double>(
    0.0,
    (sum, expense) => sum + expense.amount,
  );

  final thresholdAmount = weeklyBudget * (alertThreshold / 100);
  final shouldAlert = spent >= thresholdAmount && spent < weeklyBudget;

  if (shouldAlert) {
    final lastAlertAmount = HiveService.getSetting(
      'last_budget_alert_weekly_budget_amount',
      defaultValue: 0.0,
    ) as double;

    if (spent != lastAlertAmount) {
      await _sendBudgetNotification(
        'Weekly Budget Alert',
        'You\'ve spent ${spent.toStringAsFixed(2)} of ${weeklyBudget.toStringAsFixed(2)} (${alertThreshold.toInt()}% threshold reached)',
      );
      await HiveService.saveSetting(
        'last_budget_alert_weekly_budget_amount',
        spent,
      );
    }
  }
}

/// Check monthly budget and alert if threshold crossed
Future<void> _checkMonthlyBudget(double alertThreshold) async {
  final monthlyBudget = HiveService.getSetting('monthly_budget') as double?;
  if (monthlyBudget == null || monthlyBudget == 0.0) return;

  final expenses = HiveService.getAllExpenses();
  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);
  final monthEnd = DateTime(now.year, now.month + 1, 1);

  final monthExpenses = expenses.where((expense) {
    return expense.date.isAfter(monthStart) && expense.date.isBefore(monthEnd);
  }).toList();

  final spent = monthExpenses.fold<double>(
    0.0,
    (sum, expense) => sum + expense.amount,
  );

  final thresholdAmount = monthlyBudget * (alertThreshold / 100);
  final shouldAlert = spent >= thresholdAmount && spent < monthlyBudget;

  if (shouldAlert) {
    final lastAlertAmount = HiveService.getSetting(
      'last_budget_alert_monthly_budget_amount',
      defaultValue: 0.0,
    ) as double;

    if (spent != lastAlertAmount) {
      await _sendBudgetNotification(
        'Monthly Budget Alert',
        'You\'ve spent ${spent.toStringAsFixed(2)} of ${monthlyBudget.toStringAsFixed(2)} (${alertThreshold.toInt()}% threshold reached)',
      );
      await HiveService.saveSetting(
        'last_budget_alert_monthly_budget_amount',
        spent,
      );
    }
  }
}

/// Send budget notification
Future<void> _sendBudgetNotification(String title, String body) async {
  try {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'budget_alerts',
      'Budget Alerts',
      channelDescription: 'Notifications for budget threshold alerts',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      body,
      platformChannelSpecifics,
    );

    print('✅ [BudgetMonitor] Notification sent: $title');
  } catch (e) {
    print('❌ [BudgetMonitor] Failed to send notification: $e');
  }
}
