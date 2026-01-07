package com.mrizwantech.azanify

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import com.batoulapps.adhan.*
import com.batoulapps.adhan.data.DateComponents
import java.util.*

/**
 * Service that reschedules prayer notifications for the next day.
 * This is triggered after Isha prayer to ensure continuous notifications.
 */
class RescheduleService : Service() {
    
    companion object {
        private const val TAG = "RescheduleService"
        private const val CHANNEL_ID = "reschedule_channel"
        private const val NOTIFICATION_ID = 8888
    }
    
    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "🔄 RescheduleService started")
        
        // Start foreground immediately to avoid ForegroundServiceDidNotStartInTimeException
        val notification = createNotification()
        startForeground(NOTIFICATION_ID, notification)
        
        // Do the rescheduling work
        Thread {
            try {
                rescheduleForTomorrow()
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error rescheduling: ${e.message}", e)
            } finally {
                // Stop the service when done
                stopForeground(true)
                stopSelf()
            }
        }.start()
        
        return START_NOT_STICKY
    }
    
    private fun rescheduleForTomorrow() {
        Log.d(TAG, "📅 Rescheduling prayers for tomorrow...")
        
        // Get stored location and settings
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        
        // Flutter's SharedPreferences stores doubles as Long bits
        // We need to convert them back to double
        val latitudeLong = prefs.getLong("flutter.latitude", 0L)
        val longitudeLong = prefs.getLong("flutter.longitude", 0L)
        
        val latitude = java.lang.Double.longBitsToDouble(latitudeLong)
        val longitude = java.lang.Double.longBitsToDouble(longitudeLong)
        
        if (latitude == 0.0 && longitude == 0.0) {
            Log.e(TAG, "❌ No location stored, cannot reschedule")
            return
        }
        
        Log.d(TAG, "📍 Using location: $latitude, $longitude")
        
        // Get calculation method from preferences
        val methodName = prefs.getString("flutter.calculation_method", "north_america") ?: "north_america"
        val params = getCalculationParameters(methodName)
        
        Log.d(TAG, "🧮 Using calculation method: $methodName")
        
        // Calculate tomorrow's prayer times
        val tomorrow = Calendar.getInstance().apply {
            add(Calendar.DAY_OF_YEAR, 1)
        }
        
        val coordinates = Coordinates(latitude, longitude)
        val dateComponents = DateComponents.from(tomorrow.time)
        val prayerTimes = PrayerTimes(coordinates, dateComponents, params)
        
        Log.d(TAG, "🕌 Tomorrow's prayer times calculated:")
        Log.d(TAG, "   Fajr: ${prayerTimes.fajr}")
        Log.d(TAG, "   Dhuhr: ${prayerTimes.dhuhr}")
        Log.d(TAG, "   Asr: ${prayerTimes.asr}")
        Log.d(TAG, "   Maghrib: ${prayerTimes.maghrib}")
        Log.d(TAG, "   Isha: ${prayerTimes.isha}")
        
        // Get the selected adhan sound
        val soundFile = prefs.getString("flutter.selected_adhan", "azan1") ?: "azan1"
        
        // Schedule alarms for tomorrow's prayers
        // Use IDs 200-204 for tomorrow to avoid conflicts with today's (100-104)
        scheduleAlarm("Fajr", soundFile, prayerTimes.fajr.time, 200, false)
        scheduleAlarm("Dhuhr", soundFile, prayerTimes.dhuhr.time, 201, false)
        scheduleAlarm("Asr", soundFile, prayerTimes.asr.time, 202, false)
        scheduleAlarm("Maghrib", soundFile, prayerTimes.maghrib.time, 203, false)
        scheduleAlarm("Isha", soundFile, prayerTimes.isha.time, 204, true) // isIsha = true
        
        // Also schedule day after tomorrow's prayers (IDs 300-304)
        val dayAfterTomorrow = Calendar.getInstance().apply {
            add(Calendar.DAY_OF_YEAR, 2)
        }
        val dayAfterComponents = DateComponents.from(dayAfterTomorrow.time)
        val dayAfterTimes = PrayerTimes(coordinates, dayAfterComponents, params)
        
        Log.d(TAG, "🕌 Day after tomorrow's prayer times calculated:")
        scheduleAlarm("Fajr", soundFile, dayAfterTimes.fajr.time, 300, false)
        scheduleAlarm("Dhuhr", soundFile, dayAfterTimes.dhuhr.time, 301, false)
        scheduleAlarm("Asr", soundFile, dayAfterTimes.asr.time, 302, false)
        scheduleAlarm("Maghrib", soundFile, dayAfterTimes.maghrib.time, 303, false)
        scheduleAlarm("Isha", soundFile, dayAfterTimes.isha.time, 304, true)
        
        // Clear the reschedule flag
        val adhanPrefs = getSharedPreferences("adhan_prefs", Context.MODE_PRIVATE)
        adhanPrefs.edit()
            .putBoolean("needs_reschedule", false)
            .putLong("last_rescheduled_at", System.currentTimeMillis())
            .apply()
        
        Log.d(TAG, "✅ Successfully rescheduled prayers for tomorrow and day after")
    }
    
    private fun getCalculationParameters(methodName: String): CalculationParameters {
        return when (methodName.lowercase()) {
            "muslim_world_league", "muslimworldleague" -> CalculationMethod.MUSLIM_WORLD_LEAGUE.parameters
            "egyptian" -> CalculationMethod.EGYPTIAN.parameters
            "karachi" -> CalculationMethod.KARACHI.parameters
            "umm_al_qura", "ummalqura" -> CalculationMethod.UMM_AL_QURA.parameters
            "dubai" -> CalculationMethod.DUBAI.parameters
            "moon_sighting_committee", "moonsightingcommittee" -> CalculationMethod.MOON_SIGHTING_COMMITTEE.parameters
            "north_america", "northamerica", "isna" -> CalculationMethod.NORTH_AMERICA.parameters
            "kuwait" -> CalculationMethod.KUWAIT.parameters
            "qatar" -> CalculationMethod.QATAR.parameters
            "singapore" -> CalculationMethod.SINGAPORE.parameters
            // TEHRAN and TURKEY are not available in the Java/Kotlin library
            // Fall back to similar methods
            "tehran" -> CalculationMethod.MUSLIM_WORLD_LEAGUE.parameters
            "turkey" -> CalculationMethod.MUSLIM_WORLD_LEAGUE.parameters
            else -> CalculationMethod.NORTH_AMERICA.parameters
        }
    }
    
    private fun scheduleAlarm(prayerName: String, soundFile: String, triggerTime: Long, requestCode: Int, isIsha: Boolean) {
        // Check if this prayer's sound is enabled
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val soundEnabled = prefs.getBoolean("flutter.${prayerName.lowercase()}_sound_enabled", true)
        
        if (!soundEnabled) {
            Log.d(TAG, "⏭️ Skipping $prayerName - sound disabled")
            return
        }
        
        // Don't schedule if time is in the past
        if (triggerTime <= System.currentTimeMillis()) {
            Log.d(TAG, "⏭️ Skipping $prayerName - time already passed")
            return
        }
        
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        
        val intent = Intent(this, AdhanAlarmReceiver::class.java).apply {
            putExtra("prayerName", prayerName)
            putExtra("soundFile", soundFile)
            putExtra("isIsha", isIsha)
        }
        
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        // Schedule exact alarm
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerTime,
                pendingIntent
            )
        } else {
            alarmManager.setExact(
                AlarmManager.RTC_WAKEUP,
                triggerTime,
                pendingIntent
            )
        }
        
        val calendar = Calendar.getInstance().apply { timeInMillis = triggerTime }
        Log.d(TAG, "⏰ Scheduled $prayerName at ${calendar.time} (requestCode: $requestCode, isIsha: $isIsha)")
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Prayer Reschedule",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Notification shown while rescheduling prayers"
                setShowBadge(false)
            }
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Updating prayer schedule")
            .setContentText("Scheduling tomorrow's prayers...")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
}
