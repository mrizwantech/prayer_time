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
        
        Log.d("AdhanAlarmReceiver", "Prayer: $prayerName, Sound: $soundFile")
        
        // Get saved adhan volume from Flutter SharedPreferences
        // Flutter stores doubles as strings in SharedPreferences
        val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

        fun parseVolume(raw: Any?): Float? {
            return when (raw) {
                is Float -> raw
                is Double -> raw.toFloat()
                is Int -> raw.toFloat()
                is Long -> java.lang.Double.longBitsToDouble(raw).toFloat()
                is String -> {
                    // shared_preferences may persist doubles as a prefixed string
                    val match = Regex("-?\\d+(?:\\.\\d+)?").findAll(raw).lastOrNull()
                    match?.value?.toFloatOrNull() ?: raw.toFloatOrNull()
                }
                else -> raw?.toString()?.toFloatOrNull()
            }
        }

        val rawVolume = flutterPrefs.all["flutter.adhan_volume"] ?: flutterPrefs.all["adhan_volume"]
        val volume = parseVolume(rawVolume) ?: 1.0f
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
        
        // Schedule the next prayer immediately after receiving this one
        try {
            PrayerScheduler.scheduleNextPrayer(context)
        } catch (e: Exception) {
            Log.e("AdhanAlarmReceiver", "❌ Error scheduling next prayer: ${e.message}")
        }
    }
}
