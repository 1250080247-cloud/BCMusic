package app.bcmusic.personal

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Handler
import android.os.Looper
import android.os.StatFs
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.util.UnstableApi
import androidx.media3.database.StandaloneDatabaseProvider
import androidx.media3.datasource.cache.NoOpCacheEvictor
import androidx.media3.datasource.cache.SimpleCache
import androidx.media3.datasource.okhttp.OkHttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.exoplayer.offline.Download
import androidx.media3.exoplayer.offline.DownloadManager
import androidx.media3.exoplayer.offline.DownloadRequest
import androidx.media3.exoplayer.offline.DownloadService
import androidx.media3.exoplayer.scheduler.Requirements
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import okhttp3.HttpUrl.Companion.toHttpUrl
import java.util.concurrent.CopyOnWriteArraySet
import java.util.concurrent.Executors

@UnstableApi
class MusicLibrary private constructor(val context: Context) {
    val resolver = TrackResolver()
    val playlists = PlaylistStore(context)
    val preferences = PreferenceStore(context)
    internal val account = AccountClient(SecureAccountStorage(context))
    var accountError: String? = null
    var playlistError: String? = null
    val database = StandaloneDatabaseProvider(context)
    val cache = SimpleCache(File(context.filesDir, "offline-audio"), NoOpCacheEvictor(), database)
    internal val sourceFactory = OkHttpDataSource.Factory(SourceNetwork.client).setUserAgent(SourceNetwork.USER_AGENT)
    val downloadManager = DownloadManager(context, database, cache, sourceFactory, Executors.newFixedThreadPool(2))
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val records = linkedMapOf<String, Download>()
    private val removedDuringLoad = mutableSetOf<String>()
    private val ready = CompletableDeferred<Unit>()
    private var loadingIndex = false
    private val handler = Handler(Looper.getMainLooper())
    private val listeners = CopyOnWriteArraySet<() -> Unit>()
    var player: ExoPlayer? = null
    val playingOffline: Boolean get() = player?.currentMediaItem?.localConfiguration?.tag == OFFLINE_ITEM
    var playbackError: String? = null
    private var onlineTrack: ResolvedTrack? = null
    private var incomingText: String? = null
    private var shareSequence = 0L
    private val ticker = object : Runnable {
        override fun run() {
            emit()
            if (listeners.isNotEmpty()) handler.postDelayed(this, 1000)
        }
    }

    init {
        downloadManager.maxParallelDownloads = 1
        downloadManager.requirements = Requirements(Requirements.NETWORK)
        downloadManager.addListener(object : DownloadManager.Listener {
            override fun onInitialized(manager: DownloadManager) { loadIndex() }
            override fun onDownloadChanged(manager: DownloadManager, download: Download, exception: Exception?) {
                records[download.request.id] = download
                removedDuringLoad.remove(download.request.id)
                emit()
            }
            override fun onDownloadRemoved(manager: DownloadManager, download: Download) {
                records.remove(download.request.id)
                removedDuringLoad.add(download.request.id)
                scope.launch {
                    withContext(Dispatchers.IO) {
                        artworkFile(download.request.id).delete()
                        runCatching { playlists.removeTrack(download.request.id) }
                    }
                    emit()
                }
                emit()
            }
        })
        if (downloadManager.isInitialized) loadIndex()
    }

    private fun loadIndex() {
        if (loadingIndex) return
        loadingIndex = true
        scope.launch {
            try {
                val saved = withContext(Dispatchers.IO) {
                    runCatching { playlists.load() }.onFailure { playlistError = "Không đọc được playlist cục bộ." }
                    runCatching { account.restore() }
                    buildList {
                        downloadManager.downloadIndex.getDownloads().use { cursor ->
                            while (cursor.moveToNext()) add(cursor.download)
                        }
                    }
                }
                saved.filter { it.request.id !in removedDuringLoad }.forEach {
                    records.putIfAbsent(it.request.id, it)
                }
                ready.complete(Unit)
                emit()
            } catch (e: Exception) { ready.completeExceptionally(e) }
        }
    }

    suspend fun awaitReady() { ready.await() }

