package app.bcmusic.personal

import android.app.Application
import android.content.Context
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], application = Application::class)
class PlaylistStoreTest {
    private val context get() = RuntimeEnvironment.getApplication()
    @Before fun resetFixture() { context.getSharedPreferences("bcmusic-playlists", Context.MODE_PRIVATE).edit().clear().commit() }

    @Test fun playlistAndUniqueMembershipSurviveReload() {
        val store = PlaylistStore(context).also { it.load() }
        val playlist = store.create("  Nhạc của tôi  ", "youtube_jNQXAC9IVRw")
        store.add(playlist.id, "youtube_jNQXAC9IVRw")
        val restored = PlaylistStore(context).also { it.load() }.items.single()
        assertEquals("Nhạc của tôi", restored.name)
        assertEquals(listOf("youtube_jNQXAC9IVRw"), restored.trackIds)
    }
    @Test fun removingTrackKeepsPlaylistAndOtherTracks() {
        val store = PlaylistStore(context).also { it.load() }
        val playlist = store.create("Playlist")
        store.add(playlist.id, "youtube_jNQXAC9IVRw")
        store.add(playlist.id, "youtube_M7lc1UVf-VE")
        store.removeTrack("youtube_jNQXAC9IVRw")
        assertEquals(listOf("youtube_M7lc1UVf-VE"), store.items.single().trackIds)
    }
    @Test fun emptyNameIsRejected() {
        val store = PlaylistStore(context).also { it.load() }
        assertThrows(SourceFailure::class.java) { store.create("  ") }
    }

    @Test fun deletingPlaylistOnlySelectsCompletedDownloadsNotSharedWithOtherPlaylists() {
        val store = PlaylistStore(context).also { it.load() }
        val playlist = store.create("Xóa", "youtube_private")
        listOf("soundcloud_shared", "youtube_pending", "youtube_missing").forEach {
            store.add(playlist.id, it)
        }
        store.create("Giữ", "soundcloud_old_alias")
        val completed = mapOf(
            "youtube_private" to "youtube_private",
            "youtube_pending" to "youtube_pending",
            "soundcloud_shared" to "soundcloud_shared",
            "soundcloud_old_alias" to "soundcloud_shared",
        )
        assertEquals(
            listOf("youtube_private"),
            store.exclusiveDownloads(playlist.id, listOf("youtube_pending"), completed::get),
        )
    }
}
