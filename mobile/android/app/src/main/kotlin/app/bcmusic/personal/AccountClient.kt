package app.bcmusic.personal

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import okhttp3.Cookie
import okhttp3.CookieJar
import okhttp3.FormBody
import okhttp3.HttpUrl
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.security.KeyStore
import java.security.MessageDigest
import java.security.SecureRandom
import java.util.concurrent.TimeUnit
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

data class AccountProfile(val id: String, val name: String, val username: String, val avatarVersion: String = "") {
    fun toMap(): Map<String, String> = mapOf("id" to id, "name" to name, "username" to username, "avatarVersion" to avatarVersion)

    companion object {
        fun read(data: JSONObject?): AccountProfile? {
            val id = data?.optString("id")?.takeIf { it.isNotBlank() && it.length <= 128 } ?: return null
            val username = data.optString("username").take(80)
            return AccountProfile(id, data.optString("name").take(160).ifBlank { username.ifBlank { "BCMusic" } }, username, data.optString("avatarVersion").take(20))
        }
    }
}

internal interface AccountStorage {
    fun read(name: String): JSONObject?
    fun write(name: String, value: JSONObject?)
}

internal class SecureAccountStorage(context: Context) : AccountStorage {
    private val prefs = context.getSharedPreferences("bcmusic-account", Context.MODE_PRIVATE)

    override fun read(name: String): JSONObject? {
        val saved = prefs.getString(name, null) ?: return null
        return try {
            val encrypted = Base64.decode(saved, Base64.NO_WRAP)
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, encrypted, 0, 12))
            cipher.updateAAD(name.toByteArray())
            JSONObject(cipher.doFinal(encrypted, 12, encrypted.size - 12).toString(Charsets.UTF_8))
        } catch (_: Exception) {
            write(name, null)
            null
        }
    }

    override fun write(name: String, value: JSONObject?) {
        val editor = prefs.edit()
        if (value == null) editor.remove(name) else {
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.ENCRYPT_MODE, key())
            cipher.updateAAD(name.toByteArray())
            val encrypted = cipher.iv + cipher.doFinal(value.toString().toByteArray())
            editor.putString(name, Base64.encodeToString(encrypted, Base64.NO_WRAP))
        }
        if (!editor.commit()) throw SourceFailure("STORAGE", "Không lưu được phiên đăng nhập.")
    }

    private fun key(): SecretKey {
        val alias = "bcmusic-account-v1"
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey(alias, null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
            init(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setKeySize(256).setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build())
        }.generateKey()
    }
}

