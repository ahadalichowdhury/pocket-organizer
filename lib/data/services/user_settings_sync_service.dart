import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:mongo_dart/mongo_dart.dart' as mongo;

import '../../core/config/mongodb_config.dart';
import '../models/user_settings_model.dart';
import 'hive_service.dart';
import 'mongodb_service.dart';

class UserSettingsSyncService {
  /// Upload user settings to MongoDB
  static Future<bool> uploadSettingsToMongoDB(
      UserSettingsModel settings) async {
    if (kIsWeb) return false;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final collection = await MongoDBService.getUserCollection(
          MongoDBConfig.userSettingsCollection);
      if (collection == null) return false;

      final data = settings.toJson();

      await collection.replaceOne(
        mongo.where.eq('userId', user.uid),
        data,
        upsert: true,
      );

      print('✅ [SettingsSync] Settings uploaded to MongoDB');
      return true;
    } catch (e) {
      print('❌ [SettingsSync] Error uploading settings: $e');
      return false;
    }
  }

  /// Download user settings from MongoDB
  static Future<UserSettingsModel?> downloadSettingsFromMongoDB() async {
    if (kIsWeb) return null;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final collection = await MongoDBService.getUserCollection(
          MongoDBConfig.userSettingsCollection);
      if (collection == null) return null;

      final doc = await collection.findOne(mongo.where.eq('userId', user.uid));

      if (doc == null) {
        print('ℹ️ [SettingsSync] No settings found in MongoDB for user');
        return null;
      }

      final settings = UserSettingsModel.fromJson(doc);
      print('✅ [SettingsSync] Settings downloaded from MongoDB');
      return settings;
    } catch (e) {
      print('❌ [SettingsSync] Error downloading settings: $e');
      return null;
    }
  }

  /// Save settings to local Hive storage
  static Future<void> saveSettingsLocally(UserSettingsModel settings) async {
    try {
      await HiveService.saveSetting('user_settings_userId', settings.userId);
      await HiveService.saveSetting('dark_mode', settings.isDarkMode);
      await HiveService.saveSetting('currency_symbol', settings.currencySymbol);
      await HiveService.saveSetting(
          'notifications_enabled', settings.notificationsEnabled);
      await HiveService.saveSetting(
          'auto_sync_enabled', settings.autoSyncEnabled);

      // Convert hours to string format for UI compatibility
      final intervalString = _hoursToIntervalString(settings.autoSyncInterval);
      await HiveService.saveSetting('auto_sync_interval', intervalString);

      await HiveService.saveSetting('sync_wifi_only', settings.syncOnWifiOnly);
      await HiveService.saveSetting(
          'sync_on_wifi_only', settings.syncOnWifiOnly); // Alternate key
      await HiveService.saveSetting(
          'last_sync_time', settings.lastSyncTime?.millisecondsSinceEpoch ?? 0);
      await HiveService.saveSetting(
          'daily_budget', settings.dailyBudget ?? 0.0);
      await HiveService.saveSetting(
          'weekly_budget', settings.weeklyBudget ?? 0.0);
      await HiveService.saveSetting(
          'monthly_budget', settings.monthlyBudget ?? 0.0);
      await HiveService.saveSetting(
          'alert_threshold', settings.alertThreshold ?? 80.0);
      await HiveService.saveSetting(
          'user_settings_updatedAt', settings.updatedAt.millisecondsSinceEpoch);

      print('✅ [SettingsSync] Settings saved locally');
      print('   Dark mode: ${settings.isDarkMode}');
      print('   Currency: ${settings.currencySymbol}');
      print('   Daily budget: ${settings.dailyBudget}');
      print('   Weekly budget: ${settings.weeklyBudget}');
      print('   Monthly budget: ${settings.monthlyBudget}');
      print('   Alert threshold: ${settings.alertThreshold}%');
      print(
          '   Auto sync: ${settings.autoSyncEnabled} (${settings.autoSyncInterval}h)');
    } catch (e) {
      print('❌ [SettingsSync] Error saving settings locally: $e');
    }
  }

  /// Convert hours to interval string
  static String _hoursToIntervalString(int hours) {
    switch (hours) {
      case 6:
        return '6h';
      case 8:
        return '8h';
      case 12:
        return '12h';
      case 24:
        return '24h';
      default:
        return 'manual';
    }
  }

  /// Load settings from local Hive storage
  static UserSettingsModel? loadSettingsLocally(String userId) {
    try {
      final storedUserId =
          HiveService.getSetting('user_settings_userId', defaultValue: '')
              as String;

      // If stored userId doesn't match, return default settings
      if (storedUserId.isEmpty || storedUserId != userId) {
        print('ℹ️ [SettingsSync] No local settings or user mismatch');
        return null;
      }

      final updatedAtMs =
          HiveService.getSetting('user_settings_updatedAt', defaultValue: 0)
              as int;
      if (updatedAtMs == 0) {
        return null;
      }

      final lastSyncTimeMs =
          HiveService.getSetting('last_sync_time', defaultValue: 0) as int;

      // Convert string interval to hours
      final intervalString =
          HiveService.getSetting('auto_sync_interval', defaultValue: 'manual')
              as String;
      final intervalHours = _intervalStringToHours(intervalString);

      return UserSettingsModel(
        userId: userId,
        isDarkMode: HiveService.getSetting('dark_mode', defaultValue: false),
        currencySymbol:
            HiveService.getSetting('currency_symbol', defaultValue: '\$'),
        notificationsEnabled:
            HiveService.getSetting('notifications_enabled', defaultValue: true),
        autoSyncEnabled:
            HiveService.getSetting('auto_sync_enabled', defaultValue: false),
        autoSyncInterval: intervalHours,
        syncOnWifiOnly:
            HiveService.getSetting('sync_on_wifi_only', defaultValue: true),
        lastSyncTime: lastSyncTimeMs > 0
            ? DateTime.fromMillisecondsSinceEpoch(lastSyncTimeMs)
            : null,
        dailyBudget:
            HiveService.getSetting('daily_budget', defaultValue: 0.0) == 0.0
                ? null
                : HiveService.getSetting('daily_budget', defaultValue: 0.0)
                    as double?,
        weeklyBudget:
            HiveService.getSetting('weekly_budget', defaultValue: 0.0) == 0.0
                ? null
                : HiveService.getSetting('weekly_budget', defaultValue: 0.0)
                    as double?,
        monthlyBudget:
            HiveService.getSetting('monthly_budget', defaultValue: 0.0) == 0.0
                ? null
                : HiveService.getSetting('monthly_budget', defaultValue: 0.0)
                    as double?,
        alertThreshold:
            HiveService.getSetting('alert_threshold', defaultValue: 80.0)
                as double?,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAtMs),
      );
    } catch (e) {
      print('❌ [SettingsSync] Error loading settings locally: $e');
      return null;
    }
  }

  /// Convert interval string to hours
  static int _intervalStringToHours(String interval) {
    switch (interval) {
      case '6h':
        return 6;
      case '8h':
        return 8;
      case '12h':
        return 12;
      case '24h':
        return 24;
      default:
        return 0;
    }
  }

  /// Sync settings on login: download from MongoDB and merge with local
  static Future<UserSettingsModel> syncSettingsOnLogin(String userId) async {
    print('🔄 [SettingsSync] Syncing settings for user: $userId');

    try {
      // Try to download from MongoDB
      final cloudSettings = await downloadSettingsFromMongoDB();
      final localSettings = loadSettingsLocally(userId);

      UserSettingsModel finalSettings;

      if (cloudSettings != null && localSettings != null) {
        // Both exist, use the most recent one
        if (cloudSettings.updatedAt.isAfter(localSettings.updatedAt)) {
          print('ℹ️ [SettingsSync] Using cloud settings (more recent)');
          finalSettings = cloudSettings;
        } else {
          print('ℹ️ [SettingsSync] Using local settings (more recent)');
          finalSettings = localSettings;
          // Upload local settings to cloud since they're newer
          await uploadSettingsToMongoDB(localSettings);
        }
      } else if (cloudSettings != null) {
        print('ℹ️ [SettingsSync] Using cloud settings only');
        finalSettings = cloudSettings;
      } else if (localSettings != null) {
        print('ℹ️ [SettingsSync] Using local settings only');
        finalSettings = localSettings;
        // Upload to cloud
        await uploadSettingsToMongoDB(localSettings);
      } else {
        print('ℹ️ [SettingsSync] Creating default settings');
        finalSettings = UserSettingsModel.defaultSettings(userId);
        // Save both locally and to cloud
        await saveSettingsLocally(finalSettings);
        await uploadSettingsToMongoDB(finalSettings);
      }

      // Always save the final settings locally for offline access
      await saveSettingsLocally(finalSettings);

      print('✅ [SettingsSync] Settings synced successfully');
      return finalSettings;
    } catch (e) {
      print('❌ [SettingsSync] Error syncing settings: $e');
      // Return default settings on error
      final defaultSettings = UserSettingsModel.defaultSettings(userId);
      await saveSettingsLocally(defaultSettings);
      return defaultSettings;
    }
  }

  /// Update a single setting and sync to MongoDB
  static Future<void> updateSetting({
    required String userId,
    bool? isDarkMode,
    String? currencySymbol,
    bool? notificationsEnabled,
    bool? autoSyncEnabled,
    int? autoSyncInterval,
    bool? syncOnWifiOnly,
    DateTime? lastSyncTime,
    double? dailyBudget,
    double? weeklyBudget,
    double? monthlyBudget,
    double? alertThreshold,
  }) async {
    try {
      // Load current settings
      var currentSettings = loadSettingsLocally(userId) ??
          UserSettingsModel.defaultSettings(userId);

      // Update with new values
      currentSettings = currentSettings.copyWith(
        isDarkMode: isDarkMode,
        currencySymbol: currencySymbol,
        notificationsEnabled: notificationsEnabled,
        autoSyncEnabled: autoSyncEnabled,
        autoSyncInterval: autoSyncInterval,
        syncOnWifiOnly: syncOnWifiOnly,
        lastSyncTime: lastSyncTime,
        dailyBudget: dailyBudget,
        weeklyBudget: weeklyBudget,
        monthlyBudget: monthlyBudget,
        alertThreshold: alertThreshold,
        updatedAt: DateTime.now(),
      );

      // Save locally
      await saveSettingsLocally(currentSettings);

      // Upload to MongoDB
      await uploadSettingsToMongoDB(currentSettings);

      print('✅ [SettingsSync] Setting updated and synced');
    } catch (e) {
      print('❌ [SettingsSync] Error updating setting: $e');
    }
  }
}
