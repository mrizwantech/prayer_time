package com.mrizwantech.azanify

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val BATTERY_CHANNEL = "com.mrizwantech.azanify/battery"
    private val ADHAN_CHANNEL = "com.mrizwantech.azanify/adhan"
    private val ALARM_CHANNEL = "com.mrizwantech.azanify/adhan_alarm"
    private var adhanChannel: MethodChannel? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Store adhan channel reference for later use
        adhanChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ADHAN_CHANNEL)
        
        // Check if launched from adhan alarm
        handleAdhanLaunch()
        
        // Battery optimization channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BATTERY_CHANNEL).setMethodCallHandler {
            call, result ->
            when (call.method) {
                "isIgnoringBatteryOptimizations" -> {
                    result.success(isIgnoringBatteryOptimizations())
                }
                "requestIgnoreBatteryOptimizations" -> {
                    requestIgnoreBatteryOptimizations()
                    result.success(null)
                }
                "openExactAlarmSettings" -> {
                    openExactAlarmSettings()
                    result.success(null)
                }
                "canDrawOverlays" -> {
                    result.success(canDrawOverlays())
                }
                "requestOverlayPermission" -> {
                    requestOverlayPermission()
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // Adhan playback channel
        adhanChannel?.setMethodCallHandler {
            call, result ->
            Log.d("MainActivity", "Adhan channel received method: ${call.method}")
            when (call.method) {
                "playAdhan" -> {
                    val prayerName = call.argument<String>("prayerName") ?: "Prayer"
                    val soundFile = call.argument<String>("soundFile") ?: "fajr"
                    val volume = call.argument<Double>("volume") ?: 1.0
                    Log.d("MainActivity", "playAdhan: prayerName=$prayerName, soundFile=$soundFile, volume=$volume")
                    playAdhan(prayerName, soundFile, volume.toFloat())
                    result.success(null)
                }
                "stopAdhan" -> {
                    Log.d("MainActivity", "stopAdhan called from Flutter")
                    stopAdhan()
                    result.success(null)
                }
                "pauseAdhan" -> {
                    Log.d("MainActivity", "pauseAdhan called from Flutter")
                    pauseAdhan()
                    result.success(null)
                }
                "resumeAdhan" -> {
                    Log.d("MainActivity", "resumeAdhan called from Flutter")
                    resumeAdhan()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        
        // Alarm scheduling channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ALARM_CHANNEL).setMethodCallHandler {
            call, result ->
            when (call.method) {
                "scheduleAdhanAlarm" -> {
                    val prayerName = call.argument<String>("prayerName") ?: "Prayer"
                    val soundFile = call.argument<String>("soundFile") ?: "fajr"
                    val triggerTime = call.argument<Long>("triggerTime") ?: 0L
                    val requestCode = call.argument<Int>("requestCode") ?: 0
                    val isIsha = call.argument<Boolean>("isIsha") ?: false
                    
                    Log.d("MainActivity", "Scheduling adhan alarm for $prayerName at $triggerTime (isIsha: $isIsha)")
                    scheduleAdhanAlarm(prayerName, soundFile, triggerTime, requestCode, isIsha)
                    result.success(null)
                }
                "cancelAllAlarms" -> {
                    Log.d("MainActivity", "Cancelling all adhan alarms")
                    cancelAllAlarms()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
    
    private fun cancelAllAlarms() {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        // Cancel alarms for request codes 99-110 (sunrise + 5 prayers + buffer)
        for (requestCode in 99..110) {
            val intent = Intent(this, AdhanAlarmReceiver::class.java)
            val pendingIntent = PendingIntent.getBroadcast(
                this,
                requestCode,
                intent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            )
            if (pendingIntent != null) {
                alarmManager.cancel(pendingIntent)
                pendingIntent.cancel()
                Log.d("MainActivity", "Cancelled alarm with requestCode: $requestCode")
            }
        }
    }
    
    private fun handleAdhanLaunch() {
        val autoLaunch = intent?.getBooleanExtra("autoLaunch", false) ?: false
        val prayerName = intent?.getStringExtra("prayerName")
        val fromFullScreen = intent?.getBooleanExtra("fromFullScreen", false) ?: false
        
        Log.d("MainActivity", "handleAdhanLaunch() - autoLaunch=$autoLaunch, prayerName=$prayerName, fromFullScreen=$fromFullScreen")
        
        if (autoLaunch && prayerName != null) {
            Log.d("MainActivity", "📱 Auto-launching adhan player for $prayerName")
            // Delay slightly to ensure Flutter is ready
            window.decorView.postDelayed({
                Log.d("MainActivity", "📱 Invoking launchAdhanPlayer method on Flutter")
                adhanChannel?.invokeMethod("launchAdhanPlayer", mapOf("prayerName" to prayerName))
            }, 500)
        }
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleAdhanLaunch()
    }
    
    private fun scheduleAdhanAlarm(prayerName: String, soundFile: String, triggerTime: Long, requestCode: Int, isIsha: Boolean = false) {
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
        
        Log.d("MainActivity", "Adhan alarm scheduled for $prayerName at $triggerTime (requestCode: $requestCode, isIsha: $isIsha)")
    }

    private fun playAdhan(prayerName: String, soundFile: String, volume: Float = 1.0f) {
        val intent = Intent(this, AdhanService::class.java).apply {
            action = AdhanService.ACTION_PLAY
            putExtra(AdhanService.EXTRA_PRAYER_NAME, prayerName)
            putExtra(AdhanService.EXTRA_SOUND_FILE, soundFile)
            putExtra(AdhanService.EXTRA_VOLUME, volume)
        }
        startService(intent)
    }

    private fun stopAdhan() {
        Log.d("MainActivity", "stopAdhan() creating Intent with ACTION_STOP")
        val intent = Intent(this, AdhanService::class.java).apply {
            action = AdhanService.ACTION_STOP
        }
        Log.d("MainActivity", "Starting AdhanService with ACTION_STOP")
        startService(intent)
        Log.d("MainActivity", "startService called")
    }
    
    private fun pauseAdhan() {
        val intent = Intent(this, AdhanService::class.java).apply {
            action = AdhanService.ACTION_PAUSE
        }
        startService(intent)
    }
    
    private fun resumeAdhan() {
        val intent = Intent(this, AdhanService::class.java).apply {
            action = AdhanService.ACTION_RESUME
        }
        startService(intent)
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = getSystemService(POWER_SERVICE) as PowerManager
            val packageName = packageName
            return powerManager.isIgnoringBatteryOptimizations(packageName)
        }
        return true
    }

    private fun requestIgnoreBatteryOptimizations() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent()
            val packageName = packageName
            val powerManager = getSystemService(POWER_SERVICE) as PowerManager
            
            if (!powerManager.isIgnoringBatteryOptimizations(packageName)) {
                intent.action = Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
                intent.data = Uri.parse("package:$packageName")
                startActivity(intent)
            }
        }
    }

    private fun openExactAlarmSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
            intent.data = Uri.parse("package:$packageName")
            startActivity(intent)
        }
    }
    
    private fun canDrawOverlays(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
    }
    
    private fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (!Settings.canDrawOverlays(this)) {
                val intent = Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:$packageName")
                )
                startActivity(intent)
            }
        }
    }
}
