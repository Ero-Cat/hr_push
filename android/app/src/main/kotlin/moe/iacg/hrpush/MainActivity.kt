package moe.iacg.hrpush

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    private val CHANNEL = "moe.iacg.hrpush/notification"
    private val NOTIFICATION_ID = 1001
    private val NOTIFICATION_CHANNEL_ID = "hr_push_live"

    override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        io.flutter.plugin.common.MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "updateNotification") {
                val bpm = call.argument<Int>("bpm")
                val deviceName = call.argument<String>("deviceName")
                val isConnected = call.argument<Boolean>("isConnected") ?: false
                
                updateOldNotification(bpm, deviceName, isConnected)
                result.success(null)
            } else if (call.method == "cancelNotification") {
                 val notificationManager = getSystemService(android.content.Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
                 notificationManager.cancel(NOTIFICATION_ID)
                 result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun updateOldNotification(bpm: Int?, deviceName: String?, isConnected: Boolean) {
        android.util.Log.d("HrPush", "updateNotification: bpm=$bpm, connected=$isConnected")
        val notificationManager = getSystemService(android.content.Context.NOTIFICATION_SERVICE) as android.app.NotificationManager

        // Create Channel if needed
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val channel = android.app.NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "Live Activity",
                android.app.NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows live heart rate"
                setSound(null, null)
                enableVibration(false)
                setShowBadge(false)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            }
            notificationManager.createNotificationChannel(channel)
        }

        // Setup RemoteViews
        val views = android.widget.RemoteViews(packageName, R.layout.live_activity)
        
        if (isConnected) {
            val bpmText = if (bpm != null && bpm > 0) "$bpm BPM" else "-- BPM"
            views.setTextViewText(R.id.bpm_value, bpmText)
            views.setTextViewText(R.id.status_text, "Connected to ${deviceName ?: "Device"}")
            views.setTextViewText(R.id.time_text, "LIVE")
            views.setTextColor(R.id.time_text, android.graphics.Color.parseColor("#34C759")) // Green
        } else {
            views.setTextViewText(R.id.bpm_value, "--")
            views.setTextViewText(R.id.status_text, "Disconnected")
            views.setTextViewText(R.id.time_text, "OFF")
            views.setTextColor(R.id.time_text, android.graphics.Color.parseColor("#86868B")) // Grey
        }

        // Build Notification
        val builder = android.app.Notification.Builder(this)
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            builder.setChannelId(NOTIFICATION_CHANNEL_ID)
        }
        
        // Intent to open app
        val intent = android.content.Intent(this, MainActivity::class.java)
        val pendingIntent = android.app.PendingIntent.getActivity(this, 0, intent, android.app.PendingIntent.FLAG_IMMUTABLE)

        // Use valid notification icon (white monochrome)
        builder.setSmallIcon(R.drawable.ic_stat_heart)
        
        builder.setCustomContentView(views)
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
             builder.setCustomBigContentView(views)
             // Style workaround for some Android 12+ devices to ensure custom view shows
             builder.setStyle(android.app.Notification.DecoratedCustomViewStyle())
        }
        
        builder.setContentIntent(pendingIntent)
        builder.setOngoing(true)
        builder.setOnlyAlertOnce(true)
        builder.setVisibility(android.app.Notification.VISIBILITY_PUBLIC)

        try {
            notificationManager.notify(NOTIFICATION_ID, builder.build())
        } catch (e: Exception) {
            android.util.Log.e("HrPush", "Failed to notify", e)
        }
    }
}
