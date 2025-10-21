import 'package:hive_flutter/hive_flutter.dart';

/// Local authentication service for demo/testing without Firebase
/// Stores user credentials locally using Hive
class LocalAuthService {
  static const String _usersBoxName = 'local_users';
  static const String _currentUserKey = 'current_user';

  Box? _usersBox;
  Box? _settingsBox;

  Future<void> init() async {
    _usersBox = await Hive.openBox(_usersBoxName);
    _settingsBox = await Hive.openBox('settings');
  }

  /// Sign up with email and password (local only)
  Future<Map<String, dynamic>> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      // Check if user already exists
      if (_usersBox!.containsKey(email)) {
        return {
          'success': false,
          'error': 'An account with this email already exists',
        };
      }

      // Create user
      final user = {
        'email': email,
        'password': password, // In production, hash this!
        'displayName': displayName ?? email.split('@')[0],
        'createdAt': DateTime.now().toIso8601String(),
        'uid': DateTime.now().millisecondsSinceEpoch.toString(),
      };

      await _usersBox!.put(email, user);
      await _settingsBox!.put(_currentUserKey, email);

      return {
        'success': true,
        'user': user,
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to create account: $e',
      };
    }
  }

  /// Sign in with email and password (local only)
  Future<Map<String, dynamic>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      if (!_usersBox!.containsKey(email)) {
        return {
          'success': false,
          'error': 'No account found with this email',
        };
      }

      final user = _usersBox!.get(email) as Map;

      if (user['password'] != password) {
        return {
          'success': false,
          'error': 'Invalid password',
        };
      }

      await _settingsBox!.put(_currentUserKey, email);

      return {
        'success': true,
        'user': user,
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to sign in: $e',
      };
    }
  }

  /// Get current user
  Map<String, dynamic>? get currentUser {
    final email = _settingsBox?.get(_currentUserKey);
    if (email == null) return null;

    final user = _usersBox?.get(email);
    return user as Map<String, dynamic>?;
  }

  /// Check if user is signed in
  bool get isSignedIn => currentUser != null;

  /// Sign out
  Future<void> signOut() async {
    await _settingsBox?.delete(_currentUserKey);
  }

  /// Update display name
  Future<bool> updateDisplayName(String displayName) async {
    try {
      final email = _settingsBox?.get(_currentUserKey);
      if (email == null) return false;

      final user = _usersBox?.get(email) as Map;
      user['displayName'] = displayName;
      await _usersBox?.put(email, user);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Delete account
  Future<bool> deleteAccount() async {
    try {
      final email = _settingsBox?.get(_currentUserKey);
      if (email == null) return false;

      await _usersBox?.delete(email);
      await _settingsBox?.delete(_currentUserKey);
      return true;
    } catch (e) {
      return false;
    }
  }
}
