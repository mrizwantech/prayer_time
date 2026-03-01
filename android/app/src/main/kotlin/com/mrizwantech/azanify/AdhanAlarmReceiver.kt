package com.mrizwantech.azanify

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat

class AdhanAlarmReceiver : BroadcastReceiver() {
    
    companion object {
        private const val SILENT_CHANNEL_ID = "prayer_silent_channel"
        private const val SILENT_CHANNEL_NAME = "Prayer Time Reminders"
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        Log.d("AdhanAlarmReceiver", "🔔 Alarm received!")
        
        val prayerName = intent.getStringExtra("prayerName") ?: "Prayer"
        val soundFile = intent.getStringExtra("soundFile") ?: "fajr"
        
        Log.d("AdhanAlarmReceiver", "Prayer: $prayerName, Sound: $soundFile")
        
        val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        
        // Check if sound is enabled for this prayer
        val soundEnabledKey = "flutter.${prayerName.lowercase()}_sound_enabled"
        val soundEnabled = flutterPrefs.getBoolean(soundEnabledKey, true)
        Log.d("AdhanAlarmReceiver", "Sound enabled key: $soundEnabledKey = $soundEnabled")
        
        // Log all related prefs for debugging
        Log.d("AdhanAlarmReceiver", "All sound enabled prefs:")
        flutterPrefs.all.entries
            .filter { it.key.contains("sound_enabled") }
            .forEach { Log.d("AdhanAlarmReceiver", "  ${it.key} = ${it.value}") }

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
        
        // Only start adhan service if sound is enabled for this prayer
        if (soundEnabled) {
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
            
            Log.d("AdhanAlarmReceiver", "✅ Foreground service started for $prayerName")
        } else {
            // Sound disabled - show a silent notification instead
            Log.d("AdhanAlarmReceiver", "🔕 Sound disabled for $prayerName - showing silent notification")
            showSilentNotification(context, prayerName)
        }
        
        // ALWAYS schedule the next prayer, regardless of whether sound was played
        try {
            PrayerScheduler.scheduleNextPrayer(context)
            Log.d("AdhanAlarmReceiver", "✅ Next prayer scheduled successfully")
        } catch (e: Exception) {
            Log.e("AdhanAlarmReceiver", "❌ Error scheduling next prayer: ${e.message}")
        }
    }
    
    private fun showSilentNotification(context: Context, prayerName: String) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        
        // Create notification channel for Android O+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                SILENT_CHANNEL_ID,
                SILENT_CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Silent prayer time reminders"
                setSound(null, null) // No sound
                enableVibration(true)
            }
            notificationManager.createNotificationChannel(channel)
        }
        
        // Create intent to open the app when notification is tapped
        val openAppIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("prayerName", prayerName)
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            prayerName.hashCode(),
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        // Build and show notification
        val notification = NotificationCompat.Builder(context, SILENT_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Time for $prayerName Prayer")
            .setContentText("It's time to pray $prayerName")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setVibrate(longArrayOf(0, 250, 250, 250))
            .build()
        
        // Use prayer name hash as notification ID so each prayer has unique notification
        notificationManager.notify(prayerName.hashCode(), notification)
        Log.d("AdhanAlarmReceiver", "✅ Silent notification shown for $prayerName")
    }
}