internal class AccountClient(
    private val storage: AccountStorage,
    private val transport: OkHttpClient = OkHttpClient(),
) {
    @Volatile var profile: AccountProfile? = null
        private set
    private val origin = "https://bc-music-gilt.vercel.app/".toHttpUrl()
    private val tokenPattern = Regex("^(?:__Secure-)?next-auth\\.session-token(?:\\.\\d+)?$")
    private val proofPattern = Regex("^[A-Za-z0-9_-]{43}$")

    @Synchronized fun restore() {
        val saved = storage.read("session") ?: return
        val cookies = saved.optJSONArray("cookies") ?: return
        val jar = AccountCookies()
        jar.saveFromResponse(origin, (0 until cookies.length()).mapNotNull { Cookie.parse(origin, cookies.optString(it)) })
        profile = AccountProfile.read(saved.optJSONObject("profile")).takeIf { jar.sessions().isNotEmpty() }
        if (profile == null) storage.write("session", null)
    }

    @Synchronized fun signIn(username: String, password: String) = authenticate(username, password)

    @Synchronized fun register(username: String, password: String, displayName: String) {
        val normalized = username.trim()
        if (normalized.length !in 3..30 || password.length < 6 || password.toByteArray().size > 72 || displayName.trim().length > 50) {
            throw SourceFailure("INPUT", "Kiểm tra tên đăng nhập, tên hiển thị và mật khẩu từ 6 ký tự (tối đa 72 byte).")
        }
        val body = JSONObject().put("username", normalized).put("password", password).put("displayName", displayName.trim())
        val result = request(AccountCookies(), "/api/auth/register", jsonBody(body))
        if (result.first == 409) throw SourceFailure("ACCOUNT_EXISTS", "Tên đăng nhập đã tồn tại.")
        if (result.first !in 200..299 || !result.second.optBoolean("success"))
            throw SourceFailure("REGISTER", "Chưa đăng ký được. Hãy kiểm tra thông tin và thử lại.")
        try {
            authenticate(normalized, password)
        } catch (error: SourceFailure) {
            throw SourceFailure("REGISTERED", "Đã tạo tài khoản. Hãy chọn Đăng nhập để tiếp tục.", error)
        }
    }

    private fun authenticate(username: String, password: String) {
        val normalized = username.trim()
        if (normalized.isEmpty() || normalized.length > 30 || password.isEmpty() || password.length > 1024)
            throw SourceFailure("INPUT", "Nhập tên đăng nhập và mật khẩu.")
        val jar = AccountCookies()
        val (status, challenge) = request(jar, "/api/auth/csrf")
        val csrf = challenge.optString("csrfToken").takeIf { status == 200 && it.length in 16..256 }
            ?: throw SourceFailure("SESSION", "Không mở được phiên đăng nhập BCMusic.")
        val form = FormBody.Builder().add("username", normalized).add("password", password)
            .add("csrfToken", csrf).add("callbackUrl", origin.toString()).add("json", "true").build()
        request(jar, "/api/auth/callback/credentials", form)
        if (jar.sessions().isEmpty()) throw SourceFailure("CREDENTIALS", "Tên đăng nhập hoặc mật khẩu chưa đúng.")
        acceptSession(jar)
        storage.write("google", null)
    }

    @Synchronized fun startGoogle(): String {
        val (status, availability) = request(AccountCookies(), "/api/mobile/auth/exchange")
        if (status != 200 || !availability.optBoolean("google"))
            throw SourceFailure("AUTH_LINK", "Kết nối Google cho Android chưa được bật trên máy chủ BCMusic.")
        val verifier = randomProof()
        val state = randomProof()
        storage.write("google", JSONObject().put("state", state).put("verifier", verifier).put("time", System.currentTimeMillis()))
        return origin.newBuilder().encodedPath("/mobile/sign-in")
            .addQueryParameter("state", state).addQueryParameter("challenge", challenge(verifier)).build().toString()
    }

    @Synchronized fun finishGoogle(code: String, state: String) {
        val pending = storage.read("google")
            ?: throw SourceFailure("AUTH_LINK", "Hãy bắt đầu đăng nhập Google từ BCMusic.")
        val verifier = pending.optString("verifier")
        if (!proofPattern.matches(code) || !proofPattern.matches(state) ||
            !proofPattern.matches(verifier) || pending.optString("state") != state ||
            System.currentTimeMillis() - pending.optLong("time") !in 0..600_000) {
            throw SourceFailure("AUTH_LINK", "Phiên kết nối Google đã hết hạn. Hãy mở lại Đăng nhập.")
        }
        val jar = AccountCookies()
        val (status, _) = request(jar, "/api/mobile/auth/exchange",
            jsonBody(JSONObject().put("code", code).put("state", state).put("verifier", verifier)))
        if (status != 200) throw SourceFailure("AUTH_LINK", "Chưa kết nối được tài khoản Google. Hãy thử lại.")
        acceptSession(jar)
        storage.write("google", null)
    }

    @Synchronized fun signOut() {
        storage.write("session", null)
        profile = null
        storage.write("google", null)
    }

    private fun activeSession(): Pair<AccountProfile, AccountCookies> {
        val saved = storage.read("session")
        val account = profile ?: throw SourceFailure("SESSION", "Hãy đăng nhập để mở hồ sơ.")
        val cookies = saved?.optJSONArray("cookies")
            ?: throw SourceFailure("SESSION", "Phiên đã hết hạn. Hãy đăng nhập lại.")
        val jar = AccountCookies()
        jar.saveFromResponse(origin, (0 until cookies.length()).mapNotNull { Cookie.parse(origin, cookies.optString(it)) })
        if (jar.sessions().isEmpty()) throw SourceFailure("SESSION", "Phiên đã hết hạn. Hãy đăng nhập lại.")
        return account to jar
    }

    @Synchronized fun updateProfile(displayName: String, image: String?) {
        val (account, jar) = activeSession()
        val name = displayName.trim()
        if (name.length !in 1..50) throw SourceFailure("INPUT", "Tên hiển thị phải từ 1 đến 50 ký tự.")
        if (image != null && image.length > 2_800_000) throw SourceFailure("INPUT", "Ảnh đại diện vượt quá 2 MB.")
        val body = JSONObject().put("displayName", name).apply { if (image != null) put("image", image) }
        val (status, response) = request(jar, "/api/user/update", jsonBody(body))
        if (status == 401) throw SourceFailure("SESSION", "Phiên đã hết hạn. Hãy đăng nhập lại.")
        val data = response.optJSONObject("data")
        if (status != 200 || !response.optBoolean("success") || data == null || data.optString("id") != account.id) {
            throw SourceFailure("PROFILE", if (status == 400) "Kiểm tra tên và ảnh PNG, JPEG, GIF, WebP hoặc URL HTTPS." else "Chưa lưu được hồ sơ.")
        }
        val updated = account.copy(
            name = data.optString("displayName", name),
            avatarVersion = if (image != null) System.currentTimeMillis().toString() else account.avatarVersion,
        )
        storeSession(updated, jar)
    }

    @Synchronized fun profileCollections(): String {
        val (account, jar) = activeSession()
        val favorites = collection(jar, "/api/favorites")
        val playlists = collection(jar, "/api/playlist")
        storeSession(account, jar)
        return JSONObject().put("favorites", favorites).put("playlists", playlists).toString()
    }

    private fun collection(jar: AccountCookies, path: String): JSONArray {
        val (status, response) = request(jar, path)
        if (status == 401) throw SourceFailure("SESSION", "Phiên đã hết hạn. Hãy đăng nhập lại.")
        return response.optJSONArray("data")?.takeIf { status == 200 && response.optBoolean("success") }
            ?: throw SourceFailure("PROFILE", "Chưa tải được dữ liệu tài khoản.")
    }

    @Synchronized fun favoriteIds(): List<String> {
        val (account, jar) = activeSession()
        val rows = collection(jar, "/api/favorites")
        storeSession(account, jar)
        return (0 until rows.length()).mapNotNull { rows.optJSONObject(it)?.optString("id") }
    }

    @Synchronized fun setFavorite(accountId: String, song: JSONObject, liked: Boolean) {
        val (account, jar) = activeSession()
        if (account.id != accountId) throw SourceFailure("SESSION", "Tài khoản đã thay đổi. Hãy thử lại.")
        val source = SourceUrl.parse(song.optString("sourceUrl"))
        val id = song.optString("id")
        val title = song.optString("title").trim()
        val validId = if (source.provider == "youtube") {
            source.url.toHttpUrl().queryParameter("v") == id
        } else Regex("sc_[0-9]{1,20}").matches(id)
        if (!validId || title.length !in 1..500) throw SourceFailure("INPUT", "Thông tin bài hát không hợp lệ.")
        val metadata = JSONObject().put("id", id).put("title", title)
            .put("artist", song.optString("artist").take(500)).put("sourceUrl", source.url)
            .put("source", source.provider).put("thumbnail", song.optString("thumbnail").take(2048))
        val (status, response) = if (liked) {
            request(jar, "/api/favorites", jsonBody(JSONObject().put("song", metadata)))
        } else {
            request(jar, "/api/favorites", delete = true, query = "songId" to id)
        }
        if (status == 401) throw SourceFailure("SESSION", "Phiên đã hết hạn. Hãy đăng nhập lại.")
        val alreadyRemoved = !liked && status == 404 && response.optString("message") == "Favorite not found."
        if (!alreadyRemoved && (status != 200 || !response.optBoolean("success")))
            throw SourceFailure("FAVORITE", "Chưa cập nhật được bài yêu thích. Hãy thử lại.")
        storeSession(account, jar)
    }

    @Synchronized fun savePlaylistSong(playlistId: String?, playlistName: String?, song: JSONObject) {
        val (account, jar) = activeSession()
        val id = song.optString("id")
        val title = song.optString("title").trim()
        val source = SourceUrl.parse(song.optString("sourceUrl"))
        if (id.length !in 1..512 || title.length !in 1..500)
            throw SourceFailure("INPUT", "Thông tin bài hát không hợp lệ.")
        val name = playlistName.orEmpty().trim()
        if (playlistId == null && name.length !in 1..80)
            throw SourceFailure("INPUT", "Tên playlist phải từ 1 đến 80 ký tự.")
        val target = playlistId ?: run {
            val (status, result) = request(jar, "/api/playlist", jsonBody(JSONObject().put("name", name)))
            requirePlaylistSuccess(status, result)
            result.optJSONObject("data")?.optString("id").orEmpty()
        }
        validatePlaylistId(target)
        val metadata = JSONObject().put("id", id).put("title", title)
            .put("artist", song.optString("artist").take(500)).put("sourceUrl", source.url)
            .put("source", source.provider)
            .put("thumbnail", song.optString("thumbnail").take(2048))
        val body = JSONObject().put("playlistId", target).put("song", metadata)
        val (status, result) = request(jar, "/api/playlist/song", jsonBody(body))
        if (status != 409 || result.optString("message") != "already_exists") requirePlaylistSuccess(status, result)
        storeSession(account, jar)
    }

    @Synchronized fun removePlaylistSong(playlistId: String, songId: String) {
        validatePlaylistId(playlistId)
        if (songId.length !in 1..512) throw SourceFailure("INPUT", "Thông tin bài hát không hợp lệ.")
        val (account, jar) = activeSession()
        val body = JSONObject().put("playlistId", playlistId).put("songId", songId)
        val (status, result) = request(jar, "/api/playlist/song", jsonBody(body), delete = true)
        requirePlaylistSuccess(status, result)
        storeSession(account, jar)
    }

    private fun validatePlaylistId(id: String) {
        if (!id.matches(Regex("[a-fA-F0-9]{24}"))) throw SourceFailure("INPUT", "Playlist không hợp lệ.")
    }

    private fun requirePlaylistSuccess(status: Int, response: JSONObject) {
        if (status == 401) throw SourceFailure("SESSION", "Phiên đã hết hạn. Hãy đăng nhập lại.")
        if (status != 200 || !response.optBoolean("success"))
            throw SourceFailure("PLAYLIST", "Chưa lưu được thay đổi trong playlist.")
    }

    private fun storeSession(account: AccountProfile, jar: AccountCookies) {
        storage.write("session", JSONObject().put("profile", JSONObject(account.toMap()))
            .put("cookies", JSONArray(jar.sessions().map(Cookie::toString))))
        profile = account
    }

    private fun acceptSession(jar: AccountCookies) {
        val (status, result) = request(jar, "/api/auth/session")
        val user = AccountProfile.read(result.optJSONObject("user"))
        val cookies = jar.sessions()
        if (status != 200 || user == null || cookies.isEmpty())
            throw SourceFailure("SESSION", "Không xác nhận được tài khoản BCMusic.")
        storeSession(user, jar)
    }

    private fun request(jar: AccountCookies, path: String, body: RequestBody? = null,
        delete: Boolean = false, query: Pair<String, String>? = null): Pair<Int, JSONObject> {
        val url = origin.newBuilder().encodedPath(path).apply {
            if (query != null) addQueryParameter(query.first, query.second)
        }.build()
        val request = Request.Builder().url(url).header("Accept", "application/json")
            .header("Cache-Control", "no-store").apply {
                if (delete) delete(body) else if (body != null) post(body)
            }.build()
        val client = transport.newBuilder().cookieJar(jar).followRedirects(false)
            .followSslRedirects(false).callTimeout(20, TimeUnit.SECONDS).build()
        try {
            client.newCall(request).execute().use { response ->
                val source = response.body?.source()
                val maxBytes = if (path == "/api/user/update") 3L * 1024 * 1024 else 512L * 1024
                source?.request(maxBytes + 1)
                if (source != null && source.buffer.size > maxBytes) throw IOException("Account response too large")
                val data = source?.readUtf8()?.let { runCatching { JSONObject(it) }.getOrNull() } ?: JSONObject()
                if (response.code >= 500 || response.code == 429)
                    throw SourceFailure("ACCOUNT_NETWORK", "Máy chủ tài khoản đang bận. Hãy thử lại sau.")
                return response.code to data
            }
        } catch (error: IOException) {
            throw SourceFailure("ACCOUNT_NETWORK", "Không kết nối được BCMusic. Kiểm tra mạng rồi thử lại.", error)
        }
    }

    private fun jsonBody(value: JSONObject) = value.toString().toRequestBody("application/json".toMediaType())
    private fun randomProof() = base64Url(ByteArray(32).also { SecureRandom().nextBytes(it) })
    private fun challenge(verifier: String) = base64Url(MessageDigest.getInstance("SHA-256").digest(verifier.toByteArray()))
    private fun base64Url(bytes: ByteArray) = Base64.encodeToString(bytes, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)

    private inner class AccountCookies : CookieJar {
        private val values = linkedMapOf<String, Cookie>()

        override fun loadForRequest(url: HttpUrl): List<Cookie> =
            if (url.isHttps && url.host == origin.host && url.port == origin.port)
                values.values.filter { it.expiresAt > System.currentTimeMillis() && it.matches(url) }
            else emptyList()

        override fun saveFromResponse(url: HttpUrl, cookies: List<Cookie>) {
            if (!url.isHttps || url.host != origin.host || url.port != origin.port) return
            for (cookie in cookies) {
                // The existing deployment also uses unprefixed NextAuth cookies.
                // This jar always receives and sends them only over the pinned HTTPS origin.
                if (!cookie.httpOnly || !cookie.hostOnly || cookie.domain != origin.host || cookie.path != "/" ||
                    ((cookie.name.startsWith("__Secure-") || cookie.name.startsWith("__Host-")) && !cookie.secure) ||
                    (!tokenPattern.matches(cookie.name) &&
                        cookie.name !in setOf("__Host-next-auth.csrf-token", "next-auth.csrf-token"))) continue
                if (cookie.expiresAt <= System.currentTimeMillis()) values.remove(cookie.name)
                else values[cookie.name] = cookie
            }
        }

        fun sessions() = loadForRequest(origin).filter { tokenPattern.matches(it.name) }
    }
}