    fun subscribe(listener: () -> Unit) {
        listeners.add(listener)
        handler.removeCallbacks(ticker)
        handler.post(ticker)
    }
    fun unsubscribe(listener: () -> Unit) {
        listeners.remove(listener)
        if (listeners.isEmpty()) handler.removeCallbacks(ticker)
    }
    fun emit() { listeners.forEach { it() } }

    fun share(text: String) {
        incomingText = text.take(8193)
        shareSequence++
        emit()
    }

    fun snapshot(): Map<String, Any?> {
        val p = player
        val item = p?.currentMediaItem
        val current = item?.mediaId
        val offline = playingOffline
        val cached = records[current]?.takeIf { offline && it.state == Download.STATE_COMPLETED }
        val currentTrack = cached?.let(::trackMap) ?: onlineTrack?.takeIf { it.metadata.id == current }?.let {
            it.metadata.toMap() + mapOf("status" to "streaming", "artworkUrl" to it.artworkUrl)
        }
        return mapOf("initialized" to (ready.isCompleted && !ready.isCancelled),
            "networkAvailable" to networkAvailable(), "playlists" to playlists.items.map { it.toMap() },
            "playlistError" to playlistError, "preferences" to preferences.current.toMap(),
            "account" to account.profile?.toMap(), "accountError" to accountError,
            "tracks" to records.values.sortedByDescending { it.startTimeMs }.map(::trackMap),
            "incomingText" to incomingText, "shareSequence" to shareSequence,
            "playback" to mapOf("trackId" to current, "track" to currentTrack,
                "offline" to offline, "hasNext" to (p?.hasNextMediaItem() ?: false),
                "hasPrevious" to (p?.hasPreviousMediaItem() ?: false),
                "isPlaying" to (p?.isPlaying ?: false), "positionMs" to (p?.currentPosition ?: 0),
                "durationMs" to ((p?.duration ?: 0).coerceAtLeast(0)), "error" to playbackError))
    }

    fun networkAvailable(): Boolean {
        val manager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val capabilities = manager.getNetworkCapabilities(manager.activeNetwork) ?: return false
        return capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
            capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
    }

    fun applyAudioPreferences() {
        val settings = preferences.current
        player?.let {
            it.volume = settings.volume / 100f
            it.setPlaybackSpeed(settings.speed)
        }
    }

    fun playOnline(track: ResolvedTrack) {
        val p = player ?: throw SourceFailure("NOT_READY", "Bộ phát chưa sẵn sàng.")
        val artwork = track.artworkUrl?.takeIf { url -> runCatching { SourceNetwork.validate(url.toHttpUrl()) }.isSuccess }
        val metadata = MediaMetadata.Builder().setTitle(track.metadata.title).setArtist(track.metadata.artist)
            .setArtworkUri(artwork?.let(android.net.Uri::parse)).build()
        val item = MediaItem.Builder().setMediaId(track.metadata.id).setUri(track.streamUrl)
            .setMimeType(track.mimeType).setMediaMetadata(metadata).build()
        val source = DefaultMediaSourceFactory(context).setDataSourceFactory(sourceFactory).createMediaSource(item)
        onlineTrack = track
        playbackError = null
        p.setMediaSource(source)
        p.prepare()
        p.play()
    }

    private fun trackMap(download: Download): Map<String, Any?> {
        val meta = runCatching { TrackMetadata.fromBytes(download.request.data).toMap() }.getOrElse {
            mapOf("id" to download.request.id, "title" to "Bản tải không đọc được thông tin",
                "artist" to "", "sourceUrl" to "", "provider" to "unknown", "durationMs" to 0)
        }
        val status = when (download.state) {
            Download.STATE_COMPLETED -> "completed"
            Download.STATE_DOWNLOADING -> "downloading"
            Download.STATE_QUEUED -> "queued"
            Download.STATE_RESTARTING -> "restarting"
            Download.STATE_STOPPED -> "stopped"
            Download.STATE_REMOVING -> "removing"
            else -> "failed"
        }
        return meta + mapOf("status" to status, "progress" to download.percentDownloaded,
            "bytes" to download.bytesDownloaded, "error" to if (status == "failed")
                "Tải chưa hoàn tất. Kiểm tra mạng / dung lượng rồi thử lại." else null)
    }

