import 'package:connectivity_plus/connectivity_plus.dart';

/// Service to check internet connectivity and WiFi status
class ConnectivityService {
  static final Connectivity _connectivity = Connectivity();

  /// Check if device has any internet connection (WiFi or Mobile Data)
  static Future<bool> hasInternetConnection() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();

      // Check if connected to WiFi or Mobile Data
      return connectivityResult.contains(ConnectivityResult.wifi) ||
          connectivityResult.contains(ConnectivityResult.mobile);
    } catch (e) {
      print('❌ [Connectivity] Error checking connection: $e');
      return false;
    }
  }

  /// Check if device is connected to WiFi
  static Future<bool> isConnectedToWiFi() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      return connectivityResult.contains(ConnectivityResult.wifi);
    } catch (e) {
      print('❌ [Connectivity] Error checking WiFi: $e');
      return false;
    }
  }

  /// Check if device is connected to mobile data
  static Future<bool> isConnectedToMobileData() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      return connectivityResult.contains(ConnectivityResult.mobile);
    } catch (e) {
      print('❌ [Connectivity] Error checking mobile data: $e');
      return false;
    }
  }

  /// Check if device can proceed with network operation based on WiFi-only setting
  /// Returns true if:
  /// - WiFi-only is OFF and any connection exists
  /// - WiFi-only is ON and connected to WiFi
  static Future<bool> canProceedWithNetworkOperation({
    required bool wifiOnlyMode,
  }) async {
    try {
      if (!wifiOnlyMode) {
        // WiFi-only is OFF, any connection is fine
        return await hasInternetConnection();
      } else {
        // WiFi-only is ON, must be connected to WiFi
        return await isConnectedToWiFi();
      }
    } catch (e) {
      print('❌ [Connectivity] Error checking network operation: $e');
      return false;
    }
  }

  /// Get current connectivity status as string (for logging)
  static Future<String> getConnectionStatus() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();

      if (connectivityResult.contains(ConnectivityResult.wifi)) {
        return 'WiFi';
      } else if (connectivityResult.contains(ConnectivityResult.mobile)) {
        return 'Mobile Data';
      } else if (connectivityResult.contains(ConnectivityResult.ethernet)) {
        return 'Ethernet';
      } else {
        return 'Offline';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  /// Listen to connectivity changes (for future use)
  static Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged;
}

