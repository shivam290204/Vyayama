package com.vyayama.fitbuddy

import android.Manifest
import android.content.Context
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.EventChannel

/**
 * Universal Native Android Hardware Step Sensor Engine for Vyayama.
 * 
 * Engineered for cross-OEM reliability across Samsung, Xiaomi/Redmi, OnePlus,
 * Google Pixel, Oppo, Vivo, Motorola, and all standard Android devices.
 * 
 * Features:
 * 1. Primary: Sensor.TYPE_STEP_COUNTER (cumulative hardware counts since boot).
 * 2. Fallback: Sensor.TYPE_STEP_DETECTOR (individual step events) when counter is unavailable.
 * 3. Hardware FIFO queue batching with low-latency flush on app resume.
 * 4. Safe main-thread dispatch via EventChannel.StreamHandler to Flutter.
 * 5. Device boot time calculation via SystemClock.elapsedRealtime().
 * 6. Native persistent backup of latest raw hardware reading and timestamp.
 * 7. Comprehensive Logcat diagnostic telemetry tagged with "VyayamaStepSensor".
 */
class StepSensorManager(private val context: Context) : SensorEventListener, EventChannel.StreamHandler {

    companion object {
        private const val TAG = "VyayamaStepSensor"
        private const val PREFS_NAME = "vyayama_native_step_prefs"
        private const val KEY_LAST_RAW = "last_raw_steps"
        private const val KEY_LAST_TIME = "last_event_time_ms"
        private const val KEY_SENSOR_TYPE = "last_sensor_type"
    }

    private val sensorManager: SensorManager? = 
        context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager

