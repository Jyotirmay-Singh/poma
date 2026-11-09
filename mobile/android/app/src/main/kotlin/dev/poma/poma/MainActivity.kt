package dev.poma.poma

import io.flutter.embedding.android.FlutterActivity
import android.content.Context
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun provideFlutterEngine(context: Context): FlutterEngine = (application as PomaApplication).engine()
    override fun shouldDestroyEngineWithHost(): Boolean = false
    // Flutter's first frame can be PomaLoader. Report usability only after the
    // restored timer screen has painted, through launch_metrics below.
    override fun onFlutterUiDisplayed() {}
    override fun onResume() {
        PomaAudioNative.reconcile()
        super.onResume()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        PomaAlerts.captureOpen(applicationContext, intent)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.poma.poma/launch_metrics").setMethodCallHandler(null)
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
