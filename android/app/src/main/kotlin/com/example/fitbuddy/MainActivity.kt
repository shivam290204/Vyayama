package com.example.fitbuddy

import android.app.AlarmManager
import android.app.AppOpsManager
import android.app.PictureInPictureParams
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.net.Uri
import android.os.Build
import android.os.Process
import android.provider.Settings
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "io.vyayama.fitbuddy/system_features"
    private var methodChannel: MethodChannel? = null
    private var autoEnterPipOnUserLeave: Boolean = false

    private val STEP_CHANNEL = "io.vyayama.fitbuddy/step_sensor"
    private val STEP_EVENTS_CHANNEL = "io.vyayama.fitbuddy/step_events"
    private var stepSensorManager: StepSensorManager? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize Native Step Sensor Manager
        val stepMgr = StepSensorManager(this)
        stepSensorManager = stepMgr
        stepMgr.register()

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, STEP_EVENTS_CHANNEL).apply {
            setStreamHandler(stepMgr)
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STEP_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSensorDiagnostics" -> {
                        result.success(stepSensorManager?.getDiagnostics() ?: emptyMap<String, Any>())
                    }
                    "flushSensor" -> {
                        result.success(stepSensorManager?.flushSensor() ?: false)
                    }
                    "getDeviceBootTimeMs" -> {
                        result.success(stepSensorManager?.getDeviceBootTimeMs() ?: 0L)
                    }
                    "hasActivityRecognitionPermission" -> {
                        result.success(stepSensorManager?.hasPermission() ?: false)
                    }
                    "getLatestHardwareReading" -> {
                        result.success(stepSensorManager?.getLatestHardwareReading() ?: emptyMap<String, Any>())
                    }
                    else -> result.notImplemented()
                }
            }
        }

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "isPipSupported" -> {
                        result.success(isPipSupported())
                    }
                    "isPipAllowed" -> {
                        result.success(isPipAllowed())
                    }
                    "openPipSettings" -> {
                        openPipSettings()
                        result.success(true)
                    }
                    "enterPip" -> {
                        val aspectX = call.argument<Int>("aspectRatioX") ?: 16
                        val aspectY = call.argument<Int>("aspectRatioY") ?: 9
                        val entered = enterPip(aspectX, aspectY)
                        result.success(entered)
                    }
                    "setAutoEnterPip" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        val aspectX = call.argument<Int>("aspectRatioX") ?: 16
                        val aspectY = call.argument<Int>("aspectRatioY") ?: 9
                        setAutoEnterPip(enabled, aspectX, aspectY)
                        result.success(true)
                    }
                    "isInPipMode" -> {
                        result.success(isInPipMode())
                    }
                    "canScheduleExactAlarms" -> {
                        result.success(canScheduleExactAlarms())
                    }
                    "openAlarmsAndRemindersSettings" -> {
                        openAlarmsAndRemindersSettings()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        stepSensorManager?.onResume()
    }

    override fun onDestroy() {
        stepSensorManager?.unregister()
        super.onDestroy()
    }

    private fun isPipSupported(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
        } else {
            false
        }
    }

    private fun isPipAllowed(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as? AppOpsManager ?: return true
        return try {
            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_PICTURE_IN_PICTURE, Process.myUid(), packageName)
            } else {
                appOps.checkOpNoThrow(AppOpsManager.OPSTR_PICTURE_IN_PICTURE, Process.myUid(), packageName)
            }
            mode == AppOpsManager.MODE_ALLOWED
        } catch (_: Exception) {
            true
        }
    }

    private fun openPipSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                val intent = Intent("android.settings.PICTURE_IN_PICTURE_SETTINGS", Uri.parse("package:$packageName")).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
                return
            } catch (_: Exception) {}
        }
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.parse("package:$packageName")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }

    private fun enterPip(aspectX: Int, aspectY: Int): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && isPipSupported()) {
            val safeX = aspectX.coerceAtLeast(1)
            val safeY = aspectY.coerceAtLeast(1)
            val rational = Rational(safeX, safeY)
            val params = PictureInPictureParams.Builder()
                .setAspectRatio(rational)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                params.setAutoEnterEnabled(true)
                params.setSeamlessResizeEnabled(true)
            }
            return try {
                enterPictureInPictureMode(params.build())
            } catch (_: Exception) {
                false
            }
        }
        return false
    }

    private fun setAutoEnterPip(enabled: Boolean, aspectX: Int, aspectY: Int) {
        autoEnterPipOnUserLeave = enabled
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && isPipSupported()) {
            try {
                val safeX = aspectX.coerceAtLeast(1)
                val safeY = aspectY.coerceAtLeast(1)
                val rational = Rational(safeX, safeY)
                val params = PictureInPictureParams.Builder()
                    .setAspectRatio(rational)
                    .setAutoEnterEnabled(enabled)
                    .setSeamlessResizeEnabled(true)
                    .build()
                setPictureInPictureParams(params)
            } catch (_: Exception) {}
        }
    }

    private fun isInPipMode(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            isInPictureInPictureMode
        } else {
            false
        }
    }

    private fun canScheduleExactAlarms(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as? AlarmManager
            alarmManager?.canScheduleExactAlarms() ?: true
        } else {
            true
        }
    }

    private fun openAlarmsAndRemindersSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            try {
                val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                    data = Uri.parse("package:$packageName")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
                return
            } catch (_: Exception) {}
        }
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.parse("package:$packageName")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        methodChannel?.invokeMethod("onPipModeChanged", isInPictureInPictureMode)
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (autoEnterPipOnUserLeave && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            enterPip(16, 9)
        }
    }
}
