package dev.poma.poma

import android.os.SystemClock
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel

/** Application bridges remain attached when the Activity is recreated/hidden. */
class PomaPlatformPlugin : FlutterPlugin {
    private var clock: MethodChannel? = null
    private var audio: PomaAudioBridge? = null
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val context = binding.applicationContext
        PomaAlerts.attach(context, binding.binaryMessenger)
        clock = MethodChannel(binding.binaryMessenger, "dev.poma.poma/timer_clock").also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method != "sample") result.notImplemented()
                else result.success(mapOf("utcMicros" to System.currentTimeMillis() * 1000L,
                    "elapsedMicros" to SystemClock.elapsedRealtimeNanos() / 1000L,
                    "bootCount" to PomaAlerts.bootCount(context)))
            }
        }
        audio = PomaAudioBridge(context, binding.binaryMessenger)
    }
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        audio?.close(); audio = null
        clock?.setMethodCallHandler(null); clock = null
        PomaAlerts.detach()
    }
}
