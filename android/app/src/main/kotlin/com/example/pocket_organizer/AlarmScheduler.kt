package com.example.pocket_organizer

import android.annotation.SuppressLint
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import java.util.*

/**
 * AlarmScheduler - Uses native Android AlarmManager for precise scheduling
 * Similar to how WhatsApp schedules automatic backups
 * 
 * KEY FEATURES:
 * - Works even when app is killed
 * - More reliable than WorkManager for specific intervals
 * - Battery-efficient with WAKELOCK
 * - Survives device reboots (with BOOT_COMPLETED receiver)
 */
object AlarmScheduler {
    private const val TAG = "AlarmScheduler"
    private const val BACKUP_REQUEST_CODE = 1001
    private const val EMAIL_REPORT_REQUEST_CODE = 1002
    private const val PREFS_NAME = "pocket_organizer_prefs"
    private const val KEY_WIFI_ONLY = "backup_wifi_only"
    
    /**
     * Schedule periodic backup at fixed interval
     * @param context Application context
     * @param intervalMinutes Interval in minutes (120, 360, 480, 720, 1440)
     * @param wifiOnly If true, backup only on WiFi. If false, backup on any network
     */
    @SuppressLint("ScheduleExactAlarm")
    fun schedulePeriodicBackup(context: Context, intervalMinutes: Int, wifiOnly: Boolean = true) {
        Log.d(TAG, "========================================")
        Log.d(TAG, "📅 Scheduling periodic backup")
        Log.d(TAG, "Interval: $intervalMinutes minutes")
        Log.d(TAG, "WiFi Only: $wifiOnly")
        Log.d(TAG, "========================================")
        
        try {
            // Save WiFi preference to SharedPreferences
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().putBoolean(KEY_WIFI_ONLY, wifiOnly).apply()
            Log.d(TAG, "✅ Saved WiFi preference: $wifiOnly")
            
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, BackupAlarmReceiver::class.java)
            intent.action = "com.example.pocket_organizer.ACTION_SCHEDULED_BACKUP"
            
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                BACKUP_REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            // Calculate next trigger time
            val intervalMillis = intervalMinutes * 60 * 1000L
            val triggerTime = System.currentTimeMillis() + intervalMillis
            
            // Use setRepeating for regular intervals
            // This is MORE reliable than setInexactRepeating for user-defined intervals
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                // Android 12+ requires SCHEDULE_EXACT_ALARM permission
                if (alarmManager.canScheduleExactAlarms()) {
                    alarmManager.setRepeating(
                        AlarmManager.RTC_WAKEUP,
                        triggerTime,
                        intervalMillis,
                        pendingIntent
                    )
                    Log.d(TAG, "✅ Exact alarm scheduled (Android 12+)")
                } else {
                    Log.w(TAG, "⚠️ Exact alarm permission not granted, using inexact alarm")
                    alarmManager.setInexactRepeating(
                        AlarmManager.RTC_WAKEUP,
                        triggerTime,
                        intervalMillis,
                        pendingIntent
                    )
                }
            } else {
                // Android 11 and below
                alarmManager.setRepeating(
                    AlarmManager.RTC_WAKEUP,
                    triggerTime,
                    intervalMillis,
                    pendingIntent
                )
                Log.d(TAG, "✅ Repeating alarm scheduled (Android <12)")
            }
            
            val nextBackupTime = Date(triggerTime)
            Log.d(TAG, "⏰ Next backup scheduled for: $nextBackupTime")
            Log.d(TAG, "🔄 Interval: $intervalMinutes minutes ($intervalMillis ms)")
            Log.d(TAG, "💡 Alarm will trigger even if app is killed")
            Log.d(TAG, "========================================")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to schedule alarm: ${e.message}")
            e.printStackTrace()
            throw e
        }
    }
    
    /**
     * Cancel periodic backup alarm
     */
    fun cancelPeriodicBackup(context: Context) {
        Log.d(TAG, "🛑 Cancelling periodic backup alarm")
        
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, BackupAlarmReceiver::class.java)
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                BACKUP_REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            alarmManager.cancel(pendingIntent)
            pendingIntent.cancel()
            
            Log.d(TAG, "✅ Periodic backup alarm cancelled")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to cancel alarm: ${e.message}")
            throw e
        }
    }
    
    /**
     * Schedule daily email report at specific time
     * @param context Application context
     * @param hour Hour of day (0-23)
     * @param minute Minute of hour (0-59)
     */
    @SuppressLint("ScheduleExactAlarm")
    fun scheduleDailyEmailReport(context: Context, hour: Int, minute: Int) {
        Log.d(TAG, "========================================")
        Log.d(TAG, "📧 Scheduling daily email report")
        Log.d(TAG, "Time: ${hour.toString().padStart(2, '0')}:${minute.toString().padStart(2, '0')}")
        Log.d(TAG, "========================================")
        
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, BackupAlarmReceiver::class.java)
            intent.action = "com.example.pocket_organizer.ACTION_DAILY_EMAIL_REPORT"
            
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                EMAIL_REPORT_REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            // Calculate next trigger time (today or tomorrow at specified hour:minute)
            val calendar = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, hour)
                set(Calendar.MINUTE, minute)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
                
                // If time has passed today, schedule for tomorrow
                if (timeInMillis <= System.currentTimeMillis()) {
                    add(Calendar.DAY_OF_YEAR, 1)
                }
            }
            
            val triggerTime = calendar.timeInMillis
            val intervalMillis = AlarmManager.INTERVAL_DAY
            
            // Use setRepeating for daily reports
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                // Android 12+ requires SCHEDULE_EXACT_ALARM permission
                if (alarmManager.canScheduleExactAlarms()) {
                    alarmManager.setRepeating(
                        AlarmManager.RTC_WAKEUP,
                        triggerTime,
                        intervalMillis,
                        pendingIntent
                    )
                    Log.d(TAG, "✅ Exact daily alarm scheduled (Android 12+)")
                } else {
                    Log.w(TAG, "⚠️ Exact alarm permission not granted, using inexact alarm")
                    alarmManager.setInexactRepeating(
                        AlarmManager.RTC_WAKEUP,
                        triggerTime,
                        intervalMillis,
                        pendingIntent
                    )
                }
            } else {
                // Android 11 and below
                alarmManager.setRepeating(
                    AlarmManager.RTC_WAKEUP,
                    triggerTime,
                    intervalMillis,
                    pendingIntent
                )
                Log.d(TAG, "✅ Repeating daily alarm scheduled (Android <12)")
            }
            
            val nextReportTime = Date(triggerTime)
            Log.d(TAG, "⏰ Next report scheduled for: $nextReportTime")
            Log.d(TAG, "📧 Will repeat daily at ${hour.toString().padStart(2, '0')}:${minute.toString().padStart(2, '0')}")
            Log.d(TAG, "💡 Alarm will trigger even if app is killed")
            Log.d(TAG, "========================================")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to schedule daily email report: ${e.message}")
            e.printStackTrace()
            throw e
        }
    }
    
    /**
     * Cancel daily email report alarm
     */
    fun cancelDailyEmailReport(context: Context) {
        Log.d(TAG, "🛑 Cancelling daily email report alarm")
        
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, BackupAlarmReceiver::class.java)
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                EMAIL_REPORT_REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            alarmManager.cancel(pendingIntent)
            pendingIntent.cancel()
            
            Log.d(TAG, "✅ Daily email report alarm cancelled")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to cancel daily email report: ${e.message}")
            throw e
        }
    }
}
