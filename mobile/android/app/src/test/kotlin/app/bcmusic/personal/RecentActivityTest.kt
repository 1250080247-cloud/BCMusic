package app.bcmusic.personal

import android.app.Application
import android.os.SystemClock
import androidx.media3.common.C
import androidx.media3.common.util.UnstableApi
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.PI
import kotlin.math.sin

@UnstableApi
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], application = Application::class)
class RecentActivityTest {
    @Test fun searchAndPlaybackHistoryPersistMostRecentFirst() {
        val context = RuntimeEnvironment.getApplication()
        val history = RecentActivity(context)
        history.searched("  Nhạc mới  ")
        history.searched("Khác")
        history.searched("nhạc mới")
        val first = TrackMetadata("one", "Bài một", "", "https://youtu.be/M7lc1UVf-VE", "youtube", 2000)
        val second = first.copy(id = "two", sourceUrl = "https://youtu.be/jNQXAC9IVRw")
        history.played(first.toMap())
        history.played(second.toMap())
        history.played(first.toMap())
        val restored = RecentActivity(context)
        assertEquals(listOf("nhạc mới", "Khác"), restored.searches)
        assertEquals(listOf("one", "two"), restored.tracks.map { it["id"] })
    }

    @Test fun spectrumReadsPcmWithoutConsumingThePlaybackBuffer() {
        val spectrum = PlaybackSpectrum().apply {
            enabled = true
            flush(48000, 1, C.ENCODING_PCM_16BIT)
        }
        SystemClock.sleep(65)
        val pcm = ByteBuffer.allocate(4096).order(ByteOrder.LITTLE_ENDIAN)
        repeat(2048) { sample ->
            pcm.putShort((sin(2 * PI * 100 * sample / 48000) * 20000).toInt().toShort())
        }
        pcm.flip()
        spectrum.handleBuffer(pcm)
        assertEquals(0, pcm.position())
        assertTrue(spectrum.levels[0] > spectrum.levels[1])
        assertTrue(spectrum.levels[1] > spectrum.levels[2])
    }
}
