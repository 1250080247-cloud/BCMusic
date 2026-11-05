package app.bcmusic.personal

import android.app.Application
import org.junit.Assert.assertEquals
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
        assertEquals(AppPreferences(light = true, volume = 64, speed = 1.25f, motion = false),
            PreferenceStore(context).current)
    }
}
