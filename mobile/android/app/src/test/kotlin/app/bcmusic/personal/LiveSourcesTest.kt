package app.bcmusic.personal

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Test

// Explicit opt-in network checks. Default test runs remain independent of providers.
class LiveSourcesTest {
    @Test fun youtubeProvidesDownloadableAudioDescriptor() {
        assumeTrue(System.getProperty("bcmusic.live") == "true")
        val track = TrackResolver().resolve("https://www.youtube.com/watch?v=M7lc1UVf-VE")
        assertEquals("youtube", track.metadata.provider)
        assertTrue(track.streamUrl.startsWith("https://"))
        assertTrue(track.metadata.durationMs > 0)
        println("YouTube descriptor resolved: ${track.metadata.title}; ${track.mimeType}")
    }
    @Test fun soundCloudProvidesDownloadableAudioDescriptor() {
        assumeTrue(System.getProperty("bcmusic.live") == "true")
        // Creative Commons' own CC-BY sample from upstream extractor tests.
        val track = TrackResolver().resolve("https://soundcloud.com/wearecc/open-minds-ep-21-dr-beth-harris-and-dr-steven-zucker-of-smarthistory")
        assertEquals("soundcloud", track.metadata.provider)
        assertTrue(track.streamUrl.startsWith("https://"))
        assertTrue(track.metadata.durationMs > 0)
        println("SoundCloud descriptor resolved: ${track.metadata.title}; ${track.mimeType}")
    }
}
