package app.bcmusic.personal

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CrossfadeRampTest {
    // Helper simulating volume ramp logic from MusicLibrary
    class VolumeRampController(
        var volumePref: Int = 80,
        var crossfade: Boolean = true,
        var repeatMode: String = "off",
        var sleepAtEndOfTrack: Boolean = false
    ) {
        var playerVolume: Float = volumePref / 100f
        var isFadingOut: Boolean = false
        var isFadingIn: Boolean = false

        fun cancelFade() {
            isFadingOut = false
            isFadingIn = false
            playerVolume = volumePref / 100f
        }

        fun checkCrossfade(positionMs: Long, durationMs: Long): Boolean {
            if (!crossfade || repeatMode == "one" || sleepAtEndOfTrack) return false
            if (durationMs <= 10_000L || positionMs <= 0L) return false
            val remaining = durationMs - positionMs
            if (remaining in 1..5000 && !isFadingOut && !isFadingIn) {
                isFadingOut = true
                return true
            }
            return false
        }

        fun calculateFadeOutVolume(elapsedMs: Long, durationMs: Long, initialVolume: Float): Float {
            val progress = (elapsedMs.toFloat() / durationMs.coerceAtLeast(1000L)).coerceIn(0f, 1f)
            return (initialVolume * (1f - progress)).coerceAtLeast(0f)
        }

        fun calculateFadeInVolume(elapsedMs: Long, durationMs: Long, targetVolume: Float): Float {
            val progress = (elapsedMs.toFloat() / durationMs.coerceAtLeast(1000L)).coerceIn(0f, 1f)
            return targetVolume * progress
        }
    }

    @Test
    fun boundaryShortTracksDoNotTriggerFadeOut() {
        val ctrl = VolumeRampController()
        // Track duration 10 seconds or shorter should NOT trigger fade out
        assertFalse(ctrl.checkCrossfade(positionMs = 7000L, durationMs = 10_000L))
        assertFalse(ctrl.checkCrossfade(positionMs = 3000L, durationMs = 5000L))
        assertFalse(ctrl.isFadingOut)
    }

    @Test
    fun repeatModeOneDoesNotTriggerFadeOut() {
        val ctrl = VolumeRampController(repeatMode = "one")
        assertFalse(ctrl.checkCrossfade(positionMs = 178_000L, durationMs = 180_000L))
        assertFalse(ctrl.isFadingOut)
    }

    @Test
    fun sleepAtEndOfTrackDoesNotTriggerFadeOut() {
        val ctrl = VolumeRampController(sleepAtEndOfTrack = true)
        assertFalse(ctrl.checkCrossfade(positionMs = 178_000L, durationMs = 180_000L))
        assertFalse(ctrl.isFadingOut)
    }

    @Test
    fun fadeOutTriggersInLast5Seconds() {
        val ctrl = VolumeRampController(volumePref = 100)
        assertTrue(ctrl.checkCrossfade(positionMs = 177_000L, durationMs = 180_000L))
        assertTrue(ctrl.isFadingOut)

        // Mid-point (2.5s into 5s ramp)
        val midVol = ctrl.calculateFadeOutVolume(elapsedMs = 2500L, durationMs = 5000L, initialVolume = 1f)
        assertEquals(0.5f, midVol, 0.01f)

        // End of ramp
        val endVol = ctrl.calculateFadeOutVolume(elapsedMs = 5000L, durationMs = 5000L, initialVolume = 1f)
        assertEquals(0f, endVol, 0.01f)
    }

    @Test
    fun fadeInRampsUpToTargetVolume() {
        val ctrl = VolumeRampController(volumePref = 80)
        val target = 0.8f

        // Start of fade-in
        val startVol = ctrl.calculateFadeInVolume(elapsedMs = 0L, durationMs = 5000L, targetVolume = target)
        assertEquals(0f, startVol, 0.01f)

        // Mid-point (2.5s)
        val midVol = ctrl.calculateFadeInVolume(elapsedMs = 2500L, durationMs = 5000L, targetVolume = target)
        assertEquals(0.4f, midVol, 0.01f)

        // End of fade-in (5s)
        val endVol = ctrl.calculateFadeInVolume(elapsedMs = 5000L, durationMs = 5000L, targetVolume = target)
        assertEquals(0.8f, endVol, 0.01f)
    }

    @Test
    fun cancelFadeRestoresUserVolume() {
        val ctrl = VolumeRampController(volumePref = 70)
        ctrl.playerVolume = 0.1f // faded down
        ctrl.isFadingOut = true

        ctrl.cancelFade()
        assertFalse(ctrl.isFadingOut)
        assertFalse(ctrl.isFadingIn)
        assertEquals(0.7f, ctrl.playerVolume, 0.001f)
    }
}
