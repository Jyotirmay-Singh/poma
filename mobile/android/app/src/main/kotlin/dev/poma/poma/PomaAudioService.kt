package dev.poma.poma

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager

class PomaAudioService : Service() {
    companion object { var instance: PomaAudioService? = null; private set }
    private val main = Handler(Looper.getMainLooper())
    private lateinit var audio: AudioManager
    private lateinit var wake: PowerManager.WakeLock
    private var focus: AudioFocusRequest? = null
    private var focused = false
    private var startId = 0
    private val listener = AudioManager.OnAudioFocusChangeListener { change ->
        if (change == AudioManager.AUDIOFOCUS_LOSS || change == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT ||
            change == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK) PomaAudioNative.interrupt(1)
        // GAIN deliberately does not resume or restart a foreground service.
    }
    override fun onCreate() {
        super.onCreate(); instance = this
        audio = getSystemService(AudioManager::class.java)
        wake = getSystemService(PowerManager::class.java).newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "$packageName:focus-audio")
        wake.setReferenceCounted(false)
        if (Build.VERSION.SDK_INT >= 26) getSystemService(NotificationManager::class.java).createNotificationChannel(
            NotificationChannel(PomaAudioPolicy.CHANNEL, "Focus sounds", NotificationManager.IMPORTANCE_LOW).apply {
                setSound(null, null); enableVibration(false); setShowBadge(false)
            })
    }
    override fun onStartCommand(intent: Intent?, flags: Int, id: Int): Int {
        startId = id
        val bridge = PomaAudioBridge.instance
        if (bridge == null) { stopSelfResult(id); return START_NOT_STICKY }
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, PomaAudioPolicy.CHANNEL)
            else @Suppress("DEPRECATION") Notification.Builder(this)
        val notification = builder.setSmallIcon(R.drawable.ic_stat_poma).setContentTitle(bridge.title())
            .setContentText("Poma").setOngoing(true).setOnlyAlertOnce(true)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .addAction(Notification.Action.Builder(android.R.drawable.ic_media_pause, "Pause sounds", bridge.notificationAction("pause")).build())
            .addAction(Notification.Action.Builder(android.R.drawable.ic_menu_close_clear_cancel, "Stop sounds", bridge.notificationAction("stop")).build())
            .setStyle(Notification.MediaStyle().setMediaSession(bridge.mediaToken()).setShowActionsInCompactView(0, 1)).build()
        try {
            if (Build.VERSION.SDK_INT >= 29) startForeground(PomaAudioPolicy.NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
            else startForeground(PomaAudioPolicy.NOTIFICATION_ID, notification)
            wake.acquire(10000)
            main.post { if (instance === this) bridge.serviceReady(this) }
        } catch (_: Exception) { PomaAudioNative.interrupt(6); finishPlayback() }
        return START_NOT_STICKY
    }
    fun acquireFocus(): Boolean {
        if (focused) return true
        val result = if (Build.VERSION.SDK_INT >= 26) {
            val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build())
                .setWillPauseWhenDucked(true).setAcceptsDelayedFocusGain(false)
                .setOnAudioFocusChangeListener(listener, main).build()
            focus = request; audio.requestAudioFocus(request)
        } else @Suppress("DEPRECATION") audio.requestAudioFocus(listener, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN)
        focused = result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        return focused
    }
    fun playing(deadline: Long) {
        if (wake.isHeld) wake.release()
        wake.acquire(((deadline - PomaAudioNative.now()) / 1000).coerceIn(1, 7200000))
    }
    fun finishPlayback() {
        if (focused) {
            if (Build.VERSION.SDK_INT >= 26) focus?.let { audio.abandonAudioFocusRequest(it) }
            else @Suppress("DEPRECATION") audio.abandonAudioFocus(listener)
        }
        focused = false; focus = null
        if (wake.isHeld) wake.release()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelfResult(startId)
    }
    override fun onTaskRemoved(rootIntent: Intent?) { PomaAudioNative.interrupt(1); finishPlayback(); super.onTaskRemoved(rootIntent) }
    override fun onDestroy() {
        if (instance === this) {
            instance = null
            PomaAudioNative.interrupt(if (PomaAudioNative.busy() != 0L) 1 else 7)
        }
        finishPlayback(); super.onDestroy()
    }
    override fun onBind(intent: Intent?): IBinder? = null
}
