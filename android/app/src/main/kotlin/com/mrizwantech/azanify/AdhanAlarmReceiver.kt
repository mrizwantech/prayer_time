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
        val soundFile = intent.getStringExtra("soundFile") ?: "azan1"
        
        Log.d("AdhanAlarmReceiver", "Prayer: $prayerName, Sound: $soundFile")
        
        // Start the adhan service - it will play sound AND launch the activity
        val serviceIntent = Intent(context, AdhanService::class.java).apply {
            action = AdhanService.ACTION_PLAY
            putExtra(AdhanService.EXTRA_PRAYER_NAME, prayerName)
            putExtra(AdhanService.EXTRA_SOUND_FILE, soundFile)
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
        
        Log.d("AdhanAlarmReceiver", "✅ Foreground service started")
    }
}
