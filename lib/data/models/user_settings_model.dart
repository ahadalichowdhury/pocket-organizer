class UserSettingsModel {
  final String userId;
  final bool isDarkMode;
  final String currencySymbol;
  final bool notificationsEnabled;
  final bool autoSyncEnabled;
  final int autoSyncInterval; // in hours (0 = disabled, 6, 12, 24)
  final bool syncOnWifiOnly;
  final DateTime? lastSyncTime;
  final double? dailyBudget; // Daily budget limit
  final double? weeklyBudget; // Weekly budget limit
  final double? monthlyBudget; // Monthly budget limit
  final double? alertThreshold; // Alert threshold percentage (0-100)
  final bool warrantyRemindersEnabled; // Enable warranty/expiry reminders
  final List<int>
      warrantyReminderDays; // Days before expiry to remind [30, 7, 1]
  final DateTime updatedAt;

  UserSettingsModel({
    required this.userId,
    this.isDarkMode = false,
    this.currencySymbol = '\$',
    this.notificationsEnabled = true,
    this.autoSyncEnabled = false,
    this.autoSyncInterval = 0,
    this.syncOnWifiOnly = true,
    this.lastSyncTime,
    this.dailyBudget,
    this.weeklyBudget,
    this.monthlyBudget,
    this.alertThreshold,
    this.warrantyRemindersEnabled = false,
    this.warrantyReminderDays = const [30, 7, 1],
    required this.updatedAt,
  });

  UserSettingsModel copyWith({
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
    bool? warrantyRemindersEnabled,
    List<int>? warrantyReminderDays,
    DateTime? updatedAt,
  }) {
    return UserSettingsModel(
      userId: userId,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      autoSyncEnabled: autoSyncEnabled ?? this.autoSyncEnabled,
      autoSyncInterval: autoSyncInterval ?? this.autoSyncInterval,
      syncOnWifiOnly: syncOnWifiOnly ?? this.syncOnWifiOnly,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      dailyBudget: dailyBudget ?? this.dailyBudget,
      weeklyBudget: weeklyBudget ?? this.weeklyBudget,
      monthlyBudget: monthlyBudget ?? this.monthlyBudget,
      alertThreshold: alertThreshold ?? this.alertThreshold,
      warrantyRemindersEnabled:
          warrantyRemindersEnabled ?? this.warrantyRemindersEnabled,
      warrantyReminderDays: warrantyReminderDays ?? this.warrantyReminderDays,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'isDarkMode': isDarkMode,
      'currencySymbol': currencySymbol,
      'notificationsEnabled': notificationsEnabled,
      'autoSyncEnabled': autoSyncEnabled,
      'autoSyncInterval': autoSyncInterval,
      'syncOnWifiOnly': syncOnWifiOnly,
      'lastSyncTime': lastSyncTime?.toIso8601String(),
      'dailyBudget': dailyBudget,
      'weeklyBudget': weeklyBudget,
      'monthlyBudget': monthlyBudget,
      'alertThreshold': alertThreshold,
      'warrantyRemindersEnabled': warrantyRemindersEnabled,
      'warrantyReminderDays': warrantyReminderDays,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory UserSettingsModel.fromJson(Map<String, dynamic> json) {
    return UserSettingsModel(
      userId: json['userId'] as String,
      isDarkMode: json['isDarkMode'] as bool? ?? false,
      currencySymbol: json['currencySymbol'] as String? ?? '\$',
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      autoSyncEnabled: json['autoSyncEnabled'] as bool? ?? false,
      autoSyncInterval: json['autoSyncInterval'] as int? ?? 0,
      syncOnWifiOnly: json['syncOnWifiOnly'] as bool? ?? true,
      lastSyncTime: json['lastSyncTime'] != null
          ? DateTime.parse(json['lastSyncTime'] as String)
          : null,
      dailyBudget: json['dailyBudget'] as double?,
      weeklyBudget: json['weeklyBudget'] as double?,
      monthlyBudget: json['monthlyBudget'] as double?,
      alertThreshold: json['alertThreshold'] as double?,
      warrantyRemindersEnabled:
          json['warrantyRemindersEnabled'] as bool? ?? false,
      warrantyReminderDays: json['warrantyReminderDays'] != null
          ? List<int>.from(json['warrantyReminderDays'] as List)
          : [30, 7, 1],
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  factory UserSettingsModel.defaultSettings(String userId) {
    return UserSettingsModel(
      userId: userId,
      updatedAt: DateTime.now(),
    );
  }
}
