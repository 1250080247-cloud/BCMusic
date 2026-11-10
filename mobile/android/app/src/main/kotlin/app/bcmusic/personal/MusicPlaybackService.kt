package app.bcmusic.personal

import android.app.PendingIntent
import android.content.Intent
import android.content.Context
import android.os.Process
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.audio.AudioSink
import androidx.media3.exoplayer.audio.DefaultAudioSink
import androidx.media3.exoplayer.audio.TeeAudioProcessor
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture

@UnstableApi
class MusicPlaybackService : MediaSessionService() {
    private var session: MediaSession? = null
    private lateinit var library: MusicLibrary
    override fun onCreate() {
        super.onCreate()
        library = MusicLibrary.get(this)
        val renderers = object : DefaultRenderersFactory(this) {
            override fun buildAudioSink(context: Context, enableFloatOutput: Boolean,
                enableAudioOutputPlaybackParams: Boolean): AudioSink = DefaultAudioSink.Builder(context)
                .setAudioProcessors(arrayOf(TeeAudioProcessor(library.spectrum)))
                .setEnableAudioOutputPlaybackParameters(enableAudioOutputPlaybackParams)
                .build()
        }
        val player = ExoPlayer.Builder(this, renderers).setMediaSourceFactory(DefaultMediaSourceFactory(this)
            .setDataSourceFactory(OfflineCache.reader(library.cache))).build()
        player.setAudioAttributes(AudioAttributes.Builder().setUsage(C.USAGE_MEDIA)
            .setContentType(C.AUDIO_CONTENT_TYPE_MUSIC).build(), true)
        player.setHandleAudioBecomingNoisy(true)
        player.setWakeMode(C.WAKE_MODE_LOCAL)
        library.player = player
        library.applyAudioPreferences()
        player.addListener(object : Player.Listener {
            override fun onIsPlayingChanged(isPlaying: Boolean) {
                if (!isPlaying) {
                    library.cancelFade()
                }
                library.recordPlayback()
                library.emit()
            }

            override fun onPlayWhenReadyChanged(playWhenReady: Boolean, reason: Int) {
                if (!playWhenReady) {
                    library.cancelFade()
                }
                library.emit()
            }

            override fun onPositionDiscontinuity(
                oldPosition: Player.PositionInfo,
                newPosition: Player.PositionInfo,
                reason: Int
            ) {
                if (reason == Player.DISCONTINUITY_REASON_SEEK || reason == Player.DISCONTINUITY_REASON_SEEK_ADJUSTMENT) {
                    library.cancelFade()
                }
                library.emit()
            }

            override fun onMediaItemTransition(mediaItem: MediaItem?, reason: Int) {
                library.recordPlayback()
                if (reason == Player.MEDIA_ITEM_TRANSITION_REASON_AUTO) {
                    library.startFadeIn()
                } else {
                    library.cancelFade()
                }
                library.emit()
            }

            override fun onPlayerError(error: PlaybackException) {
                library.cancelFade()
                library.playbackError = if (library.playingOffline)
                    "Không đọc được bản tải. Hãy xóa và tải lại bài này khi có mạng."
                    else "Không phát được nguồn trực tuyến. Kiểm tra mạng hoặc thử bài khác."
                library.emit()
            }
        })
        session = MediaSession.Builder(this, player).setSessionActivity(PendingIntent.getActivity(this,
            0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT))
            .setCallback(object : MediaSession.Callback {
                @Deprecated("Deprecated in Java", ReplaceWith("super.onPlayerCommandRequest(session, controller, playerCommand)"))
                @Suppress("DEPRECATION")
                override fun onPlayerCommandRequest(
                    session: MediaSession,
                    controller: MediaSession.ControllerInfo,
                    playerCommand: Int
                ): Int {
                    if (playerCommand in listOf(
                        Player.COMMAND_PLAY_PAUSE,
                        Player.COMMAND_SEEK_TO_NEXT,
                        Player.COMMAND_SEEK_TO_PREVIOUS,
                        Player.COMMAND_SEEK_TO_NEXT_MEDIA_ITEM,
                        Player.COMMAND_SEEK_TO_PREVIOUS_MEDIA_ITEM,
                        Player.COMMAND_SEEK_IN_CURRENT_MEDIA_ITEM,
                        Player.COMMAND_SEEK_BACK,
                        Player.COMMAND_SEEK_FORWARD,
                        Player.COMMAND_STOP
                    )) {
                        library.cancelFade()
                    }
                    return super.onPlayerCommandRequest(session, controller, playerCommand)
                }

                override fun onConnect(session: MediaSession, controller: MediaSession.ControllerInfo): MediaSession.ConnectionResult {
                    val result = super.onConnect(session, controller)
                    if (controller.uid == Process.myUid()) return result
                    return MediaSession.ConnectionResult.AcceptedResultBuilder(session, controller)
                        .setAvailableSessionCommands(result.availableSessionCommands)
                        .setAvailablePlayerCommands(result.availablePlayerCommands.buildUpon()
                            .remove(Player.COMMAND_SET_MEDIA_ITEM).remove(Player.COMMAND_CHANGE_MEDIA_ITEMS).build()).build()
                }
                override fun onSetMediaItems(mediaSession: MediaSession, controller: MediaSession.ControllerInfo,
                    mediaItems: MutableList<MediaItem>, startIndex: Int, startPositionMs: Long): ListenableFuture<MediaSession.MediaItemsWithStartPosition> {
                    return try {
                        val items = mediaItems.map { library.mediaItem(library.find(it.mediaId)) }
                        Futures.immediateFuture(MediaSession.MediaItemsWithStartPosition(items, startIndex, startPositionMs))
                    } catch (e: Exception) { Futures.immediateFailedFuture(e) }
                }
            }).build()
    }
    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession? = session
    override fun onDestroy() {
        session?.player?.release()
        session?.release()
        session = null
        library.player = null
        library.emit()
        super.onDestroy()
    }
}
