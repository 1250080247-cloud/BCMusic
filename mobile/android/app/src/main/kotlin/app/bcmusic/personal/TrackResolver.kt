package app.bcmusic.personal

import okhttp3.HttpUrl.Companion.toHttpUrl
import org.schabi.newpipe.extractor.NewPipe
import org.schabi.newpipe.extractor.exceptions.ContentNotAvailableException
import org.schabi.newpipe.extractor.exceptions.ReCaptchaException
import org.schabi.newpipe.extractor.stream.DeliveryMethod
import org.schabi.newpipe.extractor.stream.StreamInfo
import java.io.IOException
import java.util.concurrent.ConcurrentHashMap

class TrackResolver {
    private val previews = ConcurrentHashMap<String, ResolvedTrack>()

    init { NewPipe.init(SourceDownloader()) }

    fun resolve(input: String, compact: Boolean = false): ResolvedTrack {
        val source = SourceUrl.parse(input)
        try {
            if (source.provider == "soundcloud") return SoundCloudResolver().resolve(source, compact)
                .also { if (!compact) previews[it.metadata.id] = it }
            val info = StreamInfo.getInfo(source.url)
            if (info.duration <= 0) throw SourceFailure("UNSUPPORTED", "Chỉ hỗ trợ bài có thời lượng xác định, chưa hỗ trợ livestream.")
            val streams = info.audioStreams.filter { it.isUrl && it.deliveryMethod in
                listOf(DeliveryMethod.PROGRESSIVE_HTTP, DeliveryMethod.HLS) }
            val compactStream = if (compact) streams.filter { it.averageBitrate in 48..96 }
                .maxByOrNull { it.averageBitrate } else null
            val stream = compactStream ?: streams.filter { it.averageBitrate in 1..192 }.maxByOrNull { it.averageBitrate }
                ?: streams.minByOrNull { if (it.averageBitrate > 0) it.averageBitrate else Int.MAX_VALUE }
                ?: throw SourceFailure("UNSUPPORTED", "Nguồn này chưa cung cấp âm thanh có thể tải.")
            SourceNetwork.validate(stream.content.toHttpUrl())
            val canonical = SourceUrl.parse(info.url)
            if (canonical.provider != source.provider || !Regex("^[A-Za-z0-9_-]{1,128}$").matches(info.id)) {
                throw SourceFailure("UNAVAILABLE", "Không đọc được danh tính bài hát.")
            }
            val metadata = TrackMetadata("${source.provider}_${info.id}",
                info.name.take(500), info.uploaderName.take(300), canonical.url,
                source.provider, info.duration * 1000)
            return ResolvedTrack(metadata, stream.content,
                if (stream.deliveryMethod == DeliveryMethod.HLS) "application/x-mpegURL" else stream.format?.mimeType,
                info.thumbnails.maxByOrNull { it.width.coerceAtLeast(0).toLong() * it.height.coerceAtLeast(0) }?.url).also { if (!compact) previews[metadata.id] = it }
        } catch (e: SourceFailure) { throw e
        } catch (e: ReCaptchaException) {
            throw SourceFailure("UNAVAILABLE", "Nguồn đang yêu cầu xác minh. Hãy thử lại sau.", e)
        } catch (e: ContentNotAvailableException) {
            throw SourceFailure("UNAVAILABLE", "Bài này hiện không khả dụng hoặc bị giới hạn truy cập.", e)
        } catch (e: IOException) {
            throw SourceFailure("NETWORK", "Không lấy được nguồn âm thanh. Kiểm tra kết nối rồi thử lại.", e)
        } catch (e: Exception) {
            throw SourceFailure("EXTRACTOR_FAILED", "Chưa đọc được bài này. Nguồn có thể đã thay đổi; cần cập nhật bộ lấy nguồn.", e)
        }
    }

    fun preview(id: String): ResolvedTrack = previews[id]?.let {
        if (System.currentTimeMillis() - it.resolvedAt < 60_000) it else resolve(it.metadata.sourceUrl)
    } ?: throw SourceFailure("NOT_FOUND", "Thông tin bài đã hết hạn. Hãy mở link lại.")
}
