package dev.poma.poma

import io.flutter.embedding.android.FlutterActivity
import android.os.SystemClock
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.poma.poma/timer_clock")
            .setMethodCallHandler { call, result ->
                if (call.method == "sample") {
                    result.success(mapOf(
                        "utcMicros" to System.currentTimeMillis() * 1000L,
                        "elapsedMicros" to SystemClock.elapsedRealtimeNanos() / 1000L
                    ))
                } else {
                    result.notImplemented()
                }
            }
    }
}
