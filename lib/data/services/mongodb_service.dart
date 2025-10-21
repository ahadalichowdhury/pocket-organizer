import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:mongo_dart/mongo_dart.dart';

import '../../core/config/mongodb_config.dart';

/// MongoDB Service for cloud database operations
/// Replaces Firebase Firestore with a proper database
class MongoDBService {
  static Db? _db;
  static bool _isConnected = false;
  static bool _isConnecting = false;
  static DateTime? _lastConnectionAttempt;
  static const Duration _reconnectCooldown = Duration(seconds: 5);

  /// Get MongoDB connection
  static Db? get database => _db;

  /// Check if connected
  static bool get isConnected {
    try {
      return _isConnected && _db != null && _db!.isConnected;
    } catch (e) {
      return false;
    }
  }

  /// Initialize MongoDB connection
  static Future<void> init() async {
    // MongoDB doesn't work on web - skip initialization
    if (kIsWeb) {
      print(
          'ℹ️ [MongoDB] Web platform detected - MongoDB not supported on web');
      print('   Using local-only mode (Hive database)');
      return;
    }

    if (!MongoDBConfig.isEnabled) {
      print('ℹ️ [MongoDB] MongoDB is disabled, using local-only mode');
      return;
    }

    // Prevent multiple simultaneous connection attempts
    if (_isConnecting) {
      print('⏳ [MongoDB] Connection already in progress, waiting...');
      // Wait for existing connection attempt to complete
      for (int i = 0; i < 30; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (!_isConnecting) break;
      }
      return;
    }

    // Check reconnect cooldown
    if (_lastConnectionAttempt != null) {
      final timeSinceLastAttempt = DateTime.now().difference(_lastConnectionAttempt!);
      if (timeSinceLastAttempt < _reconnectCooldown) {
        print('⏳ [MongoDB] Cooldown period, waiting ${_reconnectCooldown.inSeconds - timeSinceLastAttempt.inSeconds}s...');
        return;
      }
    }

    _isConnecting = true;
    _lastConnectionAttempt = DateTime.now();

    try {
      print('🔄 [MongoDB] Connecting to MongoDB...');
      
      // Close existing connection if any
      if (_db != null) {
        try {
          await _db!.close();
        } catch (e) {
          print('⚠️ [MongoDB] Error closing old connection: $e');
        }
        _db = null;
      }

      _db = await Db.create(MongoDBConfig.connectionString);
      await _db!.open();
      _isConnected = true;
      print(
          '✅ [MongoDB] Connected successfully to ${MongoDBConfig.databaseName}');
    } catch (e) {
      _isConnected = false;
      _db = null;
      print('❌ [MongoDB] Connection failed: $e');
      print('⚠️ [MongoDB] App will work in local-only mode');
    } finally {
      _isConnecting = false;
    }
  }

  /// Close MongoDB connection
  static Future<void> close() async {
    if (_db != null && _db!.isConnected) {
      await _db!.close();
      _isConnected = false;
      _db = null;
      print('🔌 [MongoDB] Connection closed');
    }
  }

  /// Ensure connection is active (reconnect if needed)
  static Future<bool> ensureConnection() async {
    // If already connecting, wait for it
    if (_isConnecting) {
      print('⏳ [MongoDB] Waiting for connection...');
      for (int i = 0; i < 30; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (!_isConnecting && isConnected) return true;
        if (!_isConnecting && !isConnected) break;
      }
    }

    // Check if connection exists and is active
    if (_db != null && _db!.isConnected) {
      return true;
    }

    // Connection lost, try to reconnect
    print('🔄 [MongoDB] Connection not available, reconnecting...');
    await init();
    
    return isConnected;
  }

  /// Get collection for the current user (with connection check)
  static Future<DbCollection?> getUserCollection(String collectionName) async {
    // Ensure connection is active
    if (!await ensureConnection()) {
      print('⚠️ [MongoDB] Cannot get collection - not connected');
      return null;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('⚠️ [MongoDB] No user logged in');
      return null;
    }

    return _db!.collection(collectionName);
  }

  /// Test connection
  static Future<bool> testConnection() async {
    if (!await ensureConnection()) {
      return false;
    }

    try {
      await _db!.collection(MongoDBConfig.usersCollection).findOne();
      return true;
    } catch (e) {
      print('❌ [MongoDB] Connection test failed: $e');
      return false;
    }
  }

  /// Reconnect if connection is lost
  static Future<void> reconnect() async {
    print('🔄 [MongoDB] Reconnecting...');
    _isConnected = false;
    await init();
  }
}
