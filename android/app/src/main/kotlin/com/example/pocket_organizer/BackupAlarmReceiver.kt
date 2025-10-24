package com.example.pocket_organizer

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.util.Log

/**
 * BackupAlarmReceiver - Receives alarms from AlarmManager
 * 
 * When AlarmManager triggers:
 * 1. This receiver wakes up
 * 2. Checks network connectivity (WiFi or mobile data)
 * 3. If WiFi-only mode, checks if connected to WiFi
 * 4. Launches MainActivity with special intent
 * 5. MainActivity triggers Flutter backup via MethodChannel
 * 
 * This is similar to how WhatsApp handles scheduled backups
 */
class BackupAlarmReceiver : BroadcastReceiver() {
    private val TAG = "BackupAlarmReceiver"
    private val PREFS_NAME = "pocket_organizer_prefs"
    private val KEY_WIFI_ONLY = "backup_wifi_only"
    
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        
        Log.d(TAG, "========================================")
        Log.d(TAG, "⏰ ALARM TRIGGERED!")
        Log.d(TAG, "Action: $action")
        Log.d(TAG, "========================================")
        
        when (action) {
            "com.example.pocket_organizer.ACTION_SCHEDULED_BACKUP" -> {
                Log.d(TAG, "🔄 Scheduled backup alarm triggered")
                
                // Check WiFi preference
                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val wifiOnly = prefs.getBoolean(KEY_WIFI_ONLY, true)
                Log.d(TAG, "📶 WiFi Only mode: $wifiOnly")
                
                // Check current network type
                val networkType = getCurrentNetworkType(context)
                Log.d(TAG, "📶 Current network: $networkType")
                
                // If WiFi-only mode is enabled, only proceed if on WiFi
                if (wifiOnly && networkType != "WiFi") {
                    Log.d(TAG, "⚠️ WiFi-only mode enabled but not on WiFi. Skipping backup.")
                    Log.d(TAG, "💡 Backup will run at next scheduled time if WiFi is available")
                    return
                }
                
                // Check if any network is available
                if (networkType == "None") {
                    Log.d(TAG, "⚠️ No network connection. Skipping backup.")
                    Log.d(TAG, "💡 Backup will run at next scheduled time")
                    return
                }
                
                Log.d(TAG, "✅ Network requirements met. Proceeding with backup...")
                triggerBackup(context)
            }
            "com.example.pocket_organizer.ACTION_DAILY_EMAIL_REPORT" -> {
                Log.d(TAG, "📧 Daily email report alarm triggered")
                triggerDailyEmailReport(context)
            }
            else -> {
                Log.w(TAG, "⚠️ Unknown action: $action")
            }
        }
    }
    
    /**
     * Get current network type (WiFi, Mobile, or None)
     */
    private fun getCurrentNetworkType(context: Context): String {
        val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val network = connectivityManager.activeNetwork
            val capabilities = connectivityManager.getNetworkCapabilities(network)
            
            when {
                capabilities == null -> "None"
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "WiFi"
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "Mobile"
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "Ethernet"
                else -> "Unknown"
            }
        } else {
            @Suppress("DEPRECATION")
            val networkInfo = connectivityManager.activeNetworkInfo
            
            when {
                networkInfo == null || !networkInfo.isConnected -> "None"
                networkInfo.type == ConnectivityManager.TYPE_WIFI -> "WiFi"
                networkInfo.type == ConnectivityManager.TYPE_MOBILE -> "Mobile"
                networkInfo.type == ConnectivityManager.TYPE_ETHERNET -> "Ethernet"
                else -> "Unknown"
            }
        }
    }
    
    /**
     * Launch app and trigger backup via MethodChannel
     */
    private fun triggerBackup(context: Context) {
        try {
            Log.d(TAG, "🚀 Launching app for scheduled backup...")
            
            // Create intent to launch MainActivity
            val intent = Intent(context, MainActivity::class.java).apply {
                action = "com.example.pocket_organizer.ACTION_SCHEDULED_BACKUP"
                putExtra("trigger_backup", true)
                putExtra("source", "alarm_manager")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            
            // Start MainActivity (this wakes up the app if needed)
            context.startActivity(intent)
            
            Log.d(TAG, "✅ App launched - MainActivity will trigger Flutter backup")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to launch app: ${e.message}")
            e.printStackTrace()
        }
    }
    
    /**
     * Launch app and trigger daily email report via MethodChannel
     */
    private fun triggerDailyEmailReport(context: Context) {
        try {
            Log.d(TAG, "📧 Launching app for daily email report...")
            
            // Create intent to launch MainActivity
            val intent = Intent(context, MainActivity::class.java).apply {
                action = "com.example.pocket_organizer.ACTION_DAILY_EMAIL_REPORT"
                putExtra("trigger_email_report", true)
                putExtra("source", "alarm_manager")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            
            // Start MainActivity (this wakes up the app if needed)
            context.startActivity(intent)
            
            Log.d(TAG, "✅ App launched - MainActivity will trigger Flutter email report")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to launch app: ${e.message}")
            e.printStackTrace()
        }
    }
}

