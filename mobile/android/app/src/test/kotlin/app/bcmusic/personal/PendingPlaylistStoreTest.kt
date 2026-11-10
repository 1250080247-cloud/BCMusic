package app.bcmusic.personal

import android.app.Application
import android.content.Context
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], application = Application::class)
class PendingPlaylistStoreTest {
    private val context: Context get() = RuntimeEnvironment.getApplication()

    @Before fun resetFixture() {
        context.getSharedPreferences("bcmusic-pending-playlists", Context.MODE_PRIVATE).edit().clear().commit()
    }

    @Test fun pendingEntriesSurviveReload() {
        val store = PendingPlaylistStore(context)
        store.add("youtube_12345678901", "p1")
        store.add("youtube_12345678901", "p2")
        store.add("youtube_98765432109", "p1")

        // Duplicate add is ignored
        store.add("youtube_12345678901", "p1")

        val restored = PendingPlaylistStore(context)
        assertEquals(listOf("p1", "p2"), restored.getPlaylistsForTrack("youtube_12345678901"))
        assertEquals(listOf("p1"), restored.getPlaylistsForTrack("youtube_98765432109"))
    }

    @Test fun removeEntrySingleAndClean() {
        val store = PendingPlaylistStore(context)
        store.add("youtube_12345678901", "p1")
        store.add("youtube_12345678901", "p2")

        store.remove("youtube_12345678901", "p1")
        assertEquals(listOf("p2"), store.getPlaylistsForTrack("youtube_12345678901"))

        store.removeTrack("youtube_12345678901")
        assertTrue(store.getPlaylistsForTrack("youtube_12345678901").isEmpty())
    }

    @Test fun removePlaylistCleansAcrossAllTracks() {
        val store = PendingPlaylistStore(context)
        store.add("youtube_11111111111", "playlist-to-delete")
        store.add("youtube_22222222222", "playlist-to-delete")
        store.add("youtube_22222222222", "playlist-keep")

        store.removePlaylist("playlist-to-delete")
        assertTrue(store.getPlaylistsForTrack("youtube_11111111111").isEmpty())
        assertEquals(listOf("playlist-keep"), store.getPlaylistsForTrack("youtube_22222222222"))
    }

    @Test fun limitsAndBlankValidation() {
        val store = PendingPlaylistStore(context)
        store.add("", "p1")
        store.add("youtube_11111111111", "")
        assertTrue(store.entries.isEmpty())
    }

    @Test(expected = SourceFailure::class)
    fun reachingLimitThrowsException() {
        val store = PendingPlaylistStore(context)
        for (i in 0 until 500) {
            store.add("track_$i", "playlist_$i")
        }
        assertEquals(500, store.entries.size)
        // 501st add must throw SourceFailure("LIMIT", ...)
        store.add("track_overflow", "playlist_overflow")
    }

    @Test
    fun hasMethodReportsCorrectState() {
        val store = PendingPlaylistStore(context)
        store.add("t1", "p1")
        assertTrue(store.has("t1", "p1"))
        org.junit.Assert.assertFalse(store.has("t1", "p2"))
        org.junit.Assert.assertFalse(store.has("t2", "p1"))
    }
}
