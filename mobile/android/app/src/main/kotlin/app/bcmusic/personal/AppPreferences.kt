package app.bcmusic.personal

import android.content.Context
import org.json.JSONObject

data class AppPreferences(
    val light: Boolean = false,
    val volume: Int = 100,
    val speed: Float = 1f,
    val motion: Boolean = true,
) {
    fun toMap(): Map<String, Any> = mapOf("light" to light, "volume" to volume, "speed" to speed.toDouble(), "motion" to motion)

    companion object {
        val speeds = setOf(.75f, 1f, 1.25f, 1.5f, 2f)

        fun fromMap(values: Map<*, *>, defaults: AppPreferences = AppPreferences()): AppPreferences {
            val rate = (values["speed"] as? Number)?.toDouble()
            return AppPreferences(
                values["light"] as? Boolean ?: defaults.light,
                (values["volume"] as? Number)?.toInt()?.coerceIn(0, 100) ?: defaults.volume,
                speeds.find { it.toDouble() == rate } ?: defaults.speed,
                values["motion"] as? Boolean ?: defaults.motion,
            )
        }
    }
}

class PreferenceStore(context: Context) {
    private val prefs = context.getSharedPreferences("bcmusic-preferences", Context.MODE_PRIVATE)

    @Volatile
    var current = runCatching {
        val json = JSONObject(prefs.getString("settings", "{}") ?: "{}")
        AppPreferences.fromMap(json.keys().asSequence().associateWith(json::get))
    }.getOrDefault(AppPreferences())
        private set

    @Synchronized
    fun update(changes: Map<*, *>) {
        val next = AppPreferences.fromMap(changes, current)
        if (!prefs.edit().putString("settings", JSONObject(next.toMap()).toString()).commit()) {
            throw SourceFailure("STORAGE", "Không lưu được cài đặt.")
        }
        current = next
    }
}
