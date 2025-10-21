import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'mongodb_service.dart';

/// Firebase Cloud Messaging (FCM) Service
/// Handles push notifications like WhatsApp - works on ALL Android devices
class FCMService {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin
      _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  /// Initialize FCM service
  static Future<void> initialize() async {
    if (kIsWeb) {
      print('ℹ️ [FCM] Web platform - FCM not fully supported');
      return;
    }

    try {
      // Request permission for iOS
      if (Platform.isIOS) {
        final settings = await _firebaseMessaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          announcement: false,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
        );
        print(
            '📱 [FCM] iOS permission status: ${settings.authorizationStatus}');
      }

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Get FCM token
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        print('✅ [FCM] Token obtained: ${token.substring(0, 20)}...');
        await _saveFCMTokenToMongoDB(token);
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        print('🔄 [FCM] Token refreshed');
        _saveFCMTokenToMongoDB(newToken);
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background messages
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      // Handle notification tap (when app is in background/terminated)
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Check if app was opened from a notification
      final initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }

      print('✅ [FCM] Service initialized successfully');
    } catch (e) {
      print('❌ [FCM] Initialization failed: $e');
    }
  }

  /// Initialize local notifications for foreground display
  static Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print('🔔 [FCM] Notification tapped: ${response.payload}');
      },
    );

    // Create notification channels for Android
    const AndroidNotificationChannel budgetChannel = AndroidNotificationChannel(
      'budget_alerts',
      'Budget Alerts',
      description: 'Notifications for budget threshold alerts',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    const AndroidNotificationChannel syncChannel = AndroidNotificationChannel(
      'sync_notifications',
      'Sync Notifications',
      description: 'Notifications for data synchronization',
      importance: Importance.defaultImportance,
    );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(budgetChannel);

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(syncChannel);
  }

  /// Save FCM token to MongoDB for the current user
  static Future<void> _saveFCMTokenToMongoDB(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('⚠️ [FCM] No user logged in, cannot save token');
        return;
      }

      if (!MongoDBService.isConnected) {
        print('⚠️ [FCM] MongoDB not connected, cannot save token');
        return;
      }

      final usersCollection = await MongoDBService.getUserCollection('users');
      if (usersCollection == null) {
        print('⚠️ [FCM] Users collection not available');
        return;
      }

      print('📤 [FCM] Saving token to MongoDB for user: ${user.uid}');
      print('   Token: ${token.substring(0, 20)}...');

      // Update or insert FCM token for user
      await usersCollection.updateOne(
        {'userId': user.uid},
        {
          '\$set': {
            'fcmToken': token,
            'fcmTokenUpdatedAt': DateTime.now().toIso8601String(),
            'platform': Platform.isAndroid ? 'android' : 'ios',
          }
        },
        upsert: true,
      );

      print('✅ [FCM] Token saved to MongoDB for user: ${user.uid}');

      // Verify the save was successful
      final savedDoc = await usersCollection.findOne({'userId': user.uid});
      if (savedDoc != null && savedDoc['fcmToken'] != null) {
        print(
            '✅ [FCM] Token verified in MongoDB: ${(savedDoc['fcmToken'] as String).substring(0, 20)}...');
      } else {
        print('⚠️ [FCM] Token was not found in MongoDB after save!');
      }
    } catch (e, stackTrace) {
      print('❌ [FCM] Failed to save token to MongoDB: $e');
      print('   Stack trace: $stackTrace');
    }
  }

  /// Public method to manually sync FCM token to MongoDB
  /// Call this after login or when MongoDB connection is restored
  static Future<void> syncTokenToMongoDB() async {
    try {
      print('🔄 [FCM] Manually syncing token to MongoDB...');
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _saveFCMTokenToMongoDB(token);
      } else {
        print('⚠️ [FCM] No token available to sync');
      }
    } catch (e) {
      print('❌ [FCM] Failed to sync token: $e');
    }
  }

  /// Handle foreground messages (when app is open)
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('📨 [FCM] Foreground message received');
    print('   Title: ${message.notification?.title}');
    print('   Body: ${message.notification?.body}');
    print('   Data: ${message.data}');

    // Show local notification even when app is in foreground
    if (message.notification != null) {
      await _showLocalNotification(
        title: message.notification!.title ?? 'Budget Alert',
        body: message.notification!.body ?? '',
        payload: message.data.toString(),
        channelId: message.data['type'] == 'budget_alert'
            ? 'budget_alerts'
            : 'sync_notifications',
      );
    }
  }

  /// Handle notification tap
  static void _handleNotificationTap(RemoteMessage message) {
    print('👆 [FCM] Notification tapped');
    print('   Data: ${message.data}');

    // TODO: Navigate to specific screen based on notification type
    // For example, if budget alert, navigate to expenses screen
  }

  /// Show local notification
  static Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
    String channelId = 'budget_alerts',
  }) async {
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      channelId,
      channelId == 'budget_alerts' ? 'Budget Alerts' : 'Sync Notifications',
      channelDescription: channelId == 'budget_alerts'
          ? 'Notifications for budget threshold alerts'
          : 'Notifications for data synchronization',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// Subscribe to a topic (for broadcast notifications)
  static Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      print('✅ [FCM] Subscribed to topic: $topic');
    } catch (e) {
      print('❌ [FCM] Failed to subscribe to topic $topic: $e');
    }
  }

  /// Unsubscribe from a topic
  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      print('✅ [FCM] Unsubscribed from topic: $topic');
    } catch (e) {
      print('❌ [FCM] Failed to unsubscribe from topic $topic: $e');
    }
  }

  /// Get current FCM token
  static Future<String?> getToken() async {
    try {
      return await _firebaseMessaging.getToken();
    } catch (e) {
      print('❌ [FCM] Failed to get token: $e');
      return null;
    }
  }

  /// Delete FCM token (on logout)
  static Future<void> deleteToken() async {
    try {
      await _firebaseMessaging.deleteToken();
      print('✅ [FCM] Token deleted');
    } catch (e) {
      print('❌ [FCM] Failed to delete token: $e');
    }
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('📨 [FCM] Background message received');
  print('   Title: ${message.notification?.title}');
  print('   Body: ${message.notification?.body}');
  print('   Data: ${message.data}');

  // Background messages are automatically displayed by FCM
  // No need to show local notification here
}
