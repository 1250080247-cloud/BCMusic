package app.bcmusic.personal

import java.net.URI
import java.net.URLDecoder

class SourceFailure(val code: String, override val message: String, cause: Throwable? = null) :
    Exception(message, cause)

data class SourceUrl(val url: String, val provider: String) {
    companion object {
        fun parse(input: String): SourceUrl {
            fun invalid(): Nothing = throw SourceFailure("INVALID_URL", "Hãy dùng link một bài YouTube hoặc SoundCloud.")
            if (input.length > 8192) invalid()
            val uri = try { URI(input.trim()) } catch (_: Exception) { invalid() }
            if (uri.scheme != "https" || uri.userInfo != null || uri.port !in listOf(-1, 443)) invalid()
            val host = uri.host?.lowercase() ?: invalid()
            val parts = (uri.path ?: "").split('/').filter { it.isNotEmpty() }
            if (host in listOf("youtube.com", "www.youtube.com", "m.youtube.com", "music.youtube.com", "youtu.be", "www.youtu.be")) {
                val id = when {
                    host.endsWith("youtu.be") && parts.size == 1 -> parts.first()
                    uri.path == "/watch" -> uri.rawQuery?.split('&')?.map { it.split('=', limit = 2) }
                        ?.firstOrNull { it.first() == "v" }?.getOrNull(1)
                        ?.let { URLDecoder.decode(it, "UTF-8") }
                    parts.size == 2 && parts.first() in listOf("shorts", "embed", "live") -> parts[1]
                    else -> null
                }
                if (id == null || !Regex("^[a-zA-Z0-9_-]{11}$").matches(id)) invalid()
                return SourceUrl("https://www.youtube.com/watch?v=$id", "youtube")
            }
            if (host in listOf("soundcloud.com", "www.soundcloud.com", "m.soundcloud.com", "on.soundcloud.com")) {
                val shortLink = host == "on.soundcloud.com" && parts.size == 1
                val track = host != "on.soundcloud.com" && parts.size == 2 && parts[1] !in
                    listOf("sets", "likes", "tracks", "albums", "reposts")
                if ((shortLink || track) && parts.none { it == "." || it == ".." }) {
                    val canonicalHost = if (shortLink) host else "soundcloud.com"
                    return SourceUrl(URI("https", canonicalHost, "/${parts.joinToString("/")}", null).toASCIIString(), "soundcloud")
                }
            }
            invalid()
        }
    }
}
