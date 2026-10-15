package com.example.fitbuddy

import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val STEP_CHANNEL = "io.vyayama.fitbuddy/step_service"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STEP_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startStepService" -> {
                    try {
                        val intent = Intent(this, StepForegroundService::class.java).apply {
                            action = StepForegroundService.ACTION_START
                        }
                        ContextCompat.startForegroundService(this, intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("START_FAILED", e.localizedMessage, null)
                    }
                }
                "stopStepService" -> {
                    try {
                        val intent = Intent(this, StepForegroundService::class.java).apply {
                            action = StepForegroundService.ACTION_STOP
                        }
                        startService(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("STOP_FAILED", e.localizedMessage, null)
                    }
                }
                "getTodaySteps" -> {
                    val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    val todayKey = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
                    val steps = prefs.getInt("flutter.today_steps_$todayKey", 0)
                    result.success(steps)
                }
                else -> result.notImplemented()
            }
        }
    }
}
