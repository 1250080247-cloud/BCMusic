package app.bcmusic.personal

import androidx.media3.common.Player
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class QueueRepeatModeTest {
    @Test
    fun sourceQueueModeForcesRepeatOffWhenModeIsAll() {
        // Even if onlineTrack is null (cached track playing in source queue),
        // sourceQueueMode must prevent ExoPlayer from looping a single item on REPEAT_MODE_ALL.
        val repeatModeCached = MusicLibrary.resolveExoPlayerRepeatMode(
            sourceQueueMode = true,
            hasOnlineTrack = false,
            mode = "all"
        )
        assertEquals(Player.REPEAT_MODE_OFF, repeatModeCached)

        // For online track in source queue
        val repeatModeOnline = MusicLibrary.resolveExoPlayerRepeatMode(
            sourceQueueMode = true,
            hasOnlineTrack = true,
            mode = "all"
        )
        assertEquals(Player.REPEAT_MODE_OFF, repeatModeOnline)
    }

    @Test
    fun sourceQueueModeAllowsRepeatOne() {
        val repeatMode = MusicLibrary.resolveExoPlayerRepeatMode(
            sourceQueueMode = true,
            hasOnlineTrack = false,
            mode = "one"
        )
        assertEquals(Player.REPEAT_MODE_ONE, repeatMode)
    }

    @Test
    fun sourceQueueModeDisablesNativeShuffle() {
        val shuffleMode = MusicLibrary.resolveExoPlayerShuffleMode(
            sourceQueueMode = true,
            hasOnlineTrack = false,
            shuffle = true
        )
        assertFalse(shuffleMode)
    }

    @Test
    fun offlinePlaylistRespectsAllRepeatAndShuffleModes() {
        // Offline playlist managed by ExoPlayer (sourceQueueMode = false, hasOnlineTrack = false)
        val repeatAll = MusicLibrary.resolveExoPlayerRepeatMode(
            sourceQueueMode = false,
            hasOnlineTrack = false,
            mode = "all"
        )
        assertEquals(Player.REPEAT_MODE_ALL, repeatAll)

        val repeatOne = MusicLibrary.resolveExoPlayerRepeatMode(
            sourceQueueMode = false,
            hasOnlineTrack = false,
            mode = "one"
        )
        assertEquals(Player.REPEAT_MODE_ONE, repeatOne)

        val repeatOff = MusicLibrary.resolveExoPlayerRepeatMode(
            sourceQueueMode = false,
            hasOnlineTrack = false,
            mode = "off"
        )
        assertEquals(Player.REPEAT_MODE_OFF, repeatOff)

        val shuffleOn = MusicLibrary.resolveExoPlayerShuffleMode(
            sourceQueueMode = false,
            hasOnlineTrack = false,
            shuffle = true
        )
        assertTrue(shuffleOn)
    }
}