    private val stepCounterSensor: Sensor? = 
        sensorManager?.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)

    private val stepDetectorSensor: Sensor? = 
        sensorManager?.getDefaultSensor(Sensor.TYPE_STEP_DETECTOR)

    private val prefs: SharedPreferences = 
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null

    private var isRegistered = false
    private var activeSensorType: String = "none"

    fun hasPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ContextCompat.checkSelfPermission(
                context, 
                Manifest.permission.ACTIVITY_RECOGNITION
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    /**
     * Registers the hardware motion sensor listener with OEM battery-friendly delay.
     */
    fun register() {
        if (isRegistered) return

        val hasPerm = hasPermission()
        val hasCounter = stepCounterSensor != null
        val hasDetector = stepDetectorSensor != null

        Log.i(TAG, "=== Vyayama Step Sensor Initialization ===")
        Log.i(TAG, "Device: ${Build.MANUFACTURER} ${Build.MODEL} (Android ${Build.VERSION.RELEASE}, API ${Build.VERSION.SDK_INT})")
        Log.i(TAG, "TYPE_STEP_COUNTER: $hasCounter (${stepCounterSensor?.name ?: "None"})")
        Log.i(TAG, "TYPE_STEP_DETECTOR: $hasDetector (${stepDetectorSensor?.name ?: "None"})")
        Log.i(TAG, "ACTIVITY_RECOGNITION Permission: $hasPerm")
        Log.i(TAG, "Device Boot Time: ${getDeviceBootTimeMs()} ms, Uptime: ${SystemClock.elapsedRealtime()} ms")

        if (!hasPerm) {
            Log.w(TAG, "ACTIVITY_RECOGNITION permission not yet granted; native listener registration deferred.")
            return
        }

        if (sensorManager == null) {
            Log.e(TAG, "SensorManager service unavailable on this device.")
            return
        }

        try {
            // Priority 1: Hardware Step Counter (Cumulative since boot)
            if (stepCounterSensor != null) {
                // Batch up to 10 seconds of steps when available to conserve battery,
                // while waking up immediately when flushed on resume.
                val maxLatencyUs = 10_000_000 // 10 seconds in microseconds
                val success = sensorManager.registerListener(
                    this, 
                    stepCounterSensor, 
                    SensorManager.SENSOR_DELAY_NORMAL,
                    maxLatencyUs
                )
                if (success) {
                    isRegistered = true
                    activeSensorType = "counter"
                    Log.i(TAG, "Successfully registered TYPE_STEP_COUNTER listener on ${Build.MANUFACTURER} ${Build.MODEL}.")
                    return
                } else {
                    Log.w(TAG, "Failed to register TYPE_STEP_COUNTER with batching, attempting standard registration...")
                    val fallbackSuccess = sensorManager.registerListener(
                        this,
                        stepCounterSensor,
                        SensorManager.SENSOR_DELAY_NORMAL
                    )
                    if (fallbackSuccess) {
                        isRegistered = true
                        activeSensorType = "counter"
                        Log.i(TAG, "Successfully registered TYPE_STEP_COUNTER with standard delay.")
                        return
                    }
                }
            }

            // Priority 2: Hardware Step Detector (Event per step) fallback
            if (stepDetectorSensor != null) {
                val success = sensorManager.registerListener(
                    this, 
                    stepDetectorSensor, 
                    SensorManager.SENSOR_DELAY_NORMAL
                )
                if (success) {
                    isRegistered = true
                    activeSensorType = "detector"
                    Log.i(TAG, "Registered fallback TYPE_STEP_DETECTOR listener.")
                    return
                }
            }

            Log.w(TAG, "No hardware step sensor could be registered on this device.")
        } catch (e: Exception) {
            Log.e(TAG, "Exception registering sensor listener: ${e.message}", e)
        }
    }

    fun unregister() {
        if (!isRegistered) return
        try {
            sensorManager?.unregisterListener(this)
            isRegistered = false
            activeSensorType = "none"
            Log.i(TAG, "Native motion sensor listener unregistered.")
        } catch (e: Exception) {
            Log.e(TAG, "Error unregistering sensor listener: ${e.message}", e)
        }
    }

    fun onResume() {
        if (!isRegistered && hasPermission()) {
            register()
        }
        flushSensor()
    }

    /**
     * Flushes queued hardware sensor batches so Android immediately delivers
     * all steps taken while the app was in the background or screen was off.
     */
    fun flushSensor(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT && isRegistered) {
            try {
                val flushed = sensorManager?.flush(this) ?: false
                Log.d(TAG, "Flushed native sensor buffer: success=$flushed")
                flushed
            } catch (e: Exception) {
                Log.w(TAG, "Error flushing sensor: ${e.message}")
                false
            }
        } else {
            false
        }
    }

    /**
     * Calculates the exact device boot timestamp in milliseconds since epoch.
     * System.currentTimeMillis() - SystemClock.elapsedRealtime() is standard across all Android OEM versions.
     */
    fun getDeviceBootTimeMs(): Long {
        return System.currentTimeMillis() - SystemClock.elapsedRealtime()
    }

    /**
     * Returns the latest persisted raw hardware sensor reading.
     */
    fun getLatestHardwareReading(): Map<String, Any> {
        val lastRaw = prefs.getInt(KEY_LAST_RAW, -1)
        val lastTime = prefs.getLong(KEY_LAST_TIME, 0L)
        val sensorType = prefs.getString(KEY_SENSOR_TYPE, activeSensorType) ?: "none"

        return mapOf(
            "rawSteps" to lastRaw,
            "timestampMs" to lastTime,
            "sensorType" to sensorType,
            "isRegistered" to isRegistered,
            "activeSensorType" to activeSensorType
        )
    }

    fun getDiagnostics(): Map<String, Any> {
        val lastRaw = prefs.getInt(KEY_LAST_RAW, -1)
        val lastTime = prefs.getLong(KEY_LAST_TIME, 0L)

        return mapOf(
            "stepCounterAvailable" to (stepCounterSensor != null),
            "stepDetectorAvailable" to (stepDetectorSensor != null),
            "sensorName" to (stepCounterSensor?.name ?: stepDetectorSensor?.name ?: "None"),
            "sensorVendor" to (stepCounterSensor?.vendor ?: stepDetectorSensor?.vendor ?: "None"),
            "sensorPower" to (stepCounterSensor?.power?.toDouble() ?: 0.0),
            "hasPermission" to hasPermission(),
            "isRegistered" to isRegistered,
            "activeSensorType" to activeSensorType,
            "deviceModel" to Build.MODEL,
            "manufacturer" to Build.MANUFACTURER,
            "androidVersion" to Build.VERSION.SDK_INT,
            "deviceBootTimeMs" to getDeviceBootTimeMs(),
            "deviceUptimeMs" to SystemClock.elapsedRealtime(),
            "lastNativeRawSteps" to lastRaw,
            "lastNativeEventTimeMs" to lastTime
        )
    }

    // --- SensorEventListener Implementation ---

    override fun onSensorChanged(event: SensorEvent?) {
        if (event == null) return
        val nowMs = System.currentTimeMillis()

        if (event.sensor.type == Sensor.TYPE_STEP_COUNTER) {
            val raw = event.values[0].toInt()

            prefs.edit()
                .putInt(KEY_LAST_RAW, raw)
                .putLong(KEY_LAST_TIME, nowMs)
                .putString(KEY_SENSOR_TYPE, "counter")
                .apply()

            Log.d(TAG, "[TYPE_STEP_COUNTER] Raw: $raw | Time: $nowMs | Device: ${Build.MANUFACTURER} ${Build.MODEL}")

            // Dispatch event to Flutter on Android main looper
            mainHandler.post {
                eventSink?.success(
                    mapOf(
                        "type" to "counter",
                        "steps" to raw,
                        "timestampMs" to nowMs
                    )
                )
            }
        } else if (event.sensor.type == Sensor.TYPE_STEP_DETECTOR) {
            prefs.edit()
                .putLong(KEY_LAST_TIME, nowMs)
                .putString(KEY_SENSOR_TYPE, "detector")
                .apply()

            Log.d(TAG, "[TYPE_STEP_DETECTOR] Step pulse detected at $nowMs")

            mainHandler.post {
                eventSink?.success(
                    mapOf(
                        "type" to "detector",
                        "steps" to 1,
                        "timestampMs" to nowMs
                    )
                )
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        Log.d(TAG, "Sensor accuracy changed: ${sensor?.name} -> accuracy=$accuracy")
    }

    // --- EventChannel.StreamHandler Implementation ---

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        Log.i(TAG, "Flutter attached to native step event stream.")
        this.eventSink = events
        if (!isRegistered) {
            register()
        }
        flushSensor()
    }

    override fun onCancel(arguments: Any?) {
        Log.i(TAG, "Flutter detached from native step event stream.")
        this.eventSink = null
    }
}
