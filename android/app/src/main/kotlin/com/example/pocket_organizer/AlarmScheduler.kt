package com.example.pocket_organizer

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * AlarmScheduler - Schedules periodic backups using AlarmManager
 * Like WhatsApp - uses native Android alarms instead of WorkManager
 * 
 * WHY ALARMMANAGER INSTEAD OF WORKMANAGER:
 * - WorkManager Dart callback doesn't execute reliably
 * - AlarmManager wakes up the app natively
 * - More reliable for time-critical tasks
 * - Works even when app is killed
 */
class AlarmScheduler {
    companion object {
        private const val TAG = "AlarmScheduler"
        private const val ALARM_REQUEST_CODE = 1002
        private const val EMAIL_REPORT_REQUEST_CODE = 1003
        private const val ACTION_SCHEDULED_BACKUP = "com.example.pocket_organizer.SCHEDULED_BACKUP"
        private const val ACTION_DAILY_EMAIL_REPORT = "com.example.pocket_organizer.DAILY_EMAIL_REPORT"
        
        /**
         * Schedule periodic backup
         * @param context Application context
         * @param intervalMinutes Interval in minutes (e.g., 120 for 2 hours, 2 for 2 minutes)
         */
        fun schedulePeriodicBackup(context: Context, intervalMinutes: Int) {
            Log.d(TAG, "========================================")
            Log.d(TAG, "Scheduling periodic backup")
            Log.d(TAG, "Interval: $intervalMinutes minutes")
            Log.d(TAG, "========================================")
            
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, ScheduledBackupReceiver::class.java).apply {
                action = ACTION_SCHEDULED_BACKUP
            }
            
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                ALARM_REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            // Calculate trigger time (current time + interval)
            val intervalMillis = intervalMinutes * 60 * 1000L
            val triggerAtMillis = System.currentTimeMillis() + intervalMillis
            
            // Cancel any existing alarm
            alarmManager.cancel(pendingIntent)
            
            // Schedule repeating alarm
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                // For Android 6.0+, use setExactAndAllowWhileIdle for better reliability
                // Note: This sets ONE alarm, we'll reschedule after each trigger
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMillis,
                    pendingIntent
                )
                
                Log.d(TAG, "✅ Alarm scheduled (exact, one-time)")
                Log.d(TAG, "   Next backup in $intervalMinutes minutes")
                Log.d(TAG, "   Will auto-reschedule after each backup")
            } else {
                // For older Android, use setRepeating
                alarmManager.setRepeating(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMillis,
                    intervalMillis,
                    pendingIntent
                )
                
                Log.d(TAG, "✅ Repeating alarm scheduled")
                Log.d(TAG, "   Interval: $intervalMinutes minutes")
            }
            
            // Save interval to SharedPreferences for auto-rescheduling
            context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .edit()
                .putInt("flutter.scheduled_backup_interval_minutes", intervalMinutes)
                .apply()
            
            Log.d(TAG, "========================================")
        }
        
        /**
         * Cancel scheduled backup
         */
        fun cancelPeriodicBackup(context: Context) {
            Log.d(TAG, "Cancelling periodic backup...")
            
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, ScheduledBackupReceiver::class.java).apply {
                action = ACTION_SCHEDULED_BACKUP
            }
            
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                ALARM_REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            alarmManager.cancel(pendingIntent)
            
            // Clear saved interval
            context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .edit()
                .remove("flutter.scheduled_backup_interval_minutes")
                .apply()
            
            Log.d(TAG, "✅ Periodic backup cancelled")
        }
        
        /**
         * Schedule daily email report at specific time
         * @param context Application context
         * @param hour Hour of day (0-23), default 11 for 11:00 AM
         * @param minute Minute of hour (0-59), default 0
         */
        fun scheduleDailyEmailReport(context: Context, hour: Int = 11, minute: Int = 0) {
            Log.d(TAG, "========================================")
            Log.d(TAG, "Scheduling daily email report")
            Log.d(TAG, "Time: ${hour.toString().padStart(2, '0')}:${minute.toString().padStart(2, '0')}")
            Log.d(TAG, "========================================")
            
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, DailyEmailReportReceiver::class.java).apply {
                action = ACTION_DAILY_EMAIL_REPORT
            }
            
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                EMAIL_REPORT_REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            // Calculate next trigger time
            val calendar = java.util.Calendar.getInstance().apply {
                set(java.util.Calendar.HOUR_OF_DAY, hour)
                set(java.util.Calendar.MINUTE, minute)
                set(java.util.Calendar.SECOND, 0)
                set(java.util.Calendar.MILLISECOND, 0)
                
                // If time has passed today, schedule for tomorrow
                if (timeInMillis <= System.currentTimeMillis()) {
                    add(java.util.Calendar.DAY_OF_MONTH, 1)
                }
            }
            
            val triggerAtMillis = calendar.timeInMillis
            
            // Cancel any existing alarm
            alarmManager.cancel(pendingIntent)
            
            // Schedule daily repeating alarm
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                // For Android 6.0+, use setExactAndAllowWhileIdle for better reliability
                // Note: This sets ONE alarm, we'll reschedule after each trigger
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMillis,
                    pendingIntent
                )
                
                val hoursUntil = (triggerAtMillis - System.currentTimeMillis()) / (1000 * 60 * 60)
                Log.d(TAG, "✅ Alarm scheduled (exact, one-time)")
                Log.d(TAG, "   Next report in ~$hoursUntil hours")
                Log.d(TAG, "   Will auto-reschedule after each report")
            } else {
                // For older Android, use setRepeating
                val dayInMillis = 24 * 60 * 60 * 1000L
                alarmManager.setRepeating(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMillis,
                    dayInMillis,
                    pendingIntent
                )
                
                Log.d(TAG, "✅ Repeating daily alarm scheduled")
            }
            
            // Save schedule to SharedPreferences
            context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .edit()
                .putInt("flutter.daily_report_hour", hour)
                .putInt("flutter.daily_report_minute", minute)
                .putBoolean("flutter.daily_report_enabled", true)
                .apply()
            
            Log.d(TAG, "========================================")
        }
        
        /**
         * Cancel daily email report
         */
        fun cancelDailyEmailReport(context: Context) {
            Log.d(TAG, "Cancelling daily email report...")
            
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, DailyEmailReportReceiver::class.java).apply {
                action = ACTION_DAILY_EMAIL_REPORT
            }
            
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                EMAIL_REPORT_REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            alarmManager.cancel(pendingIntent)
            
            // Clear saved schedule
            context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .edit()
                .remove("flutter.daily_report_hour")
                .remove("flutter.daily_report_minute")
                .putBoolean("flutter.daily_report_enabled", false)
                .apply()
            
            Log.d(TAG, "✅ Daily email report cancelled")
        }
    }
}

