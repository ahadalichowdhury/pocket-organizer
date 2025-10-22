package com.example.pocket_organizer

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ConnectivityManager
import android.os.Build
import android.util.Log
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// 🔧 FIX: Changed from FlutterActivity to FlutterFragmentActivity
// This is required by the local_auth plugin for biometric authentication
// See: https://pub.dev/packages/local_auth#android-integration
class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "com.example.pocket_organizer/network"
    private val SERVICE_CHANNEL = "com.example.pocket_organizer/service"
    private val ALARM_CHANNEL = "com.example.pocket_organizer/alarm"
    private val PROGRESS_CHANNEL = "com.example.pocket_organizer/progress"
    private val TAG = "MainActivity"
    private var methodChannel: MethodChannel? = null
    private var serviceChannel: MethodChannel? = null
    private var alarmChannel: MethodChannel? = null
    private var progressChannel: MethodChannel? = null
    private var receiverRegistered = false
    private var progressNotification: BackupProgressNotification? = null
    
    // BroadcastReceiver to listen for WiFi connection
    private val wifiConnectedReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            Log.d(TAG, "========================================")
            Log.d(TAG, "MainActivity received WiFi broadcast!")
            Log.d(TAG, "========================================")
            
            // Notify Flutter app to trigger backup/sync
            if (methodChannel != null) {
                methodChannel?.invokeMethod("onWiFiConnected", null)
                Log.d(TAG, "✅ Forwarded to Flutter via MethodChannel")
            } else {
                Log.e(TAG, "❌ MethodChannel is null, cannot forward to Flutter")
            }
        }
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Set up MethodChannel to communicate with Flutter
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        Log.d(TAG, "MethodChannel configured: $CHANNEL")
        
        // Check if we were launched by BackupMonitorService for backup
        handleIntent(intent)
        
        // Set up service control channel
        serviceChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SERVICE_CHANNEL)
        serviceChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startForegroundService" -> {
                    try {
                        Log.d(TAG, "Starting foreground service from Flutter")
                        BackupMonitorService.startService(this)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to start foreground service: ${e.message}")
                        result.error("START_FAILED", e.message, null)
                    }
                }
                "stopForegroundService" -> {
                    try {
                        Log.d(TAG, "Stopping foreground service from Flutter")
                        BackupMonitorService.stopService(this)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to stop foreground service: ${e.message}")
                        result.error("STOP_FAILED", e.message, null)
                    }
                }
                "isServiceRunning" -> {
                    val isRunning = BackupMonitorService.isRunning()
                    Log.d(TAG, "Service running status: $isRunning")
                    result.success(isRunning)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        Log.d(TAG, "MethodChannels configured")
        
        // Set up alarm control channel
        alarmChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ALARM_CHANNEL)
        alarmChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "schedulePeriodicBackup" -> {
                    try {
                        val intervalMinutes = call.argument<Int>("intervalMinutes") ?: 0
                        Log.d(TAG, "Scheduling periodic backup: $intervalMinutes minutes")
                        AlarmScheduler.schedulePeriodicBackup(this, intervalMinutes)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to schedule alarm: ${e.message}")
                        result.error("SCHEDULE_FAILED", e.message, null)
                    }
                }
                "cancelPeriodicBackup" -> {
                    try {
                        Log.d(TAG, "Cancelling periodic backup")
                        AlarmScheduler.cancelPeriodicBackup(this)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to cancel alarm: ${e.message}")
                        result.error("CANCEL_FAILED", e.message, null)
                    }
                }
                "scheduleDailyEmailReport" -> {
                    try {
                        val hour = call.argument<Int>("hour") ?: 11
                        val minute = call.argument<Int>("minute") ?: 0
                        Log.d(TAG, "Scheduling daily email report: $hour:$minute")
                        AlarmScheduler.scheduleDailyEmailReport(this, hour, minute)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to schedule daily email report: ${e.message}")
                        result.error("SCHEDULE_FAILED", e.message, null)
                    }
                }
                "cancelDailyEmailReport" -> {
                    try {
                        Log.d(TAG, "Cancelling daily email report")
                        AlarmScheduler.cancelDailyEmailReport(this)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to cancel daily email report: ${e.message}")
                        result.error("CANCEL_FAILED", e.message, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // Set up progress notification channel
        progressNotification = BackupProgressNotification(this)
        progressChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PROGRESS_CHANNEL)
        progressChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "showBackupStarted" -> {
                    progressNotification?.showBackupStarted()
                    result.success(true)
                }
                "updateProgress" -> {
                    val title = call.argument<String>("title") ?: ""
                    val current = call.argument<Int>("current") ?: 0
                    val total = call.argument<Int>("total") ?: 0
                    progressNotification?.updateProgress(title, current, total)
                    result.success(true)
                }
                "showBackupComplete" -> {
                    val itemsSynced = call.argument<Int>("itemsSynced") ?: 0
                    progressNotification?.showBackupComplete(itemsSynced)
                    result.success(true)
                }
                "showBackupError" -> {
                    val error = call.argument<String>("error") ?: "Unknown error"
                    progressNotification?.showBackupError(error)
                    result.success(true)
                }
                "dismissNotification" -> {
                    progressNotification?.dismissNotification()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // Register receiver immediately when Flutter engine is ready
        registerWiFiReceiver()
    }
    
    override fun onResume() {
        super.onResume()
        Log.d(TAG, "onResume() - ensuring receiver is registered")
        registerWiFiReceiver()
    }
    
    override fun onPause() {
        super.onPause()
        Log.d(TAG, "onPause() - keeping receiver registered (app may be in background)")
        // DON'T unregister here - we want to receive broadcasts even when app is in background
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "onDestroy() - unregistering receiver")
        unregisterWiFiReceiver()
    }
    
    /**
     * Handle special intents from BackupMonitorService
     * This allows the service to wake up the app and trigger backups
     */
    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        
        val action = intent.action
        val triggerBackup = intent.getBooleanExtra("trigger_backup", false)
        val source = intent.getStringExtra("source")
        
        Log.d(TAG, "========================================")
        Log.d(TAG, "handleIntent called:")
        Log.d(TAG, "  Action: $action")
        Log.d(TAG, "  Trigger backup: $triggerBackup")
        Log.d(TAG, "  Source: $source")
        Log.d(TAG, "========================================")
        
        if (action == "com.example.pocket_organizer.ACTION_WIFI_BACKUP" && triggerBackup) {
            Log.d(TAG, "🚀 App woken up by BackupMonitorService for WiFi backup!")
            
            // Give Flutter engine a moment to fully initialize
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                if (methodChannel != null) {
                    Log.d(TAG, "✅ Triggering Flutter backup via MethodChannel...")
                    methodChannel?.invokeMethod("onWiFiConnected", null)
                } else {
                    Log.e(TAG, "❌ MethodChannel not ready yet, will retry...")
                    // Retry after another delay
                    android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                        methodChannel?.invokeMethod("onWiFiConnected", null)
                        Log.d(TAG, "✅ Retry: Triggered Flutter backup")
                    }, 1000)
                }
            }, 500)
        } else if (action == "com.example.pocket_organizer.ACTION_SCHEDULED_BACKUP" && triggerBackup) {
            Log.d(TAG, "⏰ App woken up by AlarmManager for SCHEDULED backup!")
            
            // Give Flutter engine a moment to fully initialize
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                if (methodChannel != null) {
                    Log.d(TAG, "✅ Triggering Flutter backup via MethodChannel...")
                    methodChannel?.invokeMethod("onWiFiConnected", null)
                } else {
                    Log.e(TAG, "❌ MethodChannel not ready yet, will retry...")
                    // Retry after another delay
                    android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                        methodChannel?.invokeMethod("onWiFiConnected", null)
                        Log.d(TAG, "✅ Retry: Triggered Flutter backup")
                    }, 1000)
                }
            }, 500)
        } else if (action == "com.example.pocket_organizer.ACTION_DAILY_EMAIL_REPORT" && intent.getBooleanExtra("trigger_email_report", false)) {
            Log.d(TAG, "📧 App woken up by AlarmManager for DAILY EMAIL REPORT!")
            
            // Give Flutter engine a moment to fully initialize
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                if (methodChannel != null) {
                    Log.d(TAG, "✅ Triggering Flutter email report via MethodChannel...")
                    methodChannel?.invokeMethod("onDailyEmailReport", null)
                } else {
                    Log.e(TAG, "❌ MethodChannel not ready yet, will retry...")
                    // Retry after another delay
                    android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                        methodChannel?.invokeMethod("onDailyEmailReport", null)
                        Log.d(TAG, "✅ Retry: Triggered Flutter email report")
                    }, 1000)
                }
            }, 500)
        }
    }
    
    private fun registerWiFiReceiver() {
        if (receiverRegistered) {
            Log.d(TAG, "Receiver already registered, skipping")
            return
        }
        
        try {
            val filter = IntentFilter("com.example.pocket_organizer.WIFI_CONNECTED")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(wifiConnectedReceiver, filter, RECEIVER_NOT_EXPORTED)
            } else {
                registerReceiver(wifiConnectedReceiver, filter)
            }
            receiverRegistered = true
            Log.d(TAG, "✅ WiFi broadcast receiver registered")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error registering receiver: ${e.message}")
        }
    }
    
    private fun unregisterWiFiReceiver() {
        if (!receiverRegistered) {
            Log.d(TAG, "Receiver not registered, skipping unregister")
            return
        }
        
        try {
            unregisterReceiver(wifiConnectedReceiver)
            receiverRegistered = false
            Log.d(TAG, "✅ WiFi broadcast receiver unregistered")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error unregistering receiver: ${e.message}")
        }
    }
}
