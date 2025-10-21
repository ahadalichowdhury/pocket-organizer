import 'package:flutter_dotenv/flutter_dotenv.dart';

/// MongoDB Configuration
///
/// Configuration is loaded from .env file for security.
/// To use MongoDB:
/// 1. Create a MongoDB Atlas account (free tier available) at https://www.mongodb.com/cloud/atlas
/// 2. Create a cluster and database
/// 3. Get your connection string
/// 4. Add it to the .env file (MONGODB_CONNECTION_STRING)

class MongoDBConfig {
  // MongoDB Connection String (loaded from .env)
  // Format: mongodb+srv://<username>:<password>@<cluster>.mongodb.net/<database>?retryWrites=true&w=majority
  static String get connectionString =>
      dotenv.env['MONGODB_CONNECTION_STRING'] ??
      'mongodb://localhost:27017/pocket_organizer';

  // Database name (loaded from .env)
  static String get databaseName =>
      dotenv.env['MONGODB_DATABASE_NAME'] ?? 'pocket_organizer';

  // Whether MongoDB is enabled (loaded from .env)
  static bool get isEnabled =>
      dotenv.env['ENABLE_MONGODB']?.toLowerCase() == 'true';

  // Collection names
  static const String expensesCollection = 'expenses';
  static const String documentsCollection = 'documents';
  static const String foldersCollection = 'folders';
  static const String usersCollection = 'users';
  static const String userSettingsCollection = 'user_settings';

  // Connection timeout
  static const Duration connectionTimeout = Duration(seconds: 10);

  /// Check if MongoDB is configured properly
  static bool get isConfigured {
    final connString = dotenv.env['MONGODB_CONNECTION_STRING'];
    return connString != null &&
        connString.isNotEmpty &&
        !connString.contains('your_username') &&
        !connString.contains('your_password');
  }
}
