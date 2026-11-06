package app.bcmusic.personal

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

internal class RecentActivity(context: Context) {
    private val storage = context.getSharedPreferences("bcmusic-recent-activity", Context.MODE_PRIVATE)
    var searches = read("searches") { rows, index -> rows.optString(index).takeIf(String::isNotBlank) }
        private set
    var tracks = read("tracks") { rows, index ->
        rows.optJSONObject(index)?.let { row ->
            row.keys().asSequence().filterNot(row::isNull).associateWith(row::get)
        }
    }
        private set

    fun searched(input: String) {
        val query = input.trim().take(200)
        if (query.isEmpty()) return
        searches = (listOf(query) + searches.filterNot { it.equals(query, ignoreCase = true) }).take(12)
        storage.edit().putString("searches", JSONArray(searches).toString()).apply()
    }

    fun played(track: Map<String, Any?>) {
        val url = track["sourceUrl"] as? String ?: return
        if (url.isEmpty() || tracks.firstOrNull()?.get("sourceUrl") == url) return
        val metadata = track.filterKeys { it in trackFields }.mapNotNull { (key, value) ->
            value?.let { key to it }
        }.toMap()
        tracks = (listOf(metadata) + tracks.filterNot { it["sourceUrl"] == url }).take(30)
        storage.edit().putString("tracks", JSONArray(tracks.map { JSONObject(it) }).toString()).apply()
    }

    private fun <T : Any> read(key: String, item: (JSONArray, Int) -> T?): List<T> = runCatching {
        val rows = JSONArray(storage.getString(key, "[]"))
        (0 until rows.length().coerceAtMost(30)).mapNotNull { item(rows, it) }
    }.getOrDefault(emptyList())

    private companion object {
        val trackFields = setOf("id", "title", "artist", "sourceUrl", "provider", "durationMs", "artworkPath", "artworkUrl")
    }
}
