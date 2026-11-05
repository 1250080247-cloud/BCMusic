package app.bcmusic.personal

import android.app.Notification
import android.app.PendingIntent
import android.content.Intent
import androidx.core.app.NotificationCompat
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.offline.Download
import androidx.media3.exoplayer.offline.DownloadManager
import androidx.media3.exoplayer.offline.DownloadService
import androidx.media3.exoplayer.scheduler.PlatformScheduler
import androidx.media3.exoplayer.scheduler.Scheduler

@UnstableApi
class MusicDownloadService : DownloadService(1001, 1000, "bcmusic-downloads", R.string.download_channel, 0) {
    override fun getDownloadManager(): DownloadManager = MusicLibrary.get(this).downloadManager
    override fun getScheduler(): Scheduler = PlatformScheduler(this, 1002)
    override fun getForegroundNotification(downloads: MutableList<Download>, notMetRequirements: Int): Notification {
        val active = downloads.firstOrNull { it.state == Download.STATE_DOWNLOADING }
        val title = active?.let { runCatching { TrackMetadata.fromBytes(it.request.data).title }.getOrNull() }
        val percent = active?.percentDownloaded ?: -1f
        val pendingIntent = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        return NotificationCompat.Builder(this, "bcmusic-downloads").setSmallIcon(R.drawable.ic_stat_music)
            .setContentTitle(if (active == null) "Đang chờ tải nhạc" else "Đang tải nhạc")
            .setContentText(title ?: "Mở BCMusic để xem hàng tải")
            .setProgress(100, percent.coerceAtLeast(0f).toInt(), percent < 0)
            .setOngoing(true).setOnlyAlertOnce(true).setContentIntent(pendingIntent).build()
    }
}
