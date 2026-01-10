package com.example.overlay_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "BootReceiver"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val MONITORING_KEY = "flutter.is_monitoring_enabled"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == Intent.ACTION_MY_PACKAGE_REPLACED) {

            Log.d(TAG, "Boot/Package update received")

            // Check if monitoring was enabled
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val wasEnabled = prefs.getBoolean(MONITORING_KEY, false)

            if (wasEnabled) {
                Log.d(TAG, "Starting monitoring service after boot")
                val serviceIntent = Intent(context, AppMonitorService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
            } else {
                Log.d(TAG, "Monitoring was not enabled, skipping service start")
            }
        }
    }
}
