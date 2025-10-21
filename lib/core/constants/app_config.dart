class AppConfig {
  // App Version
  static const String appVersion = '1.0.0';
  static const int appBuildNumber = 1;

  // Database
  static const String databaseName = 'pocket_organizer_db';
  static const int databaseVersion = 1;

  // Hive Box Names
  static const String foldersBox = 'folders';
  static const String documentsBox = 'documents';
  static const String expensesBox = 'expenses';
  static const String settingsBox = 'settings';

  // Settings Keys
  static const String keyBiometricEnabled = 'biometric_enabled';
  static const String keyNotificationsEnabled = 'notifications_enabled';
  static const String keyDarkMode = 'dark_mode';
  static const String keyHasSeenOnboarding = 'has_seen_onboarding';
  static const String keyLastSyncTime = 'last_sync_time';

  // OCR & AI
  static const double minClassificationConfidence = 0.7;
  static const int maxOcrTextLength = 10000;

  // Image Settings
  static const int imageQuality = 85;
  static const int maxImageWidth = 1920;
  static const int maxImageHeight = 1080;

  // Pagination
  static const int itemsPerPage = 20;
  static const int maxSearchResults = 50;

  // Expiry Alerts (days before)
  static const int warrantyAlertDays = 30;
  static const int prescriptionAlertDays = 7;

  // Date Formats
  static const String dateFormat = 'MMM d, yyyy';
  static const String dateTimeFormat = 'MMM d, yyyy h:mm a';
  static const String monthYearFormat = 'MMMM yyyy';

  // Validation
  static const int minPasswordLength = 6;
  static const int maxTitleLength = 100;
  static const int maxNotesLength = 500;
  static const int maxTagLength = 30;
  static const int maxTagsPerDocument = 10;

  // API
  static const String openAiApiBaseUrl = 'https://api.openai.com/v1';
  static const String openAiModel = 'gpt-4-vision-preview';
  static const int apiTimeout = 30; // seconds

  // Feature Flags
  static const bool enableCloudSync = false;
  static const bool enableAIClassification =
      false; // Set to true if you add OpenAI key
  static const bool enableNotifications = true;
  static const bool enableBiometric = true;

  // URLs
  static const String privacyPolicyUrl = 'https://yourapp.com/privacy';
  static const String termsOfServiceUrl = 'https://yourapp.com/terms';
  static const String supportEmail = 'support@yourapp.com';
}
