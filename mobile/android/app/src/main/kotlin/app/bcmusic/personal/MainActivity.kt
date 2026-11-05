package app.bcmusic.personal

import android.Manifest
import android.app.Activity
import kotlinx.coroutines.CancellableContinuation
import android.content.ComponentName
import android.content.Intent
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
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
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
        if (requestCode != 7041) return
        val continuation = exportDestination
        exportDestination = null
        continuation?.resume(if (resultCode == Activity.RESULT_OK) data?.data else null)
    }

    private val listener: () -> Unit = { sink?.success(library.snapshot()) }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.bcmusic.personal/methods")
            .setMethodCallHandler(::onMethod)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "app.bcmusic.personal/events")
            .setStreamHandler(this)
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
                    "resolve" -> {
                        val input = call.argument<String>("url") ?: throw SourceFailure("INVALID_URL", "Thiếu link bài hát.")
                        val track = withContext(Dispatchers.IO) { library.resolver.resolve(input) }
                        result.success(track.metadata.toMap() + mapOf("status" to "preview", "artworkUrl" to track.artworkUrl))
                    }
                    "enqueue" -> {
                        notificationPermission()
                        val trackId = id(call)
                        val track = withContext(Dispatchers.IO) { library.resolver.preview(trackId) }
                        library.enqueue(track)
                        result.success(null)
                    }
                    "retry" -> {
                        notificationPermission()
                        library.awaitReady()
                        val download = library.find(id(call))
                        val url = TrackMetadata.fromBytes(download.request.data).sourceUrl
                        val track = withContext(Dispatchers.IO) { library.resolver.resolve(url) }
                        library.enqueue(track)
                        result.success(null)
                    }
                    "remove" -> { library.remove(id(call)); result.success(null) }
                    "play" -> {
                        playbackRequest++
                        notificationPermission()
                        library.awaitReady()
                        val trackId = id(call)
                        val requested = call.argument<List<String>>("queueIds")
                        val downloads = if (requested == null) library.completed() else
                            requested.distinct().take(500).map { library.find(it) }.filter { it.state == Download.STATE_COMPLETED }
                        val index = downloads.indexOfFirst { it.request.id == trackId }
                        if (index < 0) throw SourceFailure("NOT_READY", "Bài này chưa tải hoàn tất.")
                        val player = controller()
                        library.playbackError = null
                        player.setMediaItems(downloads.map(library::mediaItem), index, 0)
                        player.prepare()
                        player.play()
                        result.success(null)
                    }
                    "playSource" -> {
                        val version = ++playbackRequest
                        notificationPermission()
                        library.awaitReady()
                        val input = SourceUrl.parse(call.argument<String>("url") ?: "")
                        val cached = library.completed().firstOrNull {
                            runCatching { TrackMetadata.fromBytes(it.request.data).sourceUrl == input.url }.getOrDefault(false)
                        }
                        val resolved = if (cached == null) withContext(Dispatchers.IO) { library.resolver.resolve(input.url) } else null
                        if (version != playbackRequest) { result.success(null); return@launch }
                        val player = controller()
                        if (version != playbackRequest) { result.success(null); return@launch }
                        if (cached != null) {
                            library.playbackError = null
                            player.setMediaItem(library.mediaItem(cached))
                            player.prepare()
                            player.play()
                        } else library.playOnline(resolved!!)
                        result.success(null)
                    }
                    "createPlaylist" -> {
                        val name = call.argument<String>("name") ?: ""
                        val track = call.argument<String>("trackId")
                        if (track != null && library.find(track).state != Download.STATE_COMPLETED)
                            throw SourceFailure("NOT_READY", "Hãy tải hoàn tất bài trước khi thêm vào playlist.")
                        withContext(Dispatchers.IO) { library.playlists.create(name, track) }
                        library.emit(); result.success(null)
                    }
                    "deletePlaylist" -> {
                        val playlist = call.argument<String>("playlistId") ?: ""
                        withContext(Dispatchers.IO) { library.playlists.delete(playlist) }
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
                        controller().repeatMode = if (call.argument<Boolean>("enabled") == true) {
                            Player.REPEAT_MODE_ONE
                        } else {
                            Player.REPEAT_MODE_OFF
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
                        val player = controller()
                        val position = call.argument<Number>("positionMs")?.toLong() ?: 0
                        player.seekTo(position.coerceIn(0, player.duration.coerceAtLeast(0)))
                        result.success(null)
                    }
                    "skip" -> {
                        val player = controller()
                        if ((call.argument<Number>("direction")?.toInt() ?: 1) < 0) player.seekToPreviousMediaItem()
                        else player.seekToNextMediaItem()
                        result.success(null)
                    }
                    "openWebsite" -> {
                        val uri = Uri.parse("https://bc-music-gilt.vercel.app/")
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
            } catch (_: Exception) {
                result.error("INTERNAL", "Chưa thực hiện được thao tác. Hãy mở lại app và thử lại.", null)
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

    override fun onDestroy() {
        library.unsubscribe(listener)
        sink = null
        scope.cancel()
        controllerFuture?.let(MediaController::releaseFuture)
        controllerFuture = null
        super.onDestroy()
    }
}
