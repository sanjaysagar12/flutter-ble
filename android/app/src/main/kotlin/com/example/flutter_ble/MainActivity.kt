package com.example.flutter_ble

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity: FlutterActivity() {
    private var classicAudioMonitor: ClassicAudioMonitor? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        classicAudioMonitor = ClassicAudioMonitor(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        classicAudioMonitor?.dispose()
        classicAudioMonitor = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
