package dev.poma.poma

import io.flutter.embedding.android.FlutterActivity
import android.os.SystemClock
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // Flutter's first frame can be PomaLoader. Report usability only after the
    // restored timer screen has painted, through launch_metrics below.
    override fun onFlutterUiDisplayed() {}

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        PomaAlerts.attach(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
        PomaAlerts.captureOpen(applicationContext, intent)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.poma.poma/launch_metrics")
            .setMethodCallHandler { call, result ->
                if (call.method == "firstUsableFrame") {
                    reportFullyDrawn()
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
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
