package app.bcmusic.personal

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

data class PendingPlaylistEntry(val trackId: String, val playlistId: String) {
    fun toMap(): Map<String, String> = mapOf("trackId" to trackId, "playlistId" to playlistId)
}

class PendingPlaylistStore(context: Context) {
    private val prefs = context.getSharedPreferences("bcmusic-pending-playlists", Context.MODE_PRIVATE)
    @Volatile var entries: List<PendingPlaylistEntry> = emptyList()
        private set

    init {
        load()
    }

    @Synchronized fun load() {
        val json = prefs.getString("data", null)
        entries = if (json == null) emptyList() else {
            runCatching {
                val data = JSONObject(json)
                val array = data.getJSONArray("entries")
                (0 until array.length()).mapNotNull { i ->
                    val obj = array.getJSONObject(i)
                    val trackId = obj.optString("trackId", "")
                    val playlistId = obj.optString("playlistId", "")
                    if (trackId.isNotBlank() && playlistId.isNotBlank()) PendingPlaylistEntry(trackId, playlistId) else null
                }.distinct()
            }.getOrDefault(emptyList())
        }
    }

    @Synchronized fun has(trackId: String, playlistId: String): Boolean =
        entries.any { it.trackId == trackId && it.playlistId == playlistId }

    @Synchronized fun add(trackId: String, playlistId: String) {
        if (trackId.isBlank() || playlistId.isBlank()) return
        if (entries.any { it.trackId == trackId && it.playlistId == playlistId }) return
        if (entries.size >= 500) {
            throw SourceFailure("LIMIT", "Hàng chờ thêm vào playlist đã đầy (tối đa 500 bài).")
        }
        persist(entries + PendingPlaylistEntry(trackId, playlistId))
    }

    @Synchronized fun getPlaylistsForTrack(trackId: String): List<String> =
        entries.filter { it.trackId == trackId }.map { it.playlistId }.distinct()

    @Synchronized fun remove(trackId: String, playlistId: String) {
        persist(entries.filterNot { it.trackId == trackId && it.playlistId == playlistId })
    }

    @Synchronized fun removeTrack(trackId: String) {
        persist(entries.filterNot { it.trackId == trackId })
    }

    @Synchronized fun removePlaylist(playlistId: String) {
        persist(entries.filterNot { it.playlistId == playlistId })
    }

    private fun persist(next: List<PendingPlaylistEntry>) {
        val array = JSONArray()
        next.forEach { array.put(JSONObject(it.toMap())) }
        val json = JSONObject().put("version", 1).put("entries", array).toString()
        prefs.edit().putString("data", json).apply()
        entries = next
    }
}
