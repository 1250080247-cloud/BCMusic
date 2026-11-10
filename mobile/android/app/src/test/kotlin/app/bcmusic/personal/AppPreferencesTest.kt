package app.bcmusic.personal

import android.app.Application
import android.content.Context
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], application = Application::class)
class AppPreferencesTest {
    @Test fun preferencesPersistAndPartialUpdatesKeepOtherFields() {
        val context = RuntimeEnvironment.getApplication()
        val store = PreferenceStore(context)
        assertEquals(AppPreferences(), store.current)
        store.update(mapOf("light" to true, "volume" to 64, "speed" to 1.25))
        store.update(mapOf("motion" to false, "speed" to 5))
        assertEquals(AppPreferences(light = true, volume = 64, speed = 1.25f, motion = false, repeatMode = "off", shuffle = false),
            PreferenceStore(context).current)
    }

    @Test fun doubleSpeedPersistsAcrossRestarts() {
        val context = RuntimeEnvironment.getApplication()
        PreferenceStore(context).update(mapOf("speed" to 2.0))
        assertEquals(2f, PreferenceStore(context).current.speed)
    }

    @Test fun repeatModeAndShufflePersistAndValidate() {
        val context = RuntimeEnvironment.getApplication()
        val store = PreferenceStore(context)

        // Repeat mode "all"
        store.update(mapOf("repeatMode" to "all", "shuffle" to true))
        assertEquals("all", store.current.repeatMode)
        assertTrue(store.current.shuffle)

        // Repeat mode "one"
        store.update(mapOf("repeatMode" to "one"))
        assertEquals("one", store.current.repeatMode)
        assertTrue(store.current.shuffle) // remains true

        // Invalid repeat mode falls back to default/current
        store.update(mapOf("repeatMode" to "invalid_mode"))
        assertEquals("one", store.current.repeatMode)

        // Turn shuffle off and repeat off
        store.update(mapOf("repeatMode" to "off", "shuffle" to false))
        assertEquals("off", store.current.repeatMode)
        assertFalse(store.current.shuffle)
    }

    @Test fun legacySettingsWithoutRepeatOrShuffleBackwardCompatible() {
        val context = RuntimeEnvironment.getApplication()
        // Simulate legacy SharedPreferences JSON without repeatMode or shuffle
        val prefs = context.getSharedPreferences("bcmusic-preferences", Context.MODE_PRIVATE)
        prefs.edit().putString("settings", """{"light":true,"volume":75,"speed":1.0,"motion":true}""").commit()

        val loaded = PreferenceStore(context).current
        assertTrue(loaded.light)
        assertEquals(75, loaded.volume)
        assertEquals("off", loaded.repeatMode)
        assertFalse(loaded.shuffle)
    }

    @Test fun switchingFromOnlineToOfflineResetsOnlineTrackAndPreservesRepeatModeAll() {
        val context = RuntimeEnvironment.getApplication()
        val library = MusicLibrary.get(context)
        library.preferences.update(mapOf("repeatMode" to "all"))

        // Giả lập trạng thái đang phát online
        val meta = TrackMetadata("online1", "Online Song", "Online Artist", "https://youtube.com/watch?v=1", "youtube", 180000)
        library.onlineTrack = ResolvedTrack(meta, "https://stream.example.com/audio.mp4", "audio/mp4", null)
        assertEquals("online1", library.onlineTrack?.metadata?.id)

        // Chuyển sang phát offline: gọi resetOnlineTrack()
        library.resetOnlineTrack()

        // Xác nhận onlineTrack đã bị xóa về null và repeatMode vẫn giữ nguyên "all"
        org.junit.Assert.assertNull(library.onlineTrack)
        assertEquals("all", library.preferences.current.repeatMode)
    }
}
