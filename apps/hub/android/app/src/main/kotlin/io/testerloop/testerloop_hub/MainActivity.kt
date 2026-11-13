package io.testerloop.testerloop_hub

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.testerloop.testerloop_hub.tracker.HubNativePlugin

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        HubNativePlugin(applicationContext).register(flutterEngine)
    }
}
