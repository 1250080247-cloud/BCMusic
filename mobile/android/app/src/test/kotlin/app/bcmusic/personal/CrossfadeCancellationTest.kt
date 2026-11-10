package app.bcmusic.personal

import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CrossfadeCancellationTest {

    // Test implementation mimicking MusicLibrary fade and listener logic
    class TestFadeManager(
        var volumePref: Int = 80,
        var crossfade: Boolean = true,
        var repeatMode: String = "off",
        var sleepAtEndOfTrack: Boolean = false
    ) {
        var playerVolume: Float = volumePref / 100f
        var isFadingOut: Boolean = false
        var isFadingIn: Boolean = false
        var fadeToken: Long = 0L

        fun cancelFade() {
            fadeToken++
            isFadingOut = false
            isFadingIn = false
            playerVolume = volumePref / 100f
        }

        fun applyAudioPreferences(newVolume: Int? = null, newCrossfade: Boolean? = null, newRepeatMode: String? = null) {
            newVolume?.let { volumePref = it }
            newCrossfade?.let { crossfade = it }
            newRepeatMode?.let { repeatMode = it }

            if (!crossfade || repeatMode == "one" || isFadingIn || isFadingOut) {
                cancelFade()
            } else {
                playerVolume = volumePref / 100f
            }
        }

        fun startFadeIn() {
            if (!crossfade || repeatMode == "one" || sleepAtEndOfTrack) {
                cancelFade()
                return
            }
            val targetVolume = volumePref / 100f
            if (targetVolume <= 0f) return
            val token = ++fadeToken
            isFadingIn = true
            isFadingOut = false
            playerVolume = 0f
        }

        fun onIsPlayingChanged(isPlaying: Boolean) {
            if (!isPlaying) {
                cancelFade()
            }
        }

        fun onPositionDiscontinuity(reason: Int) {
            if (reason == Player.DISCONTINUITY_REASON_SEEK || reason == Player.DISCONTINUITY_REASON_SEEK_ADJUSTMENT) {
                cancelFade()
            }
        }

        fun onMediaItemTransition(reason: Int) {
            if (reason == Player.MEDIA_ITEM_TRANSITION_REASON_AUTO) {
                startFadeIn()
            } else {
                cancelFade()
            }
        }
    }

    @Test
    fun volumeChangeDuringFadeCancelsAndSetsNewVolume() {
        val manager = TestFadeManager(volumePref = 80, crossfade = true)
        manager.startFadeIn()
        assertTrue(manager.isFadingIn)
        assertEquals(0f, manager.playerVolume, 0.001f)

        // User changes volume to 50 in settings
        manager.applyAudioPreferences(newVolume = 50)
        assertFalse(manager.isFadingIn)
        assertFalse(manager.isFadingOut)
        assertEquals(0.5f, manager.playerVolume, 0.001f)
    }

    @Test
    fun turningOffCrossfadeDuringFadeCancelsAndRestoresVolume() {
        val manager = TestFadeManager(volumePref = 90, crossfade = true)
        manager.startFadeIn()
        assertTrue(manager.isFadingIn)

        // User disables crossfade
        manager.applyAudioPreferences(newCrossfade = false)
        assertFalse(manager.isFadingIn)
        assertEquals(0.9f, manager.playerVolume, 0.001f)
    }

    @Test
    fun switchingToRepeatOneCancelsFade() {
        val manager = TestFadeManager(volumePref = 75, crossfade = true)
        manager.startFadeIn()
        assertTrue(manager.isFadingIn)

        // User switches repeat mode to "one"
        manager.applyAudioPreferences(newRepeatMode = "one")
        assertFalse(manager.isFadingIn)
        assertEquals(0.75f, manager.playerVolume, 0.001f)
    }

    @Test
    fun pauseFromMediaSessionCancelsFade() {
        val manager = TestFadeManager(volumePref = 80, crossfade = true)
        manager.startFadeIn()
        assertTrue(manager.isFadingIn)

        // User pauses playback on notification / lockscreen
        manager.onIsPlayingChanged(false)
        assertFalse(manager.isFadingIn)
        assertEquals(0.8f, manager.playerVolume, 0.001f)
    }

    @Test
    fun seekFromMediaSessionCancelsFade() {
        val manager = TestFadeManager(volumePref = 80, crossfade = true)
        manager.startFadeIn()
        assertTrue(manager.isFadingIn)

        // User seeks via notification seekbar
        manager.onPositionDiscontinuity(Player.DISCONTINUITY_REASON_SEEK)
        assertFalse(manager.isFadingIn)
        assertEquals(0.8f, manager.playerVolume, 0.001f)
    }

    @Test
    fun manualSkipFromMediaSessionCancelsFadeAndDoesNotStartFadeIn() {
        val manager = TestFadeManager(volumePref = 80, crossfade = true)
        manager.playerVolume = 0.2f // faded down
        manager.isFadingOut = true

        // User presses Next on notification/Bluetooth (reason = SEEK)
        manager.onMediaItemTransition(Player.MEDIA_ITEM_TRANSITION_REASON_SEEK)
        assertFalse(manager.isFadingOut)
        assertFalse(manager.isFadingIn) // Must NOT start fade-in on manual skip
        assertEquals(0.8f, manager.playerVolume, 0.001f)
    }

    @Test
    fun autoTransitionTriggersFadeInWhenCrossfadeEnabled() {
        val manager = TestFadeManager(volumePref = 80, crossfade = true)

        // Song finishes and ExoPlayer auto-advances (reason = AUTO)
        manager.onMediaItemTransition(Player.MEDIA_ITEM_TRANSITION_REASON_AUTO)
        assertTrue(manager.isFadingIn)
        assertEquals(0f, manager.playerVolume, 0.001f)
    }

    @Test
    fun autoTransitionDoesNotTriggerFadeInWhenCrossfadeDisabled() {
        val manager = TestFadeManager(volumePref = 80, crossfade = false)

        manager.onMediaItemTransition(Player.MEDIA_ITEM_TRANSITION_REASON_AUTO)
        assertFalse(manager.isFadingIn)
        assertEquals(0.8f, manager.playerVolume, 0.001f)
    }

    @Test
    fun oldCoroutineCannotOverwriteVolumeAfterCancellation() = runBlocking {
        val manager = TestFadeManager(volumePref = 80)
        manager.startFadeIn()
        val token = manager.fadeToken

        // Simulate a coroutine running with `token`
        val job = launch {
            delay(50)
            if (token == manager.fadeToken) {
                manager.playerVolume = 0.1f
            }
        }

        // Cancel fade before coroutine finishes delay
        manager.cancelFade()
        assertEquals(0.8f, manager.playerVolume, 0.001f)

        job.join()
        // Player volume remains restored, not overwritten by 0.1f
        assertEquals(0.8f, manager.playerVolume, 0.001f)
    }
}
