package app.bcmusic.personal

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.net.Uri
import android.provider.DocumentsContract
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.Clock
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DataSourceBitmapLoader
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.cache.CacheDataSource
import androidx.media3.effect.Presentation
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.transformer.AudioEncoderSettings
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultAssetLoaderFactory
import androidx.media3.transformer.DefaultDecoderFactory
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.EditedMediaItemSequence
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import java.io.File
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

@UnstableApi
internal class CoverMp4Exporter(private val library: MusicLibrary) {
    private val context = library.context

    suspend fun export(url: String, destination: Uri) {
        var temporaryVideo: File? = null
        var temporaryCover: File? = null
        var complete = false
        try {
            library.awaitReady()
            val cached = library.completed().firstOrNull {
                runCatching { TrackMetadata.fromBytes(it.request.data).sourceUrl == url }.getOrDefault(false)
            }
            val resolved = if (cached == null) withContext(Dispatchers.IO) {
                library.resolver.resolve(url, compact = true)
            } else null
            val metadata = resolved?.metadata ?: TrackMetadata.fromBytes(requireNotNull(cached).request.data)
            if (metadata.durationMs <= 0) {
                throw SourceFailure("UNSUPPORTED", "Không xác định được thời lượng để tạo MP4.")
            }
            val cover = withContext(Dispatchers.IO) {
                metadata.artworkPath?.let(::File)?.takeIf(File::isFile) ?: run {
                    val file = File.createTempFile("mp4-cover-", ".jpg", context.cacheDir)
                    temporaryCover = file
                    if (resolved == null || library.saveArtwork(resolved, file) == null) writeFallbackCover(file)
                    file
                }
            }
            val output = withContext(Dispatchers.IO) {
                File.createTempFile("cover-mp4-", ".mp4", context.cacheDir).also { temporaryVideo = it }
            }
            val media = cached?.request?.toMediaItem() ?: MediaItem.Builder()
                .setUri(requireNotNull(resolved).streamUrl).setMimeType(resolved.mimeType).build()
            val upstream = if (cached != null) CacheDataSource.Factory().setCache(library.cache)
                .setCacheWriteDataSinkFactory(null) else library.sourceFactory
            val audioSource = DefaultMediaSourceFactory(context)
                .setDataSourceFactory(DefaultDataSource.Factory(context, upstream))

            val audio = EditedMediaItem.Builder(media).setRemoveVideo(true).build()
            val image = EditedMediaItem.Builder(MediaItem.Builder()
                .setUri(Uri.fromFile(cover))
                .setMimeType(MimeTypes.IMAGE_JPEG)
                .setImageDurationMs(metadata.durationMs).build())
                .setFrameRate(5)
                .setEffects(Effects(emptyList(), listOf(Presentation.createForHeight(480))))
                .build()
            val composition = Composition.Builder(
                EditedMediaItemSequence.withVideoFrom(listOf(image)),
                EditedMediaItemSequence.withAudioFrom(listOf(audio)),
            ).build()
            render(composition, audioSource, output)
            withContext(Dispatchers.IO) {
                val stream = context.contentResolver.openOutputStream(destination, "w")
                    ?: throw SourceFailure("STORAGE", "Không mở được tệp MP4 để lưu.")
                stream.use { target -> output.inputStream().use { it.copyTo(target) } }
                complete = true
            }
        } finally {
            withContext(NonCancellable + Dispatchers.IO) {
                temporaryCover?.delete()
                temporaryVideo?.delete()
                if (!complete) runCatching { DocumentsContract.deleteDocument(context.contentResolver, destination) }
            }
        }
    }

    private suspend fun render(composition: Composition, audioSource: DefaultMediaSourceFactory, output: File) =
        suspendCancellableCoroutine<Unit> { continuation ->
            val encoder = DefaultEncoderFactory.Builder(context)
                .setRequestedVideoEncoderSettings(VideoEncoderSettings.Builder().setBitrate(64_000).build())
                .setRequestedAudioEncoderSettings(AudioEncoderSettings.Builder().setBitrate(96_000).build())
                .build()
            val transformer = Transformer.Builder(context)
                .setAssetLoaderFactory(DefaultAssetLoaderFactory(
                    context, DefaultDecoderFactory.Builder(context).build(),
                    Clock.DEFAULT, audioSource, DataSourceBitmapLoader(context),
                ))
                .setEncoderFactory(encoder)
                .setVideoMimeType(MimeTypes.VIDEO_H264)
                .setAudioMimeType(MimeTypes.AUDIO_AAC)
                .addListener(object : Transformer.Listener {
                    override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                        if (continuation.isActive) continuation.resume(Unit)
                    }
                    override fun onError(composition: Composition, exportResult: ExportResult, exportException: ExportException) {
                        if (continuation.isActive) continuation.resumeWithException(
                            SourceFailure("EXPORT", "Chưa tạo được MP4 cho bài này.", exportException)
                        )
                    }
                }).build()
            continuation.invokeOnCancellation { android.os.Handler(transformer.applicationLooper).post { transformer.cancel() } }
            transformer.start(composition, output.absolutePath)
        }

    private fun writeFallbackCover(file: File) {
        val bitmap = Bitmap.createBitmap(480, 480, Bitmap.Config.ARGB_8888)
        try {
            val canvas = Canvas(bitmap)
            canvas.drawColor(Color.rgb(20, 24, 34))
            val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.WHITE
                textSize = 48f
                textAlign = Paint.Align.CENTER
            }
            canvas.drawText("BCMusic", 240f, 252f, paint)
            file.outputStream().use { bitmap.compress(Bitmap.CompressFormat.JPEG, 85, it) }
        } finally {
            bitmap.recycle()
        }
    }
}
