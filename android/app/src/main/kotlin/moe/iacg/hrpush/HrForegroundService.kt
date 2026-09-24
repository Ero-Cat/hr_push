package moe.iacg.hrpush

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Color
import android.os.Build
import android.os.IBinder
import android.widget.RemoteViews

class HrForegroundService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }

        val bpm = intent?.getIntExtra(EXTRA_BPM, 0) ?: 0
        val deviceName = intent?.getStringExtra(EXTRA_DEVICE_NAME).orEmpty()
        val isConnected = intent?.getBooleanExtra(EXTRA_CONNECTED, false) ?: false
        val status = intent?.getStringExtra(EXTRA_STATUS).orEmpty()
        showForegroundNotification(bpm, deviceName, isConnected, status)
        return START_STICKY
    }

    override fun onDestroy() {
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }

    private fun showForegroundNotification(
        bpm: Int,
        deviceName: String,
        isConnected: Boolean,
        status: String,
    ) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                buildNotification(bpm, deviceName, isConnected, status),
                ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE,
            )
        } else {
            startForeground(NOTIFICATION_ID, buildNotification(bpm, deviceName, isConnected, status))
        }
    }

    private fun buildNotification(
        bpm: Int,
        deviceName: String,
        isConnected: Boolean,
        status: String,
    ): Notification {
        createNotificationChannel()

        val views = RemoteViews(packageName, R.layout.live_activity)
        if (isConnected) {
            val bpmText = if (bpm > 0) "$bpm BPM" else "-- BPM"
            views.setTextViewText(R.id.bpm_value, bpmText)
            views.setTextViewText(R.id.status_text, status.ifEmpty { "Connected to $deviceName" })
            views.setTextViewText(R.id.time_text, "LIVE")
            views.setTextColor(R.id.time_text, Color.parseColor("#34C759"))
        } else {
            views.setTextViewText(R.id.bpm_value, "--")
            views.setTextViewText(R.id.status_text, status.ifEmpty { "Disconnected" })
            views.setTextViewText(R.id.time_text, "OFF")
            views.setTextColor(R.id.time_text, Color.parseColor("#86868B"))
        }

        val openApp = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, NOTIFICATION_CHANNEL_ID)
        } else {
            Notification.Builder(this)
        }

        return builder
            .setSmallIcon(R.drawable.ic_stat_heart)
            .setCustomContentView(views)
            .setCustomBigContentView(views)
            .setStyle(Notification.DecoratedCustomViewStyle())
            .setContentIntent(openApp)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            NOTIFICATION_CHANNEL_ID,
            "Live Activity",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Shows live heart rate"
            setSound(null, null)
            enableVibration(false)
            setShowBadge(false)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        manager.createNotificationChannel(channel)
    }

    companion object {
        private const val ACTION_START = "moe.iacg.hrpush.action.START"
        private const val ACTION_UPDATE = "moe.iacg.hrpush.action.UPDATE"
        private const val ACTION_STOP = "moe.iacg.hrpush.action.STOP"
        private const val EXTRA_BPM = "bpm"
        private const val EXTRA_DEVICE_NAME = "deviceName"
        private const val EXTRA_CONNECTED = "isConnected"
        private const val EXTRA_STATUS = "status"
        private const val NOTIFICATION_ID = 1001
        private const val NOTIFICATION_CHANNEL_ID = "hr_push_live"

        fun start(
            context: Context,
            bpm: Int,
            deviceName: String,
            isConnected: Boolean,
            status: String,
        ) {
            val intent = serviceIntent(context, ACTION_START, bpm, deviceName, isConnected, status)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun update(
            context: Context,
            bpm: Int,
            deviceName: String,
            isConnected: Boolean,
            status: String,
        ) {
            context.startService(serviceIntent(context, ACTION_UPDATE, bpm, deviceName, isConnected, status))
        }

        fun stop(context: Context) {
            context.startService(Intent(context, HrForegroundService::class.java).setAction(ACTION_STOP))
        }

        private fun serviceIntent(
            context: Context,
            action: String,
            bpm: Int,
            deviceName: String,
            isConnected: Boolean,
            status: String,
        ) = Intent(context, HrForegroundService::class.java).apply {
            this.action = action
            putExtra(EXTRA_BPM, bpm)
            putExtra(EXTRA_DEVICE_NAME, deviceName)
            putExtra(EXTRA_CONNECTED, isConnected)
            putExtra(EXTRA_STATUS, status)
        }
    }
}
