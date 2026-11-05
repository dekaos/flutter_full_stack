package br.com.stuhler.flutter_full_stack

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // The app's own page in system settings, where a refused permission
        // can be granted again. See lib/core/app_settings.dart.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "br.com.stuhler.flutter_full_stack/app_settings",
        ).setMethodCallHandler { call, result ->
            if (call.method != "open") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            startActivity(
                Intent(
                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.fromParts("package", packageName, null),
                ),
            )
            result.success(null)
        }
    }
}
