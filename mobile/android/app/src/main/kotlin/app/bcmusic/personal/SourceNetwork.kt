package app.bcmusic.personal

import okhttp3.Dns
import okhttp3.HttpUrl
import okhttp3.OkHttpClient
import okhttp3.RequestBody.Companion.toRequestBody
import org.schabi.newpipe.extractor.downloader.Downloader
import org.schabi.newpipe.extractor.downloader.Request
import org.schabi.newpipe.extractor.downloader.Response
import org.schabi.newpipe.extractor.exceptions.ReCaptchaException
import java.io.IOException
import java.net.InetAddress
import java.util.concurrent.TimeUnit

object SourceNetwork {
    private val roots = listOf("youtube.com", "youtu.be", "youtube-nocookie.com", "googlevideo.com",
        "googleapis.com", "google.com", "ytimg.com", "ggpht.com", "gstatic.com",
        "soundcloud.com", "sndcdn.com", "media-streaming.soundcloud.cloud")
    // The extractor parses desktop bootstrap scripts; SoundCloud's mobile page
    // does not expose those scripts and cannot supply its anonymous client id.
    const val USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

    fun validate(url: HttpUrl) {
        if (url.scheme != "https" || url.port != 443 || url.username.isNotEmpty() || url.password.isNotEmpty() ||
            roots.none { url.host == it || url.host.endsWith(".$it") }) {
            throw IOException("Unsupported source host")
        }
    }

    val client: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS).readTimeout(25, TimeUnit.SECONDS)
        .callTimeout(0, TimeUnit.SECONDS)
        .followSslRedirects(false)
        .dns(object : Dns {
            override fun lookup(hostname: String): List<InetAddress> = Dns.SYSTEM.lookup(hostname).also { addresses ->
                if (addresses.any { it.isAnyLocalAddress || it.isLoopbackAddress ||
                    it.isLinkLocalAddress || it.isSiteLocalAddress || it.isMulticastAddress }) {
                    throw IOException("Private network target rejected")
                }
            }
        })
        .addInterceptor { chain ->
            validate(chain.request().url)
            chain.proceed(chain.request().newBuilder()
                .header("User-Agent", chain.request().header("User-Agent") ?: USER_AGENT).build())
        }
        .addNetworkInterceptor { chain -> validate(chain.request().url); chain.proceed(chain.request()) }
        .build()
}

class SourceDownloader : Downloader() {
    override fun execute(request: Request): Response {
        val builder = okhttp3.Request.Builder().url(request.url())
        request.headers().forEach { (name, values) -> values.forEach { builder.addHeader(name, it) } }
        val method = request.httpMethod()
        val body = if (method == "GET" || method == "HEAD") null
            else (request.dataToSend() ?: ByteArray(0)).toRequestBody(null)
        builder.method(method, body)
        val call = SourceNetwork.client.newCall(builder.build())
        call.timeout().timeout(90, TimeUnit.SECONDS)
        call.execute().use { response ->
            if (response.code == 429) throw ReCaptchaException("Source requires verification", request.url())
            val source = response.body?.source()
            source?.request(8L * 1024 * 1024 + 1)
            if (source != null && source.buffer.size > 8L * 1024 * 1024) throw IOException("Metadata too large")
            return Response(response.code, response.message, response.headers.toMultimap(),
                source?.readUtf8() ?: "", response.request.url.toString())
        }
    }
}
