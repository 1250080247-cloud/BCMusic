package app.bcmusic.personal

import org.json.JSONObject

data class TrackMetadata(val id: String, val title: String, val artist: String,
    val sourceUrl: String, val provider: String, val durationMs: Long,
    val artworkPath: String? = null) {
    fun toMap(): Map<String, Any?> = mapOf("id" to id, "title" to title, "artist" to artist,
        "sourceUrl" to sourceUrl, "provider" to provider, "durationMs" to durationMs,
        "artworkPath" to artworkPath)

    fun toBytes(): ByteArray = JSONObject(toMap()).toString().toByteArray(Charsets.UTF_8)

    companion object {
        fun fromBytes(bytes: ByteArray): TrackMetadata {
            require(bytes.size <= 64 * 1024)
            val json = JSONObject(String(bytes, Charsets.UTF_8))
            return TrackMetadata(json.getString("id"), json.getString("title"),
                json.optString("artist"), json.getString("sourceUrl"), json.getString("provider"),
                json.optLong("durationMs"), json.optString("artworkPath").takeIf { it.isNotBlank() && it != "null" })
        }
    }
}

data class ResolvedTrack(
    val metadata: TrackMetadata,
    val streamUrl: String,
    val mimeType: String?,
    val artworkUrl: String?,
    val quality: String = "standard",
    val resolvedAt: Long = System.currentTimeMillis()
)
