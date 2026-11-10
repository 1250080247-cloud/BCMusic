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

data class ResolvedPlaylistTrack(
    val id: String,
    val title: String,
    val artist: String,
    val sourceUrl: String,
    val durationMs: Long,
    val artworkUrl: String?
)

data class ResolvedPlaylist(
    val id: String,
    val name: String,
    val uploader: String,
    val artworkUrl: String?,
    val sourceUrl: String,
    val tracks: List<ResolvedPlaylistTrack>
)

class SoundCloudResolver {
    // Reuse upstream's anonymous bootstrap and track resolution. Its current
    // stream builder only recognizes AAC 160k; SoundCloud now returns AAC 96k.
    fun resolve(source: SourceUrl, quality: String = "standard"): ResolvedTrack {
        val downloader = SourceDownloader()
        val canonicalInput = if (source.url.toHttpUrl().host == "on.soundcloud.com")
            SourceUrl.parse(downloader.head(source.url).latestUrl()) else source
        val track = if (canonicalInput.url.startsWith("https://api-v2.soundcloud.com/tracks/")) {
            val clientId = SoundcloudParsingHelper.clientId()
            val req = canonicalInput.url.toHttpUrl().newBuilder().setQueryParameter("client_id", clientId).build()
            val res = downloader.get(req.toString())
            if (res.responseCode() !in 200..299) throw SourceFailure("UNAVAILABLE", "Không đọc được bài SoundCloud.")
            JsonParser.`object`().from(res.responseBody())
        } else {
            SoundcloudParsingHelper.resolveFor(downloader, canonicalInput.url)
        }
        if (track.getString("kind") == "playlist") {
            throw SourceFailure("PLAYLIST_URL", "Đây là link danh sách phát SoundCloud.")
        }
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
        }.sortedWith { a, b ->
            val fA = a.second
            val fB = b.second
            when (quality) {
                "economy" -> {
                    val scoreA = if (fA.bitrate <= 64) 1000 - fA.bitrate else if (fA.bitrate <= 96) 500 - fA.bitrate else 100 - fA.bitrate
                    val scoreB = if (fB.bitrate <= 64) 1000 - fB.bitrate else if (fB.bitrate <= 96) 500 - fB.bitrate else 100 - fB.bitrate
                    scoreB.compareTo(scoreA)
                }
                "high" -> {
                    fB.bitrate.compareTo(fA.bitrate)
                }
                else -> {
                    val distA = kotlin.math.abs(fA.bitrate - 128)
                    val distB = kotlin.math.abs(fB.bitrate - 128)
                    distA.compareTo(distB)
                }
            }
        }
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
                return ResolvedTrack(
                    metadata = TrackMetadata(
                        id = "soundcloud_$id",
                        title = track.getString("title", "Chưa có tên").take(500),
                        artist = track.getObject("user")?.getString("username", "")?.take(300) ?: "",
                        sourceUrl = sourceUrl.url,
                        provider = "soundcloud",
                        durationMs = duration
                    ),
                    streamUrl = audioUrl,
                    mimeType = format.mimeType,
                    artworkUrl = track.getString("artwork_url") ?: track.getObject("user")?.getString("avatar_url"),
                    quality = quality
                )
            } catch (_: java.io.IOException) {
                // Try another explicitly supported, unencrypted full-length source.
            }
        }
        throw SourceFailure("UNAVAILABLE", "SoundCloud chưa cung cấp nguồn nghe đầy đủ cho bài này. Hãy thử lại sau.")
    }

    fun resolvePlaylist(source: SourceUrl): ResolvedPlaylist {
        val downloader = SourceDownloader()
        val canonicalInput = if (source.url.toHttpUrl().host == "on.soundcloud.com")
            SourceUrl.parse(downloader.head(source.url).latestUrl()) else source
        val responseObj = SoundcloudParsingHelper.resolveFor(downloader, canonicalInput.url)
        val kind = responseObj.getString("kind")
        if (kind != "playlist") {
            throw SourceFailure("UNSUPPORTED", "Link này không phải playlist SoundCloud.")
        }
        val playlistId = responseObj.getLong("id")
        val playlistTitle = responseObj.getString("title", "SoundCloud Playlist").take(80)
        val uploader = responseObj.getObject("user")?.getString("username", "") ?: ""
        val artwork = responseObj.getString("artwork_url") ?: responseObj.getObject("user")?.getString("avatar_url")
        val tracksArray = responseObj.getArray("tracks") ?: com.grack.nanojson.JsonArray()

        val parsedTracks = mutableListOf<ResolvedPlaylistTrack>()
        for (i in 0 until tracksArray.size) {
            val item = tracksArray.getObject(i) ?: continue
            val id = item.getLong("id")
            if (id <= 0) continue
            val title = item.getString("title", "Chưa có tên").take(500)
            val permalink = item.getString("permalink_url")
            val artist = item.getObject("user")?.getString("username", uploader) ?: uploader
            val duration = item.getLong("duration", 0L)
            val trackArtwork = item.getString("artwork_url") ?: artwork
            val trackUrl = if (!permalink.isNullOrBlank()) permalink else "https://api-v2.soundcloud.com/tracks/$id"
            parsedTracks.add(ResolvedPlaylistTrack(
                id = "soundcloud_$id",
                title = title,
                artist = artist,
                sourceUrl = trackUrl,
                durationMs = duration,
                artworkUrl = trackArtwork
            ))
        }
        return ResolvedPlaylist(
            id = "soundcloud_playlist_$playlistId",
            name = playlistTitle.ifBlank { "SoundCloud Playlist" },
            uploader = uploader,
            artworkUrl = artwork,
            sourceUrl = canonicalInput.url,
            tracks = parsedTracks
        )
    }
}
