package com.mrizwantech.azanify

import android.app.*
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat

class AdhanService : Service() {
    private var mediaPlayer: MediaPlayer? = null
    private var audioManager: AudioManager? = null
    private var audioFocusRequest: AudioFocusRequest? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private val CHANNEL_ID = "adhan_alert_channel_v2" // New channel ID for high priority
    private val NOTIFICATION_ID = 9999

    companion object {
        private const val TAG = "AdhanService"
        const val ACTION_PLAY = "PLAY_ADHAN"
        const val ACTION_STOP = "STOP_ADHAN"
        const val ACTION_PAUSE = "PAUSE_ADHAN"
        const val ACTION_RESUME = "RESUME_ADHAN"
        const val EXTRA_PRAYER_NAME = "PRAYER_NAME"
        const val EXTRA_SOUND_FILE = "SOUND_FILE"
    }
    
    private var isPaused = false

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "onStartCommand called with action: ${intent?.action}")
        when (intent?.action) {
            ACTION_PLAY -> {
                val prayerName = intent.getStringExtra(EXTRA_PRAYER_NAME) ?: "Prayer"
                val soundFile = intent.getStringExtra(EXTRA_SOUND_FILE) ?: "azan1"
                Log.d(TAG, "ACTION_PLAY: prayerName=$prayerName, soundFile=$soundFile")
                playAdhan(prayerName, soundFile)
            }
            ACTION_STOP -> {
                Log.d(TAG, "ACTION_STOP received, calling stopAdhan()")
                stopAdhan()
            }
            ACTION_PAUSE -> {
                Log.d(TAG, "ACTION_PAUSE received")
                pauseAdhan()
            }
            ACTION_RESUME -> {
                Log.d(TAG, "ACTION_RESUME received")
                resumeAdhan()
            }
        }
        return START_NOT_STICKY
    }
    
    private fun pauseAdhan() {
        try {
            mediaPlayer?.let {
                if (it.isPlaying) {
                    it.pause()
                    isPaused = true
                    Log.d(TAG, "⏸️ Adhan paused")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error pausing adhan: ${e.message}")
        }
    }
    
    private fun resumeAdhan() {
        try {
            mediaPlayer?.let {
                if (isPaused) {
                    it.start()
                    isPaused = false
                    Log.d(TAG, "▶️ Adhan resumed")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error resuming adhan: ${e.message}")
        }
    }

    private fun playAdhan(prayerName: String, soundFile: String) {
        try {
            Log.d(TAG, "🎵 playAdhan() called: prayerName=$prayerName, soundFile=$soundFile")
            
            // CRITICAL: Start foreground IMMEDIATELY to avoid ForegroundServiceDidNotStartInTimeException
            // This MUST be called within 5 seconds of startForegroundService()
            val notification = createNotificationWithFullScreenIntent(prayerName)
            startForeground(NOTIFICATION_ID, notification)
            Log.d(TAG, "📱 Foreground notification shown (early)")
            
            // Acquire wake lock to ensure device stays awake
            acquireWakeLock()
            
            // Stop any existing playback first
            mediaPlayer?.let {
                if (it.isPlaying) {
                    it.stop()
                }
                it.release()
            }
            mediaPlayer = null

            // Request audio focus
            requestAudioFocus()

            // Get resource ID for the sound file, with fallback to azan1
            var resourceId = resources.getIdentifier(soundFile, "raw", packageName)
            var actualSoundFile = soundFile
            if (resourceId == 0) {
                Log.w(TAG, "Sound file not found: $soundFile, falling back to azan1")
                resourceId = resources.getIdentifier("azan1", "raw", packageName)
                actualSoundFile = "azan1"
            }
            
            if (resourceId == 0) {
                Log.e(TAG, "No sound files available, stopping service")
                releaseWakeLock()
                stopSelf()
                return
            }
            
            Log.d(TAG, "Using sound file: $actualSoundFile (resourceId: $resourceId)")

            // Create media player with proper audio attributes for media playback
            mediaPlayer = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .build()
                )
                setDataSource(resources.openRawResourceFd(resourceId))
                prepare()
                setOnCompletionListener {
                    Log.d(TAG, "Adhan playback completed")
                    stopAdhan()
                }
                start()
            }

            Log.d(TAG, "🎵 MediaPlayer started successfully")
            
            // Launch the activity - need overlay permission on Android 10+
            launchMainActivity(prayerName)

        } catch (e: Exception) {
            Log.e(TAG, "Error playing adhan: ${e.message}")
            releaseWakeLock()
            stopSelf()
        }
    }
    
    private fun launchMainActivity(prayerName: String) {
        try {
            // Check if we have overlay permission (required for Android 10+ background activity launch)
            val canDrawOverlays = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                android.provider.Settings.canDrawOverlays(this)
            } else {
                true
            }
            
            Log.d(TAG, "🚀 Attempting to launch MainActivity... canDrawOverlays=$canDrawOverlays")
            
            val launchIntent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or 
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra("prayerName", prayerName)
                putExtra("autoLaunch", true)
            }
            
            if (canDrawOverlays) {
                // With overlay permission, we can launch directly
                startActivity(launchIntent)
                Log.d(TAG, "✅ MainActivity launched with overlay permission!")
            } else {
                // Fall back to PendingIntent approach
                Log.d(TAG, "⚠️ No overlay permission, trying PendingIntent...")
                val pendingIntent = PendingIntent.getActivity(
                    this,
                    System.currentTimeMillis().toInt(),
                    launchIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                pendingIntent.send()
                Log.d(TAG, "📤 PendingIntent sent")
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to launch MainActivity: ${e.message}", e)
        }
    }
    
    private fun acquireWakeLock() {
        if (wakeLock == null) {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                "Azanify::AdhanWakeLock"
            )
        }
        wakeLock?.acquire(10 * 60 * 1000L) // 10 minute timeout
        Log.d(TAG, "🔓 WakeLock acquired")
    }
    
    private fun releaseWakeLock() {
        wakeLock?.let {
            if (it.isHeld) {
                it.release()
                Log.d(TAG, "🔓 WakeLock released")
            }
        }
        wakeLock = null
    }
    
    private fun createNotificationWithFullScreenIntent(prayerName: String): Notification {
        // Intent for when notification is tapped
        val contentIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("prayerName", prayerName)
            putExtra("autoLaunch", true)
        }
        val contentPendingIntent = PendingIntent.getActivity(
            this, 0, contentIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        // Full screen intent - this is what auto-launches the activity!
        val fullScreenIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_NO_USER_ACTION
            putExtra("prayerName", prayerName)
            putExtra("autoLaunch", true)
            putExtra("fromFullScreen", true)
        }
        val fullScreenPendingIntent = PendingIntent.getActivity(
            this, 1, fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Stop action
        val stopIntent = Intent(this, AdhanService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPendingIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            PendingIntent.getForegroundService(
                this, 2, stopIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        } else {
            PendingIntent.getService(
                this, 2, stopIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }
        
        // Dismiss action (same as stop but also cancels notification)
        val dismissIntent = Intent(this, AdhanService::class.java).apply {
            action = ACTION_STOP
        }
        val dismissPendingIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            PendingIntent.getForegroundService(
                this, 3, dismissIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        } else {
            PendingIntent.getService(
                this, 3, dismissIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("🕌 $prayerName Adhan")
            .setContentText("Tap to view adhan player")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(contentPendingIntent)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .addAction(android.R.drawable.ic_media_pause, "STOP", stopPendingIntent)
            .addAction(android.R.drawable.ic_delete, "DISMISS", dismissPendingIntent)
            .setOngoing(true)
            .setAutoCancel(false)
            .build()
    }

    private fun requestAudioFocus() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                .build()
            
            val focusChangeListener = AudioManager.OnAudioFocusChangeListener { focusChange ->
                when (focusChange) {
                    AudioManager.AUDIOFOCUS_LOSS -> {
                        Log.d(TAG, "Audio focus lost, stopping adhan")
                        stopAdhan()
                    }
                    AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                        Log.d(TAG, "Audio focus lost temporarily, pausing")
                        mediaPlayer?.pause()
                    }
                    AudioManager.AUDIOFOCUS_GAIN -> {
                        Log.d(TAG, "Audio focus gained, resuming")
                        mediaPlayer?.start()
                    }
                }
            }
            
            audioFocusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(audioAttributes)
                .setOnAudioFocusChangeListener(focusChangeListener)
                .build()
            
            audioManager?.requestAudioFocus(audioFocusRequest!!)
        } else {
            @Suppress("DEPRECATION")
            audioManager?.requestAudioFocus(
                null,
                AudioManager.STREAM_MUSIC,
                AudioManager.AUDIOFOCUS_GAIN
            )
        }
    }

    private fun abandonAudioFocus() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioFocusRequest?.let {
                audioManager?.abandonAudioFocusRequest(it)
            }
        } else {
            @Suppress("DEPRECATION")
            audioManager?.abandonAudioFocus(null)
        }
    }

    private fun stopAdhan() {
        Log.d(TAG, "stopAdhan() called")
        try {
            mediaPlayer?.let {
                Log.d(TAG, "MediaPlayer exists. isPlaying: ${it.isPlaying}")
                if (it.isPlaying) {
                    Log.d(TAG, "Stopping MediaPlayer...")
                    it.stop()
                    Log.d(TAG, "MediaPlayer stopped")
                }
                Log.d(TAG, "Releasing MediaPlayer...")
                it.release()
                Log.d(TAG, "MediaPlayer released")
            } ?: Log.d(TAG, "MediaPlayer is null, nothing to stop")
            mediaPlayer = null
            abandonAudioFocus()
            releaseWakeLock()
            Log.d(TAG, "Stopping foreground service...")
            stopForeground(true)
            Log.d(TAG, "Stopping service...")
            stopSelf()
            Log.d(TAG, "stopAdhan() completed")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping adhan: ${e.message}")
        }
    }

    private fun createNotification(prayerName: String, isPlaying: Boolean): Notification {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        intent?.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val stopIntent = Intent(this, AdhanService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPendingIntent = PendingIntent.getService(
            this,
            1,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("🕌 $prayerName Prayer")
            .setContentText(if (isPlaying) "Playing Adhan..." else "Adhan")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .addAction(
                android.R.drawable.ic_delete,
                "STOP",
                stopPendingIntent
            )
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // High-priority channel for heads-up banner notifications
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Adhan Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Prayer time adhan notifications"
                setSound(null, null) // We handle sound separately via MediaPlayer
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 500, 200, 500)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setBypassDnd(true) // Show even in Do Not Disturb mode
            }
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
