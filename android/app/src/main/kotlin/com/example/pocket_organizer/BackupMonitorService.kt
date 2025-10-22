package com.example.pocket_organizer

import android.app.*
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.*
import java.net.HttpURLConnection
import java.net.URL

/**
 * Foreground Service for background backup monitoring
 * Similar to WhatsApp's backup service - keeps app alive even when killed
 * 
 * KEY DIFFERENCE FROM FLUTTER APPS:
 * - WhatsApp uses native Java/Kotlin code for backups (can run when app is killed)
 * - We use a hybrid approach:
 *   1. If app is running → Use Flutter (full features)
 *   2. If app is killed → Trigger via AlarmManager to wake app
 * 
 * This ensures backups work even when app is completely killed!
 */
class BackupMonitorService : Service() {
    
    companion object {
        private const val TAG = "BackupMonitorService"
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "backup_monitor_channel"
        private const val CHANNEL_NAME = "Backup Monitor"
        
        // Control flags
        private var isServiceRunning = false
        private var lastBackupTriggerTime = 0L
        private const val BACKUP_DEBOUNCE_MS = 30000L // 30 seconds debounce
        
        fun isRunning(): Boolean = isServiceRunning
        
        fun startService(context: Context) {
            Log.d(TAG, "Starting BackupMonitorService...")
            val intent = Intent(context, BackupMonitorService::class.java)
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
        
        fun stopService(context: Context) {
            Log.d(TAG, "Stopping BackupMonitorService...")
            val intent = Intent(context, BackupMonitorService::class.java)
            context.stopService(intent)
        }
    }
    
    private val serviceScope = CoroutineScope(Dispatchers.IO + Job())
    
    // BroadcastReceiver to monitor network changes
    private val networkChangeReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            Log.d(TAG, "Network change detected in foreground service")
            
            if (isWiFiConnected(context)) {
                Log.d(TAG, "WiFi connected - triggering backup")
                onWiFiConnected(context)
            }
        }
    }
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "onCreate() called")
        isServiceRunning = true
        
        // Create notification channel for Android O and above
        createNotificationChannel()
        
        // Start as foreground service with notification
        startForeground(NOTIFICATION_ID, createNotification("Monitoring for auto-backup"))
        
        // Register network change receiver
        registerNetworkReceiver()
        
        Log.d(TAG, "Service started successfully (WhatsApp-style)")
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "onStartCommand() called")
        return START_STICKY // Restart service if killed by system
    }
    
    override fun onBind(intent: Intent?): IBinder? {
        return null // Not a bound service
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "onDestroy() called")
        isServiceRunning = false
        
        // Cancel all coroutines
        serviceScope.cancel()
        
        // Unregister network receiver
        try {
            unregisterReceiver(networkChangeReceiver)
            Log.d(TAG, "Network receiver unregistered")
        } catch (e: Exception) {
            Log.e(TAG, "Error unregistering receiver: ${e.message}")
        }
        
        Log.d(TAG, "Service destroyed")
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW // Low importance = no sound
            ).apply {
                description = "Monitors WiFi for automatic backups (like WhatsApp)"
                setShowBadge(false)
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
            Log.d(TAG, "Notification channel created")
        }
    }
    
    private fun createNotification(contentText: String): Notification {
        // Intent to open MainActivity when notification is tapped
        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            notificationIntent,
            PendingIntent.FLAG_IMMUTABLE
        )
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Pocket Organizer")
            .setContentText(contentText)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentIntent(pendingIntent)
            .setOngoing(true) // Cannot be dismissed by user
            .setPriority(NotificationCompat.PRIORITY_LOW) // Low priority = no sound
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }
    
    private fun registerNetworkReceiver() {
        val filter = IntentFilter().apply {
            addAction(ConnectivityManager.CONNECTIVITY_ACTION)
            addAction("android.net.wifi.WIFI_STATE_CHANGED")
        }
        
        registerReceiver(networkChangeReceiver, filter)
        Log.d(TAG, "Network receiver registered")
    }
    
    /**
     * Called when WiFi connection is detected
     * 
     * WHATSAPP-STYLE SOLUTION:
     * Uses TWO approaches simultaneously:
     * 1. Send broadcast to MainActivity (if app is running)
     * 2. Wake up the app using PendingIntent (if app is killed)
     */
    private fun onWiFiConnected(context: Context) {
        // Debounce: prevent duplicate backups within 30 seconds
        val now = System.currentTimeMillis()
        if (now - lastBackupTriggerTime < BACKUP_DEBOUNCE_MS) {
            Log.d(TAG, "⏭️ Skipping backup trigger (debounce active, ${(BACKUP_DEBOUNCE_MS - (now - lastBackupTriggerTime)) / 1000}s remaining)")
            return
        }
        lastBackupTriggerTime = now
        
        Log.d(TAG, "========================================")
        Log.d(TAG, "WiFi Connected - Triggering backup!")
        Log.d(TAG, "========================================")
        
        // Update notification
        updateNotification("Backup triggered...")
        
        // Approach 1: Try to notify running app via broadcast
        try {
            val broadcastIntent = Intent("com.example.pocket_organizer.WIFI_CONNECTED")
            context.sendBroadcast(broadcastIntent)
            Log.d(TAG, "✅ Broadcast sent (works if app is running)")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error sending broadcast: ${e.message}")
        }
        
        // Approach 2: Wake up the app using PendingIntent (works even if app is killed!)
        try {
            Log.d(TAG, "🚀 Waking up app for backup (WhatsApp style)...")
            
            val wakeUpIntent = Intent(context, MainActivity::class.java).apply {
                action = "com.example.pocket_organizer.ACTION_WIFI_BACKUP"
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra("trigger_backup", true)
                putExtra("source", "foreground_service")
            }
            
            val pendingIntent = PendingIntent.getActivity(
                context,
                999, // Unique request code
                wakeUpIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            // Send the PendingIntent - this will start MainActivity even if app is killed
            pendingIntent.send()
            
            Log.d(TAG, "✅ Wake-up intent sent successfully")
            Log.d(TAG, "   This will start MainActivity and trigger backup")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error waking app: ${e.message}")
        }
        
        // Update notification after 3 seconds
        serviceScope.launch {
            delay(3000)
            updateNotification("Monitoring for auto-backup")
        }
    }
    
    private fun updateNotification(text: String) {
        val notification = createNotification(text)
        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.notify(NOTIFICATION_ID, notification)
    }
    
    /**
     * Check if WiFi is currently connected
     */
    private fun isWiFiConnected(context: Context): Boolean {
        val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val network = connectivityManager.activeNetwork ?: return false
            val capabilities = connectivityManager.getNetworkCapabilities(network) ?: return false
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)
        } else {
            @Suppress("DEPRECATION")
            val networkInfo = connectivityManager.activeNetworkInfo ?: return false
            @Suppress("DEPRECATION")
            networkInfo.isConnected && networkInfo.type == ConnectivityManager.TYPE_WIFI
        }
    }
}
