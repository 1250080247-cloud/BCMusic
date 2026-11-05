package app.bcmusic.personal

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

data class LocalPlaylist(val id: String, val name: String, val trackIds: List<String>) {
    fun toMap(): Map<String, Any> = mapOf("id" to id, "name" to name, "trackIds" to trackIds)
}

class PlaylistStore(context: Context) {
    private val preferences = context.getSharedPreferences("bcmusic-playlists", Context.MODE_PRIVATE)
    @Volatile var items: List<LocalPlaylist> = emptyList()
        private set
    private var loaded = false

    @Synchronized fun load() {
        val json = preferences.getString("data", null)
        try {
            items = if (json == null) emptyList() else {
                val data = JSONObject(json)
                require(data.getInt("version") == 1)
                val array = data.getJSONArray("playlists")
                (0 until array.length()).map { index ->
                    val item = array.getJSONObject(index)
                    val tracks = item.getJSONArray("trackIds")
                    LocalPlaylist(item.getString("id"), item.getString("name"),
                        (0 until tracks.length()).map { tracks.getString(it) }.distinct())
                }
            }
            loaded = true
        } catch (e: Exception) { throw SourceFailure("STORAGE", "Không đọc được playlist cục bộ.", e) }
    }

    @Synchronized fun create(input: String, initialTrack: String? = null): LocalPlaylist {
        ensureLoaded()
        val name = input.trim()
        if (name.isEmpty() || name.length > 80 || name.any { it.isISOControl() })
            throw SourceFailure("INVALID_ARGUMENT", "Tên playlist cần từ 1 đến 80 ký tự.")
        if (items.size >= 100) throw SourceFailure("LIMIT", "Bạn đã có 100 playlist trên thiết bị này.")
        val playlist = LocalPlaylist(UUID.randomUUID().toString(), name, listOfNotNull(initialTrack))
        persist(items + playlist)
        return playlist
    }

    @Synchronized fun add(id: String, trackId: String) {
        if (!Regex("^(youtube|soundcloud)_[A-Za-z0-9_-]{1,128}$").matches(trackId))
            throw SourceFailure("INVALID_ARGUMENT", "Bài hát không hợp lệ.")
        update(id) { playlist ->
            if (playlist.trackIds.size >= 500 && trackId !in playlist.trackIds)
                throw SourceFailure("LIMIT", "Playlist đã có 500 bài.")
            playlist.copy(trackIds = (playlist.trackIds + trackId).distinct())
        }
    }
    @Synchronized fun remove(id: String, trackId: String) = update(id) { it.copy(trackIds = it.trackIds - trackId) }
    @Synchronized fun delete(id: String) { ensureLoaded(); persist(items.filterNot { it.id == id }) }
    @Synchronized fun removeTrack(trackId: String) {
        ensureLoaded()
        if (items.any { trackId in it.trackIds }) persist(items.map { it.copy(trackIds = it.trackIds - trackId) })
    }

    private fun update(id: String, change: (LocalPlaylist) -> LocalPlaylist) {
        ensureLoaded()
        if (items.none { it.id == id }) throw SourceFailure("NOT_FOUND", "Playlist không còn tồn tại.")
        persist(items.map { if (it.id == id) change(it) else it })
    }
    private fun ensureLoaded() { if (!loaded) throw SourceFailure("STORAGE", "Playlist chưa được đọc thành công.") }
    private fun persist(next: List<LocalPlaylist>) {
        val array = JSONArray()
        next.forEach { array.put(JSONObject(it.toMap())) }
        val json = JSONObject().put("version", 1).put("playlists", array).toString()
        if (!preferences.edit().putString("data", json).commit())
            throw SourceFailure("STORAGE", "Không lưu được playlist. Kiểm tra dung lượng rồi thử lại.")
        items = next
    }
}
