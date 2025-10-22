package com.example.pocket_organizer

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Manages progress notifications for backups
 * Like WhatsApp - shows detailed progress during backup
 */
class BackupProgressNotification(private val context: Context) {
    
    companion object {
        private const val TAG = "BackupProgress"
        private const val CHANNEL_ID = "backup_progress_channel"
        private const val CHANNEL_NAME = "Backup Progress"
        private const val NOTIFICATION_ID = 2001
    }
    
    private val notificationManager: NotificationManager =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    
    init {
        createNotificationChannel()
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW // Low = no sound
            ).apply {
                description = "Shows backup progress like WhatsApp"
                setShowBadge(false)
            }
            notificationManager.createNotificationChannel(channel)
            Log.d(TAG, "Progress notification channel created")
        }
    }
    
    /**
     * Show backup started notification
     */
    fun showBackupStarted() {
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle("Backing up...")
            .setContentText("Starting backup...")
            .setSmallIcon(R.drawable.ic_notification)
            .setOngoing(true) // Cannot be dismissed
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setProgress(100, 0, true) // Indeterminate progress
            .build()
        
        notificationManager.notify(NOTIFICATION_ID, notification)
        Log.d(TAG, "Backup started notification shown")
    }
    
    /**
     * Update progress during backup
     * @param title e.g., "Folders" or "Documents"
     * @param current Current item number
     * @param total Total items
     */
    fun updateProgress(title: String, current: Int, total: Int) {
        val progressPercent = if (total > 0) ((current.toFloat() / total) * 100).toInt() else 0
        val text = "$current of $total $title"
        
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle("Backing up...")
            .setContentText(text)
            .setSmallIcon(R.drawable.ic_notification)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setProgress(100, progressPercent, false) // Determinate progress
            .build()
        
        notificationManager.notify(NOTIFICATION_ID, notification)
        Log.d(TAG, "Progress updated: $text ($progressPercent%)")
    }
    
    /**
     * Show backup completed notification
     * @param itemsSynced Total items synced
     */
    fun showBackupComplete(itemsSynced: Int) {
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle("Backup complete")
            .setContentText("$itemsSynced items backed up successfully")
            .setSmallIcon(R.drawable.ic_notification)
            .setOngoing(false) // Can be dismissed
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setAutoCancel(true) // Auto dismiss when tapped
            .build()
        
        notificationManager.notify(NOTIFICATION_ID, notification)
        Log.d(TAG, "Backup complete notification shown: $itemsSynced items")
        
        // Auto-dismiss after 3 seconds
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            dismissNotification()
        }, 3000)
    }
    
    /**
     * Show backup error notification
     */
    fun showBackupError(error: String) {
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle("Backup failed")
            .setContentText(error)
            .setSmallIcon(R.drawable.ic_notification)
            .setOngoing(false)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .build()
        
        notificationManager.notify(NOTIFICATION_ID, notification)
        Log.e(TAG, "Backup error notification shown: $error")
    }
    
    /**
     * Dismiss the notification
     */
    fun dismissNotification() {
        notificationManager.cancel(NOTIFICATION_ID)
        Log.d(TAG, "Notification dismissed")
    }
}