    fun find(id: String): Download = records[id]
        ?: throw SourceFailure("NOT_FOUND", "Bản tải không còn trong thư viện.")

    fun completed(): List<Download> = records.values.filter { it.state == Download.STATE_COMPLETED }
        .sortedByDescending { it.startTimeMs }

    fun mediaItem(download: Download): MediaItem {
        require(download.state == Download.STATE_COMPLETED)
        val metadata = TrackMetadata.fromBytes(download.request.data)
        val mediaMetadata = MediaMetadata.Builder().setTitle(metadata.title).setArtist(metadata.artist)
            .setArtworkUri(metadata.artworkPath?.let { android.net.Uri.fromFile(File(it)) }).build()
        return download.request.toMediaItem().buildUpon().setMediaId(download.request.id)
            .setTag(OFFLINE_ITEM).setMediaMetadata(mediaMetadata).build()
    }

    suspend fun enqueue(resolved: ResolvedTrack) {
        awaitReady()
        if (records[resolved.metadata.id]?.state in listOf(Download.STATE_COMPLETED, Download.STATE_QUEUED, Download.STATE_DOWNLOADING)) return
        val metadata = withContext(Dispatchers.IO) {
            if (StatFs(context.filesDir.absolutePath).availableBytes < 8 * 1024 * 1024) {
                throw SourceFailure("STORAGE", "Điện thoại còn quá ít dung lượng. Hãy giải phóng bộ nhớ rồi thử lại.")
            }
            resolved.metadata.copy(artworkPath = saveArtwork(resolved))
        }
        val request = DownloadRequest.Builder(metadata.id, android.net.Uri.parse(resolved.streamUrl))
            .setMimeType(resolved.mimeType).setData(metadata.toBytes()).build()
        if (records.containsKey(metadata.id)) DownloadService.sendRemoveDownload(context, MusicDownloadService::class.java, metadata.id, false)
        DownloadService.sendAddDownload(context, MusicDownloadService::class.java, request, true)
    }

    fun remove(id: String) {
        find(id)
        player?.let { p ->
            if (p.currentMediaItem?.mediaId == id) { p.stop(); p.clearMediaItems() }
            else for (index in p.mediaItemCount - 1 downTo 0) if (p.getMediaItemAt(index).mediaId == id) p.removeMediaItem(index)
        }
        DownloadService.sendRemoveDownload(context, MusicDownloadService::class.java, id, true)
    }

    private fun artworkFile(id: String): File {
        val key = java.security.MessageDigest.getInstance("SHA-256").digest(id.toByteArray())
            .joinToString("") { "%02x".format(it) }
        return File(File(context.filesDir, "artwork").also { it.mkdirs() }, "$key.img")
    }

    internal fun saveArtwork(track: ResolvedTrack, destination: File = artworkFile(track.metadata.id)): String? = runCatching {
        val url = track.artworkUrl ?: return null
        val request = okhttp3.Request.Builder().url(url).build()
        val call = SourceNetwork.client.newCall(request)
        call.timeout().timeout(10, java.util.concurrent.TimeUnit.SECONDS)
        call.execute().use { response ->
            if (!response.isSuccessful || response.header("Content-Type")?.startsWith("image/") != true) return null
            val source = response.body?.source() ?: return null
            source.request(2L * 1024 * 1024 + 1)
            if (source.buffer.size > 2L * 1024 * 1024) return null
            val file = destination
            val temporary = File(file.parentFile, "${file.name}.partial")
            try {
                temporary.writeBytes(source.readByteArray())
                if (!temporary.renameTo(file)) return null
                file.absolutePath
            } finally { temporary.delete() }
        }
    }.getOrNull()

    companion object {
        private const val OFFLINE_ITEM = "offline"
        @Volatile private var instance: MusicLibrary? = null
        fun get(context: Context): MusicLibrary = instance ?: synchronized(this) {
            instance ?: MusicLibrary(context.applicationContext).also { instance = it }
        }
    }
}
