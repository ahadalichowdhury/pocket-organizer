package com.example.pocket_organizer

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Boot Receiver - Auto-starts BackupMonitorService after device reboot
 * Like WhatsApp - service automatically resumes monitoring after reboot
 * 
 * IMPORTANT: Since we removed the UI toggle, the service is now ALWAYS-ON
 * Just like WhatsApp - no user choice, it just works!
 */
class BootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "BootReceiver"
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == "android.intent.action.QUICKBOOT_POWERON" ||
            intent.action == Intent.ACTION_LOCKED_BOOT_COMPLETED) {
            
            Log.i(TAG, "========================================")
            Log.i(TAG, "Device boot completed!")
            Log.i(TAG, "Auto-starting BackupMonitorService (WhatsApp-style)")
            Log.i(TAG, "========================================")
            
            try {
                // Always start the foreground service after boot
                // Just like WhatsApp - no checking, just start!
                BackupMonitorService.startService(context)
                
                Log.i(TAG, "✅ BackupMonitorService started successfully after boot")
                Log.i(TAG, "   Service will now monitor WiFi in background")
                Log.i(TAG, "   User can see persistent notification")
            } catch (e: Exception) {
                Log.e(TAG, "❌ Failed to start service after boot: ${e.message}")
                Log.e(TAG, "   Stack trace: ${e.stackTraceToString()}")
            }
        }
    }
}
