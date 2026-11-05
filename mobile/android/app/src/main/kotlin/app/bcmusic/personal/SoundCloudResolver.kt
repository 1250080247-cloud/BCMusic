package app.bcmusic.personal

import okhttp3.HttpUrl.Companion.toHttpUrl
import com.grack.nanojson.JsonParser
import org.schabi.newpipe.extractor.services.soundcloud.SoundcloudParsingHelper

data class SoundCloudFormat(val bitrate: Int, val mimeType: String) {
    companion object {
        fun parse(preset: String, protocol: String, snipped: Boolean): SoundCloudFormat? {
            if (snipped || protocol !in listOf("hls", "progressive")) return null
            val bitrate = when {
                preset.contains("mp3") -> 128
                preset.contains("opus") -> 64
                else -> Regex("^aac_(\\d+)k(?:_.*)?$").matchEntire(preset)?.groupValues?.get(1)?.toIntOrNull()
            } ?: return null
            val mime = if (protocol == "hls") "application/x-mpegURL" else when {
                preset.contains("mp3") -> "audio/mpeg"
                preset.contains("opus") -> "audio/ogg"
                else -> "audio/mp4"
            }
            return SoundCloudFormat(bitrate, mime)
        }
    }
}

class SoundCloudResolver {
    // Reuse upstream's anonymous bootstrap and track resolution. Its current
    // stream builder only recognizes AAC 160k; SoundCloud now returns AAC 96k.
    fun resolve(source: SourceUrl, compact: Boolean = false): ResolvedTrack {
        val downloader = SourceDownloader()
        val canonicalInput = if (source.url.toHttpUrl().host == "on.soundcloud.com")
            SourceUrl.parse(downloader.head(source.url).latestUrl()) else source
        val track = SoundcloudParsingHelper.resolveFor(downloader, canonicalInput.url)
        if (!track.getBoolean("streamable") || track.getString("policy") != "ALLOW") {
            throw SourceFailure("UNAVAILABLE", "Bài SoundCloud này bị giới hạn hoặc chưa cho phép nghe đầy đủ.")
        }
        val sourceUrl = SourceUrl.parse(track.getString("permalink_url"))
        val duration = track.getLong("duration")
        if (duration <= 0) throw SourceFailure("UNSUPPORTED", "Không xác định được thời lượng bài.")
        val transcodings = track.getObject("media")?.getArray("transcodings")
            ?: throw SourceFailure("UNSUPPORTED", "Bài này chưa có nguồn âm thanh được hỗ trợ.")
        val candidates = transcodings.mapNotNull { value ->
            val item = value as? com.grack.nanojson.JsonObject ?: return@mapNotNull null
            val format = SoundCloudFormat.parse(item.getString("preset", ""),
                item.getObject("format")?.getString("protocol", "") ?: "", item.getBoolean("snipped"))
                ?: return@mapNotNull null
            item.getString("url")?.let { it to format }
        }.sortedByDescending { (_, format) -> if (compact && format.bitrate <= 96) format.bitrate + 192 else if (format.bitrate <= 192) format.bitrate else 0 }
        if (candidates.isEmpty()) throw SourceFailure("UNSUPPORTED", "Bài này chỉ có định dạng chưa hỗ trợ hoặc bản nghe thử.")
        for ((endpoint, format) in candidates.take(20)) {
            val request = endpoint.toHttpUrl().newBuilder()
                .setQueryParameter("client_id", SoundcloudParsingHelper.clientId())
                .apply { track.getString("track_authorization")?.let { setQueryParameter("track_authorization", it) } }.build()
            try {
                val response = downloader.get(request.toString())
                if (response.responseCode() !in 200..299) continue
                val audioUrl = JsonParser.`object`().from(response.responseBody()).getString("url") ?: continue
                SourceNetwork.validate(audioUrl.toHttpUrl())
                val id = track.getLong("id").takeIf { it > 0 }
                    ?: throw SourceFailure("UNAVAILABLE", "Không đọc được danh tính bài SoundCloud.")
                return ResolvedTrack(TrackMetadata("soundcloud_$id", track.getString("title", "Chưa có tên").take(500),
                    track.getObject("user")?.getString("username", "")?.take(300) ?: "",
                    sourceUrl.url, "soundcloud", duration), audioUrl, format.mimeType,
                    track.getString("artwork_url") ?: track.getObject("user")?.getString("avatar_url"))
            } catch (_: java.io.IOException) {
                // Try another explicitly supported, unencrypted full-length source.
            }
        }
        throw SourceFailure("UNAVAILABLE", "SoundCloud chưa cung cấp nguồn nghe đầy đủ cho bài này. Hãy thử lại sau.")
    }
}
