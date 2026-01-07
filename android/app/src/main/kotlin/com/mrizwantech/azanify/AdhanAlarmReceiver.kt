package com.mrizwantech.azanify

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

class AdhanAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.d("AdhanAlarmReceiver", "🔔 Alarm received!")
        
        val prayerName = intent.getStringExtra("prayerName") ?: "Prayer"
        val soundFile = intent.getStringExtra("soundFile") ?: "fajr"
        val isIsha = intent.getBooleanExtra("isIsha", false)
        
        Log.d("AdhanAlarmReceiver", "Prayer: $prayerName, Sound: $soundFile, isIsha: $isIsha")
        
        // Get saved adhan volume from Flutter SharedPreferences
        // Flutter stores doubles as strings in SharedPreferences
        val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val volume = try {
            // Try reading as float first (in case it was set natively)
            flutterPrefs.getFloat("flutter.adhan_volume", 1.0f)
        } catch (e: ClassCastException) {
            // Flutter stores doubles as strings, so parse it
            val volumeStr = flutterPrefs.getString("flutter.adhan_volume", "1.0")
            volumeStr?.toFloatOrNull() ?: 1.0f
        }
        Log.d("AdhanAlarmReceiver", "Adhan volume: $volume")
        
        // Start the adhan service - it will play sound AND launch the activity
        val serviceIntent = Intent(context, AdhanService::class.java).apply {
            action = AdhanService.ACTION_PLAY
            putExtra(AdhanService.EXTRA_PRAYER_NAME, prayerName)
            putExtra(AdhanService.EXTRA_SOUND_FILE, soundFile)
            putExtra(AdhanService.EXTRA_VOLUME, volume)
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
        
        Log.d("AdhanAlarmReceiver", "✅ Foreground service started")
        
        // If this is Isha prayer, trigger rescheduling for tomorrow
        if (isIsha) {
            Log.d("AdhanAlarmReceiver", "🌙 Isha prayer - scheduling tomorrow's prayers")
            triggerReschedule(context)
        }
    }
    
    private fun triggerReschedule(context: Context) {
        try {
            // Set a flag in SharedPreferences to indicate reschedule is needed
            val prefs = context.getSharedPreferences("adhan_prefs", Context.MODE_PRIVATE)
            prefs.edit()
                .putBoolean("needs_reschedule", true)
                .putLong("reschedule_requested_at", System.currentTimeMillis())
                .apply()
            
            Log.d("AdhanAlarmReceiver", "📅 Reschedule flag set - will reschedule when app opens or via WorkManager")
            
            // Start the reschedule service to do it immediately in background
            val rescheduleIntent = Intent(context, RescheduleService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(rescheduleIntent)
            } else {
                context.startService(rescheduleIntent)
            }
            
            Log.d("AdhanAlarmReceiver", "✅ RescheduleService started")
        } catch (e: Exception) {
            Log.e("AdhanAlarmReceiver", "❌ Error triggering reschedule: ${e.message}")
        }
    }
}
