package com.mrizwantech.azanify

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import com.batoulapps.adhan.CalculationMethod
import com.batoulapps.adhan.CalculationParameters
import com.batoulapps.adhan.Coordinates
import com.batoulapps.adhan.PrayerTimes
import com.batoulapps.adhan.data.DateComponents
import java.util.Date

object PrayerScheduler {

    fun scheduleNextPrayer(context: Context) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

        val latitude = readDouble(prefs, "latitude") ?: readDouble(prefs, "flutter.latitude")
        val longitude = readDouble(prefs, "longitude") ?: readDouble(prefs, "flutter.longitude")

        if (latitude == null || longitude == null) {
            Log.e(
                "PrayerScheduler",
                "Location missing, cannot schedule (prefs keys=${prefs.all.keys.joinToString()})"
            )
            return
        }

        val method = prefs.getString("flutter.calculation_method", "north_america") ?: "north_america"
        val params = getCalculationParameters(method)
        val coordinates = Coordinates(latitude, longitude)

        val now = System.currentTimeMillis()
        val today = DateComponents.from(Date())
        val todayTimes = PrayerTimes(coordinates, today, params)

        val todayPrayers = listOf(
            "Fajr" to todayTimes.fajr,
            "Dhuhr" to todayTimes.dhuhr,
            "Asr" to todayTimes.asr,
            "Maghrib" to todayTimes.maghrib,
            "Isha" to todayTimes.isha
        )

        todayPrayers.firstOrNull { it.second.time > now }?.let {
            scheduleAlarm(context, it.first, it.second.time)
            return
        }

        // All passed -> schedule tomorrow Fajr
        val tomorrow = DateComponents.from(Date(System.currentTimeMillis() + 24 * 60 * 60 * 1000))
        val tomorrowTimes = PrayerTimes(coordinates, tomorrow, params)
        scheduleAlarm(context, "Fajr", tomorrowTimes.fajr.time)
    }

    private fun scheduleAlarm(context: Context, prayerName: String, triggerAt: Long) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        if (triggerAt <= System.currentTimeMillis()) {
            Log.w("PrayerScheduler", "Skipping $prayerName - time already passed (${Date(triggerAt)})")
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !alarmManager.canScheduleExactAlarms()) {
            Log.e("PrayerScheduler", "Exact alarm permission not granted; cannot schedule $prayerName")
            return
        }

        val intent = Intent(context, AdhanAlarmReceiver::class.java).apply {
            putExtra("prayerName", prayerName)
            putExtra("soundFile", "fajr") // default; service can override if needed
        }

        // Single deterministic requestCode
        val requestCode = 5000

        val pendingIntent = PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
        } else {
            alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
        }

        Log.d("PrayerScheduler", "Scheduled $prayerName at ${Date(triggerAt)}")
    }

    private fun getCalculationParameters(method: String): CalculationParameters =
        when (method.lowercase()) {
            "muslim_world_league" -> CalculationMethod.MUSLIM_WORLD_LEAGUE.parameters
            "egyptian" -> CalculationMethod.EGYPTIAN.parameters
            "karachi" -> CalculationMethod.KARACHI.parameters
            "umm_al_qura" -> CalculationMethod.UMM_AL_QURA.parameters
            "north_america", "isna" -> CalculationMethod.NORTH_AMERICA.parameters
            else -> CalculationMethod.NORTH_AMERICA.parameters
        }

    private fun readDouble(prefs: android.content.SharedPreferences, key: String): Double? {
        if (!prefs.contains(key)) return null

        val raw = prefs.all[key]
        Log.d("PrayerScheduler", "readDouble($key) raw=$raw (${raw?.javaClass?.simpleName})")

        return when (raw) {
            is Double -> raw
            is Float -> raw.toDouble()
            is Long -> java.lang.Double.longBitsToDouble(raw)
            is Int -> raw.toDouble()
            is String -> {
                // shared_preferences may persist doubles as "This is the prefix for Double.<value>"
                // Extract the last numeric token (handles negatives and decimals)
                val match = Regex("-?\\d+(?:\\.\\d+)?").findAll(raw).lastOrNull()
                match?.value?.toDoubleOrNull()
                    ?: raw.toDoubleOrNull()
                    ?: runCatching { java.lang.Double.longBitsToDouble(raw.toLong()) }.getOrNull()
            }
            else -> {
                // Last resort: try string conversion
                raw?.toString()?.toDoubleOrNull()
            }
        }
    }
}
