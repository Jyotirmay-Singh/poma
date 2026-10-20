package dev.poma.poma

import io.flutter.embedding.android.FlutterActivity
import android.os.SystemClock
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        PomaAlerts.attach(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
        PomaAlerts.captureOpen(applicationContext, intent)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.poma.poma/timer_clock")
            .setMethodCallHandler { call, result ->
                if (call.method == "sample") {
                    result.success(mapOf(
                        "utcMicros" to System.currentTimeMillis() * 1000L,
                        "elapsedMicros" to SystemClock.elapsedRealtimeNanos() / 1000L,
                        "bootCount" to PomaAlerts.bootCount(applicationContext)
                    ))
                } else {
                    result.notImplemented()
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        PomaAlerts.captureOpen(applicationContext, intent)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        PomaAlerts.detach()
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
