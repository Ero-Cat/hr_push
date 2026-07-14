package moe.iacg.hrpush

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "moe.iacg.hrpush/notification"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startForegroundService" -> {
                        HrForegroundService.start(
                            this,
                            call.argument<Int>("bpm") ?: 0,
                            call.argument<String>("deviceName").orEmpty(),
                            call.argument<Boolean>("isConnected") ?: false,
                        )
                        result.success(null)
                    }

                    "updateNotification" -> {
                        HrForegroundService.update(
                            this,
                            call.argument<Int>("bpm") ?: 0,
                            call.argument<String>("deviceName").orEmpty(),
                            call.argument<Boolean>("isConnected") ?: false,
                        )
                        result.success(null)
                    }

                    "stopForegroundService", "cancelNotification" -> {
                        HrForegroundService.stop(this)
                        result.success(null)
                    }

                    "openBackgroundRuntimeSettings" -> {
                        result.success(openBackgroundRuntimeSettings())
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun openBackgroundRuntimeSettings(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return false

        val powerManager = getSystemService(POWER_SERVICE) as PowerManager
        if (powerManager.isIgnoringBatteryOptimizations(packageName)) return true

        val directRequest = Intent(
            Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
            Uri.parse("package:$packageName"),
        )
        if (directRequest.resolveActivity(packageManager) != null) {
            startActivity(directRequest)
            return true
        }

        val optimizationSettings = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
        if (optimizationSettings.resolveActivity(packageManager) != null) {
            startActivity(optimizationSettings)
            return true
        }

        val appDetails = Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.parse("package:$packageName"),
        )
        if (appDetails.resolveActivity(packageManager) != null) {
            startActivity(appDetails)
            return true
        }

        return false
    }
}
