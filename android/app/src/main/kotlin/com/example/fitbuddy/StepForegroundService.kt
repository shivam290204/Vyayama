package com.example.fitbuddy

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class StepForegroundService : Service(), SensorEventListener {

    private var sensorManager: SensorManager? = null
    private var stepSensor: Sensor? = null
    private var isTracking = false

    companion object {
        const val CHANNEL_ID = "step_tracking_channel"
        const val NOTIFICATION_ID = 2001
        const val ACTION_START = "ACTION_START"
        const val ACTION_STOP = "ACTION_STOP"
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        stepSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopTracking()
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    stopForeground(STOP_FOREGROUND_REMOVE)
                } else {
                    @Suppress("DEPRECATION")
                    stopForeground(true)
                }
                stopSelf()
                return START_NOT_STICKY
            }
            else -> {
                startTracking()
            }
        }
        return START_STICKY
    }

    private fun startTracking() {
        if (!isTracking) {
            stepSensor?.let {
                sensorManager?.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL)
                isTracking = true
            }
        }

        val todaySteps = getTodayStepsFromPrefs()
        val notification = buildNotification(todaySteps)

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) { // Android 14+
                startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            // Fallback for devices with restrictive foreground service policies
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun stopTracking() {
        if (isTracking) {
            sensorManager?.unregisterListener(this)
            isTracking = false
        }
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event == null || event.sensor.type != Sensor.TYPE_STEP_COUNTER) return
        val rawSteps = event.values[0].toInt()

        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val todayKey = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
        val baseKey = "flutter.steps_base_$todayKey"
        val todayStepsKey = "flutter.today_steps_$todayKey"
        val offsetKey = "flutter.steps_offset_$todayKey"

        var baseSteps = prefs.getInt(baseKey, -1)
        var offset = prefs.getInt(offsetKey, 0)

        if (baseSteps <= 0) {
            baseSteps = rawSteps
            prefs.edit().putInt(baseKey, baseSteps).apply()
        } else if (rawSteps < baseSteps) {
            // Phone rebooted: previous count added to offset
            val lastRecorded = prefs.getInt(todayStepsKey, 0)
            offset = lastRecorded
            baseSteps = rawSteps
            prefs.edit().putInt(offsetKey, offset).putInt(baseKey, baseSteps).apply()
        }

        val computed = offset + (rawSteps - baseSteps)
        if (computed >= 0) {
            val previousSaved = prefs.getInt(todayStepsKey, 0)
            if (computed > previousSaved) {
                prefs.edit().putInt(todayStepsKey, computed).apply()
                updateNotification(computed)
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    private fun getTodayStepsFromPrefs(): Int {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val todayKey = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
        return prefs.getInt("flutter.today_steps_$todayKey", 0)
    }

    private fun buildNotification(steps: Int): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val calories = (steps * 0.04).toInt()

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Vyayama • $steps steps")
            .setContentText("Walking: $steps steps today (~$calories kcal)")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()
    }

    private fun updateNotification(steps: Int) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, buildNotification(steps))
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Vyayama Step Tracker",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows real-time step count and keeps step tracking active in the background"
                setShowBadge(false)
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        stopTracking()
        super.onDestroy()
    }
}
