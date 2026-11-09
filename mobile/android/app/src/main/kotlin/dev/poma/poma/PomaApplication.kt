package dev.poma.poma

import android.app.Application
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor

class PomaApplication : Application() {
    private var engine: FlutterEngine? = null
    @Synchronized fun engine(): FlutterEngine {
        engine?.let { return it }
        return FlutterEngine(this).also {
            engine = it
            it.plugins.add(PomaPlatformPlugin())
            it.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        }
    }
}
