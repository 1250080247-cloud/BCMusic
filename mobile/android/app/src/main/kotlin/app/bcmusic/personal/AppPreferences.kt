package app.bcmusic.personal

import android.content.Context
import org.json.JSONObject

data class AppPreferences(
    val light: Boolean = false,
    val volume: Int = 100,
    val speed: Float = 1f,
    val motion: Boolean = true,
    val repeatMode: String = "off",
    val shuffle: Boolean = false,
    val downloadQuality: String = "standard",
    val crossfade: Boolean = false,
) {
    fun toMap(): Map<String, Any> = mapOf(
        "light" to light,
        "volume" to volume,
        "speed" to speed.toDouble(),
        "motion" to motion,
        "repeatMode" to repeatMode,
        "shuffle" to shuffle,
        "downloadQuality" to downloadQuality,
        "crossfade" to crossfade,
    )

    companion object {
        val speeds = setOf(.75f, 1f, 1.25f, 1.5f, 2f)
        val repeatModes = setOf("off", "all", "one")
        val downloadQualities = setOf("economy", "standard", "high")

        fun fromMap(values: Map<*, *>, defaults: AppPreferences = AppPreferences()): AppPreferences {
            val rate = (values["speed"] as? Number)?.toDouble()
            val repeat = values["repeatMode"] as? String
            val quality = values["downloadQuality"] as? String
            return AppPreferences(
                values["light"] as? Boolean ?: defaults.light,
                (values["volume"] as? Number)?.toInt()?.coerceIn(0, 100) ?: defaults.volume,
                speeds.find { it.toDouble() == rate } ?: defaults.speed,
                values["motion"] as? Boolean ?: defaults.motion,
                if (repeat in repeatModes) repeat!! else defaults.repeatMode,
                values["shuffle"] as? Boolean ?: defaults.shuffle,
                if (quality in downloadQualities) quality!! else defaults.downloadQuality,
                values["crossfade"] as? Boolean ?: defaults.crossfade,
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
