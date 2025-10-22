package com.example.pocket_organizer

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.util.Log
import io.flutter.plugin.common.MethodChannel

/**
 * Native Android BroadcastReceiver for network connectivity changes
 * Similar to how WhatsApp detects WiFi connection for auto-backup
 */
class NetworkChangeReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "NetworkChangeReceiver"
        private const val CHANNEL = "com.example.pocket_organizer/network"
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "Network change detected")
        
        if (isWiFiConnected(context)) {
            Log.d(TAG, "WiFi connected - triggering backup check")
            
            // Notify Flutter app that WiFi is connected
            // Flutter app will handle the actual backup logic
            notifyFlutterApp(context)
        } else {
            Log.d(TAG, "Not on WiFi - skipping backup")
        }
    }
    
    /**
     * Check if device is connected to WiFi
     */
    private fun isWiFiConnected(context: Context): Boolean {
        val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        
        val network = connectivityManager.activeNetwork ?: return false
        val capabilities = connectivityManager.getNetworkCapabilities(network) ?: return false
        
        return capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)
    }
    
    /**
     * Notify Flutter app to trigger backup
     * This uses MethodChannel to communicate with Dart code
     */
    private fun notifyFlutterApp(context: Context) {
        Log.d(TAG, "Notifying Flutter app to trigger backup")
        
        // Send broadcast that can be picked up by MainActivity
        val intent = Intent("com.example.pocket_organizer.WIFI_CONNECTED")
        context.sendBroadcast(intent)
    }
}

