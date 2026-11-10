package app.bcmusic.personal

import android.Manifest
import android.app.Activity
import kotlinx.coroutines.CancellableContinuation
import android.content.ComponentName
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import androidx.browser.customtabs.CustomTabsIntent
import androidx.core.content.ContextCompat
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.offline.Download
import androidx.media3.session.MediaController
import androidx.media3.session.SessionToken
import com.google.common.util.concurrent.ListenableFuture
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

@androidx.annotation.OptIn(UnstableApi::class)
class MainActivity : FlutterActivity(), EventChannel.StreamHandler {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val library by lazy { MusicLibrary.get(this) }
    private var sink: EventChannel.EventSink? = null
    private var controllerFuture: ListenableFuture<MediaController>? = null
    private var playbackRequest = 0
    private var exportDestination: CancellableContinuation<Uri?>? = null
    private var exportingMp4 = false
    private var profileImage: CancellableContinuation<Uri?>? = null
    private var spectrumSink: EventChannel.EventSink? = null
    private var spectrumJob: Job? = null
    private var foreground = false

    private suspend fun chooseMp4Destination(title: String): Uri? =
        suspendCancellableCoroutine { continuation ->
            exportDestination = continuation
            continuation.invokeOnCancellation { exportDestination = null }
            val name = title.replace(Regex("[^\\p{L}\\p{N} ._-]"), "_").trim().take(90)
            val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "video/mp4"
                putExtra(Intent.EXTRA_TITLE, "${name.ifBlank { "BCMusic" }}.mp4")
            }
            try {
                startActivityForResult(intent, 7041)
            } catch (error: Exception) {
                exportDestination = null
                continuation.resumeWithException(error)
            }
        }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 7042) {
            val continuation = profileImage
            profileImage = null
            continuation?.resume(if (resultCode == Activity.RESULT_OK) data?.data else null)
            return
        }
        if (requestCode != 7041) return
        val continuation = exportDestination
        exportDestination = null
        continuation?.resume(if (resultCode == Activity.RESULT_OK) data?.data else null)
    }

    private val listener: () -> Unit = { sink?.success(library.snapshot()) }

    private suspend fun pickProfileImage(): String? {
        if (profileImage != null) throw SourceFailure("BUSY", "Đang chọn ảnh đại diện.")
        val uri = suspendCancellableCoroutine<Uri?> { continuation ->
            profileImage = continuation
            continuation.invokeOnCancellation { profileImage = null }
            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "image/*"
            }
            try {
                startActivityForResult(intent, 7042)
            } catch (error: Exception) {
                profileImage = null
                continuation.resumeWithException(error)
            }
        } ?: return null
        return withContext(Dispatchers.IO) {
            val mime = contentResolver.getType(uri)
            if (mime !in setOf("image/jpeg", "image/png", "image/gif", "image/webp")) {
                throw SourceFailure("INPUT", "Hãy chọn ảnh PNG, JPEG, GIF hoặc WebP.")
            }
            val data = java.io.ByteArrayOutputStream()
            val stream = contentResolver.openInputStream(uri)
                ?: throw SourceFailure("INPUT", "Không đọc được ảnh đã chọn.")
            stream.use {
                val buffer = ByteArray(8192)
                while (true) {
                    val read = it.read(buffer)
                    if (read < 0) break
                    if (data.size() + read > 2 * 1024 * 1024) throw SourceFailure("INPUT", "Ảnh phải nhỏ hơn 2 MB.")
                    data.write(buffer, 0, read)
                }
            }
            "data:$mime;base64,${android.util.Base64.encodeToString(data.toByteArray(), android.util.Base64.NO_WRAP)}"
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.bcmusic.personal/methods")
            .setMethodCallHandler(::onMethod)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "app.bcmusic.personal/events")
            .setStreamHandler(this)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "app.bcmusic.personal/spectrum")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    spectrumSink = events
                    syncSpectrum()
                }
                override fun onCancel(arguments: Any?) {
                    spectrumSink = null
                    syncSpectrum()
                }
            })
    }

    override fun onStart() {
        super.onStart()
        foreground = true
        syncSpectrum()
    }

    override fun onStop() {
        foreground = false
        syncSpectrum()
        super.onStop()
    }

    private fun syncSpectrum() {
        spectrumJob?.cancel()
        val events = spectrumSink?.takeIf { foreground }
        library.spectrum.enabled = events != null
        if (events == null) return
        spectrumJob = scope.launch {
            while (isActive) {
                val levels = if (library.player?.isPlaying == true) library.spectrum.levels else listOf(0.0, 0.0, 0.0)
                events.success(levels)
                delay(80)
            }
        }
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        consumeShare(intent)
        consumeAccountLink(intent)
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        consumeShare(intent)
        consumeAccountLink(intent)
    }
    private fun consumeShare(intent: Intent?) {
        if (intent?.action == Intent.ACTION_SEND && intent.type == "text/plain") {
            intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()?.take(8193)?.let(library::share)
            // Prevent rotation/engine recreation from treating the same intent as a new share.
            intent.action = Intent.ACTION_MAIN
        }
    }

    private fun consumeAccountLink(intent: Intent?) {
        val uri = intent?.data ?: return
        if (intent.action != Intent.ACTION_VIEW || uri.scheme != "app.bcmusic.personal" ||
            uri.host != "account" || uri.path != "/complete") return
        val code = uri.getQueryParameter("code") ?: return
        val state = uri.getQueryParameter("state") ?: return
        intent.data = null
        intent.action = Intent.ACTION_MAIN
        scope.launch {
            library.accountError = null
            try {
                library.awaitReady()
                withContext(Dispatchers.IO) { library.account.finishGoogle(code, state) }
            } catch (error: CancellationException) {
                throw error
            } catch (error: Exception) {
                library.accountError = (error as? SourceFailure)?.message ?: "Chưa kết nối được tài khoản Google."
            }
            library.emit()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
        library.subscribe(listener)
    }
    override fun onCancel(arguments: Any?) {
        library.unsubscribe(listener)
        sink = null
    }

    private fun id(call: MethodCall): String = call.argument<String>("id")?.takeIf {
        Regex("^(youtube|soundcloud)_[A-Za-z0-9_-]{1,128}$").matches(it)
    } ?: throw SourceFailure("INVALID_ARGUMENT", "Danh tính bài không hợp lệ.")

    private fun onMethod(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                when (call.method) {
                    "getState" -> {
                        withTimeout(15_000) { library.awaitReady() }
                        result.success(library.snapshot())
                    }
                    "recordSearch" -> {
                        library.recent.searched(call.argument<String>("query").orEmpty())
                        library.emit()
                        result.success(null)
                    }
                    "resolve" -> {
                        val input = call.argument<String>("url") ?: throw SourceFailure("INVALID_URL", "Thiếu link bài hát.")
                        val quality = library.preferences.current.downloadQuality
                        val track = withContext(Dispatchers.IO) { library.resolver.resolve(input, quality) }
                        result.success(track.metadata.toMap() + mapOf("status" to "preview", "artworkUrl" to track.artworkUrl))
                    }
                    "enqueue" -> {
                        notificationPermission()
                        val trackId = id(call)
                        val quality = library.preferences.current.downloadQuality
                        val track = withContext(Dispatchers.IO) { library.resolver.preview(trackId, quality) }
                        library.enqueue(track)
                        result.success(null)
                    }
                    "retry" -> {
                        notificationPermission()
                        library.awaitReady()
                        val download = library.find(id(call))
                        val url = TrackMetadata.fromBytes(download.request.data).sourceUrl
                        val quality = library.preferences.current.downloadQuality
                        val track = withContext(Dispatchers.IO) { library.resolver.resolve(url, quality) }
                        library.enqueue(track)
                        result.success(null)
                    }
                    "remove" -> {
                        val trackId = id(call)
                        removeLyrics(trackId)
                        library.remove(trackId)
                        result.success(null)
                    }
                    "saveLyrics" -> {
                        val trackId = call.argument<String>("trackId").orEmpty()
                        val data = call.argument<String>("data").orEmpty()
                        if (trackId.isNotBlank() && data.isNotBlank()) saveLyrics(trackId, data)
                        result.success(null)
                    }
                    "getLyrics" -> {
                        val trackId = call.argument<String>("trackId").orEmpty()
                        result.success(getLyrics(trackId))
                    }
                    "play" -> {
                        playbackRequest++
                        notificationPermission()
                        library.awaitReady()
                        library.cancelFade()
                        library.sourceQueueMode = false
                        val trackId = id(call)
                        val requested = call.argument<List<String>>("queueIds")
                        val downloads = if (requested == null) library.completed() else
                            requested.distinct().take(500).map { library.find(it) }.filter { it.state == Download.STATE_COMPLETED }
                        val index = downloads.indexOfFirst { it.request.id == trackId }
                        if (index < 0) throw SourceFailure("NOT_READY", "Bài này chưa tải hoàn tất.")
                        val player = controller()
                        library.playbackError = null
                        library.resetOnlineTrack()
                        player.setMediaItems(downloads.map(library::mediaItem), index, 0)
                        player.prepare()
                        player.play()
                        result.success(null)
                    }
                    "playSource" -> {
                        val version = ++playbackRequest
                        notificationPermission()
                        library.awaitReady()
                        library.sourceQueueMode = true
                        val auto = call.argument<Boolean>("autoTransition") == true
                        val input = SourceUrl.parse(call.argument<String>("url") ?: "")
                        val cached = library.completed().firstOrNull {
                            runCatching { TrackMetadata.fromBytes(it.request.data).sourceUrl == input.url }.getOrDefault(false)
                        }
                        val quality = library.preferences.current.downloadQuality
                        val resolved = if (cached == null) withContext(Dispatchers.IO) { library.resolver.resolve(input.url, quality) } else null
                        if (version != playbackRequest) { result.success(null); return@launch }
                        val player = controller()
                        if (version != playbackRequest) { result.success(null); return@launch }
                        if (cached != null) {
                            library.playbackError = null
                            library.resetOnlineTrack()
                            player.setMediaItem(library.mediaItem(cached))
                            player.prepare()
                            player.play()
                            if (auto) {
                                library.startFadeIn()
                            } else {
                                library.cancelFade()
                            }
                        } else {
                            library.playOnline(resolved!!)
                            if (auto) {
                                library.startFadeIn()
                            } else {
                                library.cancelFade()
                            }
                        }
                        result.success(null)
                    }
                    "createPlaylist" -> {
                        notificationPermission()
                        val name = call.argument<String>("name") ?: ""
                        val track = call.argument<String>("trackId")
                        val url = call.argument<String>("url")
                        val enqueue = call.argument<Boolean>("enqueueIfMissing") == true
                        val created = withContext(Dispatchers.IO) {
                            if (track != null || !url.isNullOrBlank()) {
                                val validUrl = if (!url.isNullOrBlank()) {
                                    runCatching { SourceUrl.parse(url).url }.getOrNull() ?: url
                                } else null
                                val quality = library.preferences.current.downloadQuality

                                val resolved = if (validUrl != null) {
                                    library.resolver.findOrResolve(track ?: "", validUrl, quality)
                                } else if (track != null) {
                                    runCatching { library.resolver.preview(track, quality) }.getOrNull()
                                } else null

                                val canonicalTrackId = resolved?.metadata?.id ?: track!!
                                val download = library.findNullable(canonicalTrackId)

                                if (download != null && download.state == Download.STATE_COMPLETED) {
                                    library.playlists.create(name, canonicalTrackId)
                                } else {
                                    if (library.pendingPlaylists.entries.size >= 500 && !library.pendingPlaylists.has(canonicalTrackId, "")) {
                                        throw SourceFailure("LIMIT", "Hàng chờ thêm vào playlist đã đầy (tối đa 500 bài).")
                                    }
                                    val playlist = library.playlists.create(name, null)
                                    var pendingAdded = false
                                    try {
                                        library.pendingPlaylists.add(canonicalTrackId, playlist.id)
                                        pendingAdded = true
                                        if (enqueue && (download == null || download.state == Download.STATE_FAILED || download.state == Download.STATE_STOPPED)) {
                                            if (resolved != null) {
                                                library.enqueue(resolved)
                                            } else {
                                                val preview = library.resolver.findOrResolve(canonicalTrackId, validUrl, quality)
                                                library.enqueue(preview)
                                            }
                                        }
                                        playlist
                                    } catch (e: Throwable) {
                                        if (pendingAdded) {
                                            library.pendingPlaylists.remove(canonicalTrackId, playlist.id)
                                        }
                                        library.playlists.delete(playlist.id)
                                        throw e
                                    }
                                }
                            } else {
                                library.playlists.create(name, null)
                            }
                        }
                        library.emit(); result.success(created.toMap())
                    }
                    "enqueueAndAddToPlaylist" -> {
                        notificationPermission()
                        val trackId = call.argument<String>("id")
                        val playlistId = call.argument<String>("playlistId") ?: throw SourceFailure("INVALID_ARGUMENT", "Thiếu ID playlist.")
                        val url = call.argument<String>("url")
                        val validUrl = if (!url.isNullOrBlank()) {
                            runCatching { SourceUrl.parse(url).url }.getOrNull() ?: url
                        } else null
                        val quality = library.preferences.current.downloadQuality

                        val resolved = if (validUrl != null) {
                            withContext(Dispatchers.IO) { library.resolver.findOrResolve(trackId ?: "", validUrl, quality) }
                        } else if (trackId != null) {
                            withContext(Dispatchers.IO) { runCatching { library.resolver.preview(trackId, quality) }.getOrNull() }
                        } else null

                        val canonicalTrackId = resolved?.metadata?.id ?: trackId ?: throw SourceFailure("INVALID_ARGUMENT", "Thiếu ID bài hát.")
                        val download = library.findNullable(canonicalTrackId)

                        if (download != null && download.state == Download.STATE_COMPLETED) {
                            withContext(Dispatchers.IO) { library.playlists.add(playlistId, canonicalTrackId) }
                        } else {
                            if (library.pendingPlaylists.entries.size >= 500 && !library.pendingPlaylists.has(canonicalTrackId, playlistId)) {
                                throw SourceFailure("LIMIT", "Hàng chờ thêm vào playlist đã đầy (tối đa 500 bài).")
                            }
                            val alreadyPending = library.pendingPlaylists.has(canonicalTrackId, playlistId)
                            if (!alreadyPending) {
                                library.pendingPlaylists.add(canonicalTrackId, playlistId)
                            }
                            if (download == null || download.state == Download.STATE_FAILED || download.state == Download.STATE_STOPPED) {
                                try {
                                    if (resolved != null) {
                                        library.enqueue(resolved)
                                    } else {
                                        val track = withContext(Dispatchers.IO) { library.resolver.findOrResolve(canonicalTrackId, validUrl, quality) }
                                        library.enqueue(track)
                                    }
                                } catch (e: Throwable) {
                                    if (!alreadyPending) {
                                        library.pendingPlaylists.remove(canonicalTrackId, playlistId)
                                    }
                                    throw e
                                }
                            }
                        }
                        library.emit(); result.success(null)
                    }
                    "deletePlaylist" -> {
                        val playlist = call.argument<String>("playlistId") ?: ""
                        withContext(Dispatchers.IO) {
                            library.playlists.delete(playlist)
                            library.pendingPlaylists.removePlaylist(playlist)
                        }
                        library.emit(); result.success(null)
                    }
                    "addToPlaylist", "removeFromPlaylist" -> {
                        val playlist = call.argument<String>("playlistId") ?: ""
                        val track = id(call)
                        if (call.method == "addToPlaylist" && library.find(track).state != Download.STATE_COMPLETED)
                            throw SourceFailure("NOT_READY", "Hãy tải hoàn tất bài trước khi thêm vào playlist.")
                        withContext(Dispatchers.IO) {
                            if (call.method == "addToPlaylist") library.playlists.add(playlist, track)
                            else library.playlists.remove(playlist, track)
                        }
                        library.emit(); result.success(null)
                    }
                    "setRepeatOne" -> {
                        val enabled = call.argument<Boolean>("enabled") == true
                        val mode = if (enabled) "one" else "off"
                        library.preferences.update(mapOf("repeatMode" to mode))
                        if (enabled) {
                            library.cancelFade()
                        }
                        val player = controller()
                        player.repeatMode = if (enabled) Player.REPEAT_MODE_ONE else Player.REPEAT_MODE_OFF
                        library.emit()
                        result.success(null)
                    }
                    "setRepeatMode" -> {
                        val mode = call.argument<String>("mode") ?: "off"
                        library.preferences.update(mapOf("repeatMode" to mode))
                        if (mode == "one") {
                            library.cancelFade()
                        }
                        val player = controller()
                        player.repeatMode = MusicLibrary.resolveExoPlayerRepeatMode(
                            library.sourceQueueMode,
                            library.onlineTrack != null,
                            mode
                        )
                        library.emit()
                        result.success(null)
                    }
                    "setShuffle" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        library.preferences.update(mapOf("shuffle" to enabled))
                        val player = controller()
                        player.shuffleModeEnabled = MusicLibrary.resolveExoPlayerShuffleMode(
                            library.sourceQueueMode,
                            library.onlineTrack != null,
                            enabled
                        )
                        library.emit()
                        result.success(null)
                    }
                    "removeQueueItem" -> {
                        val index = call.argument<Int>("index") ?: throw SourceFailure("INVALID", "Thiếu index.")
                        val player = controller()
                        if (index in 0 until player.mediaItemCount) {
                            player.removeMediaItem(index)
                            library.emit()
                        }
                        result.success(null)
                    }
                    "reorderQueue" -> {
                        val oldIndex = call.argument<Int>("oldIndex") ?: throw SourceFailure("INVALID", "Thiếu oldIndex.")
                        val newIndex = call.argument<Int>("newIndex") ?: throw SourceFailure("INVALID", "Thiếu newIndex.")
                        val player = controller()
                        if (oldIndex in 0 until player.mediaItemCount && newIndex in 0 until player.mediaItemCount) {
                            player.moveMediaItem(oldIndex, newIndex)
                            library.emit()
                        }
                        result.success(null)
                    }
                    "exportCoverMp4" -> {
                        if (exportingMp4) throw SourceFailure("BUSY", "Đang tạo một tệp MP4 khác.")
                        val url = SourceUrl.parse(call.argument<String>("url").orEmpty()).url
                        exportingMp4 = true
                        try {
                            val title = call.argument<String>("title").orEmpty()
                            val destination = chooseMp4Destination(title)
                            if (destination != null) CoverMp4Exporter(library).export(url, destination)
                            result.success(destination != null)
                        } finally {
                            exportingMp4 = false
                        }
                    }
                    "getProfileCollections" -> {
                        result.success(withContext(Dispatchers.IO) { library.account.profileCollections() })
                    }
                    "getFavoriteIds" -> result.success(withContext(Dispatchers.IO) { library.account.favoriteIds() })
                    "setFavorite" -> {
                        val accountId = call.argument<String>("accountId").orEmpty()
                        val song = call.argument<Map<String, String>>("song").orEmpty()
                        val liked = call.argument<Boolean>("liked") == true
                        withContext(Dispatchers.IO) {
                            library.account.setFavorite(accountId, org.json.JSONObject(song), liked)
                        }
                        result.success(null)
                    }
                    "saveWebPlaylistSong" -> {
                        val playlistId = call.argument<String>("playlistId")
                        val playlistName = call.argument<String>("playlistName")
                        val song = call.argument<Map<String, String>>("song").orEmpty()
                        withContext(Dispatchers.IO) {
                            library.account.savePlaylistSong(playlistId, playlistName, org.json.JSONObject(song))
                        }
                        result.success(null)
                    }
                    "removeWebPlaylistSong" -> {
                        val playlistId = call.argument<String>("playlistId").orEmpty()
                        val songId = call.argument<String>("songId").orEmpty()
                        withContext(Dispatchers.IO) { library.account.removePlaylistSong(playlistId, songId) }
                        result.success(null)
                    }
                    "pickProfileImage" -> result.success(pickProfileImage())
                    "updateProfile" -> {
                        val name = call.argument<String>("displayName").orEmpty()
                        val image = call.argument<String>("image")
                        withContext(Dispatchers.IO) { library.account.updateProfile(name, image) }
                        library.emit()
                        result.success(null)
                    }
                    "shareTrack" -> {
                        val url = requireNotNull(call.argument<String>("url"))
                        val share = Intent(Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            putExtra(Intent.EXTRA_TEXT, url)
                        }
                        startActivity(Intent.createChooser(share, null))
                        result.success(null)
                    }
                    "togglePlay" -> {
                        library.cancelFade()
                        val player = controller()
                        if (player.isPlaying) player.pause() else {
                            library.playbackError = null
                            if (player.playbackState == Player.STATE_ENDED) player.seekToDefaultPosition()
                            if (player.playbackState == Player.STATE_IDLE) player.prepare()
                            player.play()
                        }
                        result.success(null)
                    }
                    "updatePreferences" -> {
                        val changes = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
                        withContext(Dispatchers.IO) { library.preferences.update(changes) }
                        library.applyAudioPreferences()
                        library.emit()
                        result.success(null)
                    }
                    "signIn", "register", "signOut", "startGoogle" -> {
                        library.awaitReady()
                        library.accountError = null
                        val username = call.argument<String>("username") ?: ""
                        val password = call.argument<String>("password") ?: ""
                        val displayName = call.argument<String>("displayName") ?: ""
                        val browser = withContext(Dispatchers.IO) {
                            when (call.method) {
                                "signIn" -> { library.account.signIn(username, password); null }
                                "register" -> { library.account.register(username, password, displayName); null }
                                "signOut" -> { library.account.signOut(); null }
                                else -> library.account.startGoogle()
                            }
                        }
                        if (browser != null) CustomTabsIntent.Builder().build().launchUrl(this@MainActivity, Uri.parse(browser))
                        library.emit()
                        result.success(null)
                    }
                    "clearAccountError" -> {
                        library.accountError = null
                        library.emit()
                        result.success(null)
                    }
                    "seek" -> {
                        library.cancelFade()
                        val player = controller()
                        val position = call.argument<Number>("positionMs")?.toLong() ?: 0
                        player.seekTo(position.coerceIn(0, player.duration.coerceAtLeast(0)))
                        result.success(null)
                    }
                    "skip" -> {
                        library.cancelFade()
                        val player = controller()
                        if ((call.argument<Number>("direction")?.toInt() ?: 1) < 0) player.seekToPreviousMediaItem()
                        else player.seekToNextMediaItem()
                        result.success(null)
                    }
                    "pause" -> {
                        library.cancelFade()
                        val player = controller()
                        player.pause()
                        library.pause()
                        result.success(null)
                    }
                    "setSleepTimer" -> {
                        val minutes = call.argument<Number>("minutes")?.toInt()
                        val atEnd = call.argument<Boolean>("atEndOfTrack") ?: false
                        library.setSleepTimer(minutes, atEnd)
                        result.success(null)
                    }
                    "cancelSleepTimer" -> {
                        library.cancelSleepTimer()
                        result.success(null)
                    }
                    "openWebsite" -> {
                        val uri = Uri.parse(BCMUSIC_ORIGIN_URL)
                        try { CustomTabsIntent.Builder().build().launchUrl(this@MainActivity, uri) }
                        catch (_: android.content.ActivityNotFoundException) {
                            startActivity(Intent(Intent.ACTION_VIEW, uri))
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: CancellationException) { throw e
            } catch (e: SourceFailure) { result.error(e.code, e.message, null)
            } catch (error: Exception) {
                val isDebug = (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
                if (isDebug) {
                    android.util.Log.e("BCMusic", "Method ${call.method} failed", error)
                } else {
                    android.util.Log.e("BCMusic", "Method ${call.method} failed: ${error.javaClass.simpleName}: ${error.message}")
                }
                val (code, message) = mapExceptionToFlutterError(error)
                result.error(code, message, error.javaClass.simpleName)
            }
        }
    }

    private fun notificationPermission() {
        if (Build.VERSION.SDK_INT >= 33 && ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 100)
        }
    }

    private suspend fun controller(): MediaController = suspendCancellableCoroutine { continuation ->
        val future = controllerFuture ?: MediaController.Builder(this,
            SessionToken(this, ComponentName(this, MusicPlaybackService::class.java))).buildAsync()
            .also { controllerFuture = it }
        future.addListener({
            if (continuation.isActive) {
                try { continuation.resume(future.get()) }
                catch (e: Exception) { controllerFuture = null; continuation.resumeWithException(e) }
            }
        }, ContextCompat.getMainExecutor(this))
    }

    private fun lyricsPrefs() = getSharedPreferences("bcmusic-lyrics-cache", android.content.Context.MODE_PRIVATE)

    private fun saveLyrics(trackId: String, data: String) {
        val prefs = lyricsPrefs()
        val order = prefs.getString("__order", "")?.split(",")?.filter { it.isNotBlank() }?.toMutableList() ?: mutableListOf()
        order.remove(trackId)
        order.add(0, trackId)
        val editor = prefs.edit()
        editor.putString(trackId, data)
        while (order.size > 200) {
            val oldest = order.removeAt(order.size - 1)
            editor.remove(oldest)
        }
        editor.putString("__order", order.joinToString(","))
        editor.apply()
    }

    private fun getLyrics(trackId: String): String? = lyricsPrefs().getString(trackId, null)

    private fun removeLyrics(trackId: String) {
        val prefs = lyricsPrefs()
        val order = prefs.getString("__order", "")?.split(",")?.filter { it.isNotBlank() }?.toMutableList() ?: mutableListOf()
        order.remove(trackId)
        prefs.edit().remove(trackId).putString("__order", order.joinToString(",")).apply()
    }

    override fun onDestroy() {
        library.unsubscribe(listener)
        sink = null
        scope.cancel()
        controllerFuture?.let(MediaController::releaseFuture)
        controllerFuture = null
        super.onDestroy()
    }

    companion object {
        fun mapExceptionToFlutterError(error: Exception): Pair<String, String> =
            app.bcmusic.personal.mapExceptionToFlutterError(error)
    }
}

internal fun mapExceptionToFlutterError(error: Exception): Pair<String, String> = when (error) {
    is SourceFailure -> error.code to error.message
    is java.net.UnknownHostException,
    is java.net.ConnectException,
    is java.net.SocketTimeoutException -> "NETWORK" to "Không có kết nối mạng. Hãy kiểm tra kết nối và thử lại."
    else -> "INTERNAL" to "Chưa thực hiện được thao tác. Hãy mở lại app và thử lại."
}
