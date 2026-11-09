package dev.poma.poma

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.media.MediaMetadata
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.FlutterInjector
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors
import java.io.ByteArrayOutputStream
import kotlin.math.min

/** Engine-scoped OS integration; no SQLite access and no independent countdown. */
class PomaAudioBridge(private val context: Context, messenger: BinaryMessenger) {
    companion object { @Volatile var instance: PomaAudioBridge? = null }
    private val main = Handler(Looper.getMainLooper())
    private val io = Executors.newSingleThreadExecutor()
    private val channel = MethodChannel(messenger, "dev.poma.poma/focus_audio")
    private val audio = context.getSystemService(AudioManager::class.java)
    private val media = MediaSession(context, "Poma focus sounds")
    private var session = emptyMap<String, Any?>()
    private var eligibleRun: String? = null
    private var pending: Pending? = null
    private var closed = false
    private var outputs = outputIds()
    private val noisy = object : BroadcastReceiver() {
        override fun onReceive(c: Context?, intent: Intent?) {
            if (intent?.action == AudioManager.ACTION_AUDIO_BECOMING_NOISY) PomaAudioNative.interrupt(3)
        }
    }
    private val devices = object : AudioDeviceCallback() {
        override fun onAudioDevicesAdded(values: Array<out AudioDeviceInfo>?) = route()
        override fun onAudioDevicesRemoved(values: Array<out AudioDeviceInfo>?) = route()
    }
    private data class Pending(val args: Map<String, Any?>, val result: MethodChannel.Result) {
        val owner get() = (args["owner"] as Number).toLong()
        val generation get() = (args["generation"] as Number).toLong()
        val epoch get() = (args["epoch"] as Number).toLong()
        val deadline get() = (args["startupDeadline"] as Number).toLong()
        val sound get() = (args["sound"] as Number).toInt()
        var finished = false
    }
    init {
        instance = this
        // Load JNI and register native events without opening any audio device.
        PomaAudioNative.owner()
        media.setCallback(object : MediaSession.Callback() {
            override fun onPlay() = control("play")
            override fun onPause() = control("pause")
            override fun onStop() = control("stop")
        }, main)
        channel.setMethodCallHandler { call, result ->
            val args = (call.arguments as? Map<*, *>)?.entries?.associate { it.key.toString() to it.value } ?: emptyMap()
            try {
                when (call.method) {
                    "session" -> {
                        if ((args["owner"] as? Number)?.toLong() == PomaAudioNative.owner()) {
                            session = args
                            if (args["restoration"] == true || args["running"] != true || eligibleRun != args["runId"]) eligibleRun = null
                            updateMedia()
                        }
                        result.success(null)
                    }
                    "prepare" -> begin(Pending(args, result))
                    "start" -> {
                        val code = PomaAudioNative.start((args["owner"] as Number).toLong(),
                            (args["source"] as Number).toLong(), (args["generation"] as Number).toLong(),
                            (args["epoch"] as Number).toLong(), (args["deadline"] as Number).toLong(),
                            (args["volume"] as Number).toDouble())
                        if (code == 1) PomaAudioService.instance?.playing((args["deadline"] as Number).toLong())
                        else cleanup()
                        updateMedia(); result.success(code)
                    }
                    "release" -> io.execute {
                        PomaAudioNative.release((args["owner"] as Number).toLong(), (args["source"] as Number).toLong())
                        main.post { cleanup(); result.success(null) }
                    }
                    else -> result.notImplemented()
                }
            } catch (_: Exception) { result.error("audio", "Sound could not play. Retry.", null); cleanup() }
        }
        if (Build.VERSION.SDK_INT >= 33) context.registerReceiver(noisy, IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY), Context.RECEIVER_NOT_EXPORTED)
        else @Suppress("DEPRECATION") context.registerReceiver(noisy, IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY))
        audio.registerAudioDeviceCallback(devices, main)
    }
    private fun outputIds() = audio.getDevices(AudioManager.GET_DEVICES_OUTPUTS).map { it.id }.sorted()
    private fun route() {
        val next = outputIds()
        if (outputs != next && PomaAudioNative.busy() != 0L) PomaAudioNative.interrupt(3)
        outputs = next
    }
    private fun current(p: Pending) = !closed && PomaAudioPolicy.current(p.owner, p.generation, p.epoch,
        p.deadline, PomaAudioNative.owner(), PomaAudioNative.generation(), PomaAudioNative.epoch(), PomaAudioNative.now())
    private fun begin(p: Pending) {
        if (closed || p.sound !in 1..4 || !current(p) || pending != null) {
            p.result.error("cancelled", "Sound request is no longer current.", null); return
        }
        pending = p
        eligibleRun = if (p.args["preview"] != true && session["running"] == true) p.args["runId"] as? String else null
        media.setMetadata(MediaMetadata.Builder().putString(MediaMetadata.METADATA_KEY_TITLE, PomaAudioPolicy.titles[p.sound])
            .putString(MediaMetadata.METADATA_KEY_ARTIST, "Poma").build())
        main.postDelayed({
            if (!p.finished && pending === p) {
                PomaAudioNative.interrupt(7)
                finish(p, null, "Sound preparation timed out. Retry.")
            }
        }, min(10000L, ((p.deadline - PomaAudioNative.now()) / 1000).coerceAtLeast(1)))
        try {
            val intent = Intent(context, PomaAudioService::class.java)
            if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(intent) else context.startService(intent)
        } catch (_: Exception) { finish(p, null, "Open Poma to play sounds.") }
    }
    fun serviceReady(service: PomaAudioService) {
        val p = pending
        if (p == null || !current(p)) { cleanup(); return }
        if (!service.acquireFocus()) { finish(p, null, "Audio is in use. Play sounds when ready."); return }
        io.execute {
            try {
                val key = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset("assets/audio/${PomaAudioPolicy.assets[p.sound]}")
                val bytes = context.assets.open(key).use { input ->
                    val output = ByteArrayOutputStream()
                    val buffer = ByteArray(8192)
                    while (true) {
                        val count = input.read(buffer)
                        if (count < 0) break
                        require(output.size() + count <= PomaAudioPolicy.MAX_ASSET_BYTES)
                        output.write(buffer, 0, count)
                    }
                    output.toByteArray()
                }
                val source = if (current(p)) PomaAudioNative.prepare(p.owner, p.generation, p.epoch, p.deadline, p.sound, bytes) else 0L
                main.post {
                    if (p.finished || !current(p)) {
                        if (source > 0) io.execute { PomaAudioNative.release(p.owner, source) }
                        finish(p, null, "Sound request was cancelled.")
                    } else if (source > 0) finish(p, source, null)
                    else finish(p, null, "Sound could not be prepared. Retry.")
                }
            } catch (_: Exception) { main.post { finish(p, null, "Sound could not be prepared. Retry.") } }
        }
    }
    private fun finish(p: Pending, source: Long?, error: String?) {
        if (p.finished) return
        p.finished = true
        if (pending === p) pending = null
        if (source != null) p.result.success(source) else p.result.error("audio", error, null)
        cleanup()
    }
    fun nativeEvent(kind: Int, owner: Long, generation: Long, epoch: Long) {
        main.post {
            if (closed) return@post
            if (owner != PomaAudioNative.owner() || epoch < PomaAudioNative.epoch()) {
                if ((session["owner"] as? Number)?.toLong() != PomaAudioNative.owner()) { session = emptyMap(); eligibleRun = null }
                cleanup(); updateMedia(); return@post
            }
            if (kind != 7) channel.invokeMethod("event", mapOf("kind" to kind, "owner" to owner, "generation" to generation, "epoch" to epoch))
            cleanup(); updateMedia()
        }
    }
    fun control(action: String) {
        PomaAudioNative.reconcile()
        if (action == "play" && (eligibleRun == null || eligibleRun != session["runId"] ||
            session["running"] != true || ((session["deadline"] as? Number)?.toLong() ?: 0) <= PomaAudioNative.now())) return
        val owner = PomaAudioNative.owner(); val generation = PomaAudioNative.generation()
        if (action != "play") PomaAudioNative.interrupt(7)
        channel.invokeMethod("media", mapOf("owner" to owner, "generation" to generation,
            "epoch" to PomaAudioNative.epoch(), "runId" to session["runId"], "segment" to session["segment"], "action" to action))
    }
    fun notificationAction(action: String): PendingIntent {
        val intent = Intent(context, PomaAudioControlReceiver::class.java).setAction(action)
            .putExtra("owner", PomaAudioNative.owner()).putExtra("generation", PomaAudioNative.generation())
        return PendingIntent.getBroadcast(context, if (action == "pause") 71 else 72, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }
    fun mediaToken() = media.sessionToken
    fun title() = media.controller.metadata?.getString(MediaMetadata.METADATA_KEY_TITLE) ?: "Focus sounds"
    private fun updateMedia() {
        val playing = PomaAudioNative.playing() != 0L
        val eligible = eligibleRun != null && eligibleRun == session["runId"] && session["running"] == true &&
            ((session["deadline"] as? Number)?.toLong() ?: 0) > PomaAudioNative.now()
        media.setPlaybackState(PlaybackState.Builder().setActions(PlaybackState.ACTION_PLAY or PlaybackState.ACTION_PAUSE or PlaybackState.ACTION_STOP)
            .setState(if (playing) PlaybackState.STATE_PLAYING else PlaybackState.STATE_PAUSED, 0, if (playing) 1f else 0f).build())
        media.isActive = playing || eligible
        if (!playing && !eligible) media.setMetadata(null)
    }
    fun cleanup() {
        if (PomaAudioNative.busy() == 0L && pending?.let { current(it) && !it.finished } != true) PomaAudioService.instance?.finishPlayback()
    }
    fun close() {
        if (closed) return
        PomaAudioNative.interrupt(7)
        pending?.let { finish(it, null, "Audio closed.") }
        closed = true; cleanup()
        channel.setMethodCallHandler(null)
        context.unregisterReceiver(noisy); audio.unregisterAudioDeviceCallback(devices)
        media.release(); io.shutdown()
        if (instance === this) instance = null
    }
}

class PomaAudioControlReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        // A stale system action may create a process, but never an engine or audio.
        val bridge = PomaAudioBridge.instance ?: return
        if (intent.getLongExtra("owner", -1) != PomaAudioNative.owner() ||
            intent.getLongExtra("generation", -1) != PomaAudioNative.generation()) return
        intent.action?.takeIf { it == "pause" || it == "stop" }?.let { bridge.control(it) }
    }
}
