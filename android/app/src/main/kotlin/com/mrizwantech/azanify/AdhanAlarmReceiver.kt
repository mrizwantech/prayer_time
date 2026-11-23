package com.mrizwantech.azanify

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.os.Build
import android.provider.Settings
import android.util.Log
import androidx.core.app.NotificationCompat

class AdhanAlarmReceiver : BroadcastReceiver() {
    
    companion object {
        private const val SILENT_CHANNEL_ID = "prayer_silent_channel"
        private const val SILENT_CHANNEL_NAME = "Prayer Time Reminders"
        private const val DEFAULT_CHANNEL_ID = "prayer_default_sound_channel"
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
        
        val selectedAdhan = flutterPrefs.getString("flutter.selected_adhan", null)
        val savedMode = flutterPrefs.getString("flutter.prayer_sound_mode_$prayerName", null)
        val mode = when {
            !soundEnabled -> "silent"
            savedMode in listOf("defaultTone", "adhan", "silent") -> savedMode
            prayerName != "Fajr" && selectedAdhan == "Silent" -> "silent"
            else -> "adhan"
        }
        val actualSound = when {
            prayerName.equals("Fajr", ignoreCase = true) -> "fajr"
            selectedAdhan.isNullOrEmpty() || selectedAdhan == "Silent" ->
                "Rabeh Ibn Darah Al Jazairi - Adan Al Jazaer"
            else -> selectedAdhan
        }

        if (mode == "adhan") {
            val serviceIntent = Intent(context, AdhanService::class.java).apply {
                action = AdhanService.ACTION_PLAY
                putExtra(AdhanService.EXTRA_PRAYER_NAME, prayerName)
                putExtra(AdhanService.EXTRA_SOUND_FILE, if (prayerName == "Test") soundFile else actualSound)
                putExtra(AdhanService.EXTRA_VOLUME, volume.coerceIn(0f, 1f))
            }
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
            
            Log.d("AdhanAlarmReceiver", "✅ Foreground service started for $prayerName")
        } else {
            showPrayerNotification(context, prayerName, mode == "defaultTone")
        }
        
        // ALWAYS schedule the next prayer, regardless of whether sound was played
        try {
            PrayerScheduler.scheduleNextPrayer(context)
            Log.d("AdhanAlarmReceiver", "✅ Next prayer scheduled successfully")
        } catch (e: Exception) {
            Log.e("AdhanAlarmReceiver", "❌ Error scheduling next prayer: ${e.message}")
        }
    }
    
    private fun showPrayerNotification(context: Context, prayerName: String, playSound: Boolean) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channelId = if (playSound) DEFAULT_CHANNEL_ID else SILENT_CHANNEL_ID
        
        // Create notification channel for Android O+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                if (playSound) "Prayer Time Notifications" else SILENT_CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = if (playSound) "Prayer time reminders with the default sound" else "Silent prayer time reminders"
                if (playSound) {
                    setSound(
                        Settings.System.DEFAULT_NOTIFICATION_URI,
                        AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_NOTIFICATION).build()
                    )
                } else {
                    setSound(null, null)
                }
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
        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Time for $prayerName Prayer")
            .setContentText("It's time to pray $prayerName")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setSound(if (playSound) Settings.System.DEFAULT_NOTIFICATION_URI else null)
            .setVibrate(longArrayOf(0, 250, 250, 250))
            .build()
        
        // Use prayer name hash as notification ID so each prayer has unique notification
        notificationManager.notify(prayerName.hashCode(), notification)
        Log.d("AdhanAlarmReceiver", "Prayer notification shown for $prayerName, sound=$playSound")
    }
}