/**
 * BroadcastReceiver that handles scheduled backup alarms
 */
class ScheduledBackupReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "ScheduledBackupReceiver"
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "========================================")
        Log.d(TAG, "⏰ SCHEDULED BACKUP ALARM TRIGGERED!")
        Log.d(TAG, "========================================")
        
        // Trigger backup by waking up the app (same as WiFi-triggered backup)
        val wakeUpIntent = Intent(context, MainActivity::class.java).apply {
            action = "com.example.pocket_organizer.ACTION_SCHEDULED_BACKUP"
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("trigger_backup", true)
            putExtra("source", "scheduled_alarm")
        }
        
        val pendingIntent = PendingIntent.getActivity(
            context,
            998, // Different request code from WiFi backup
            wakeUpIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        try {
            pendingIntent.send()
            Log.d(TAG, "✅ Wake-up intent sent for scheduled backup")
            
            // Reschedule for next interval (for Android 6.0+ which uses one-time alarms)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val intervalMinutes = prefs.getInt("flutter.scheduled_backup_interval_minutes", -1)
                
                if (intervalMinutes > 0) {
                    Log.d(TAG, "🔄 Rescheduling next backup in $intervalMinutes minutes...")
                    AlarmScheduler.schedulePeriodicBackup(context, intervalMinutes)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error sending wake-up intent: ${e.message}")
        }
    }
}

/**
 * BroadcastReceiver that handles daily email report alarms
 */
class DailyEmailReportReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "DailyEmailReportReceiver"
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "========================================")
        Log.d(TAG, "📧 DAILY EMAIL REPORT ALARM TRIGGERED!")
        Log.d(TAG, "========================================")
        
        // Trigger email report by waking up the app
        val wakeUpIntent = Intent(context, MainActivity::class.java).apply {
            action = "com.example.pocket_organizer.ACTION_DAILY_EMAIL_REPORT"
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("trigger_email_report", true)
            putExtra("source", "daily_report_alarm")
        }
        
        val pendingIntent = PendingIntent.getActivity(
            context,
            997, // Unique request code for email reports
            wakeUpIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        try {
            pendingIntent.send()
            Log.d(TAG, "✅ Wake-up intent sent for daily email report")
            
            // Reschedule for next day (for Android 6.0+ which uses one-time alarms)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val hour = prefs.getInt("flutter.daily_report_hour", 11)
                val minute = prefs.getInt("flutter.daily_report_minute", 0)
                val enabled = prefs.getBoolean("flutter.daily_report_enabled", false)
                
                if (enabled) {
                    Log.d(TAG, "🔄 Rescheduling next report for tomorrow at $hour:$minute...")
                    AlarmScheduler.scheduleDailyEmailReport(context, hour, minute)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error sending wake-up intent: ${e.message}")
        }
    }
}
