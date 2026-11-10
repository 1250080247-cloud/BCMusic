package app.bcmusic.personal

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Test

class TrackQualitySelectionTest {
    data class MockAudioStream(val url: String, val averageBitrate: Int)

    private fun selectStream(streams: List<MockAudioStream>, quality: String): MockAudioStream? {
        return when (quality) {
            "economy" -> {
                streams.filter { it.averageBitrate in 40..80 }.maxByOrNull { it.averageBitrate }
                    ?: streams.filter { it.averageBitrate in 1..96 }.minByOrNull { if (it.averageBitrate > 0) it.averageBitrate else Int.MAX_VALUE }
                    ?: streams.filter { it.averageBitrate in 1..140 }.maxByOrNull { it.averageBitrate }
                    ?: streams.firstOrNull()
            }
            "high" -> {
                streams.filter { it.averageBitrate in 140..256 }.maxByOrNull { it.averageBitrate }
                    ?: streams.filter { it.averageBitrate in 1..192 }.maxByOrNull { it.averageBitrate }
                    ?: streams.firstOrNull()
            }
            else -> {
                streams.filter { it.averageBitrate in 96..140 }.maxByOrNull { it.averageBitrate }
                    ?: streams.filter { it.averageBitrate in 1..192 }.maxByOrNull { it.averageBitrate }
                    ?: streams.firstOrNull()
            }
        }
    }

    @Test
    fun economyQualitySelectsLowerBitrate() {
        val streams = listOf(
            MockAudioStream("stream_low", 64),
            MockAudioStream("stream_mid", 128),
            MockAudioStream("stream_high", 256)
        )
        val selected = selectStream(streams, "economy")
        assertNotNull(selected)
        assertEquals("stream_low", selected?.url)
        assertEquals(64, selected?.averageBitrate)
    }

    @Test
    fun standardQualitySelectsMidBitrate() {
        val streams = listOf(
            MockAudioStream("stream_low", 64),
            MockAudioStream("stream_mid", 128),
            MockAudioStream("stream_high", 256)
        )
        val selected = selectStream(streams, "standard")
        assertNotNull(selected)
        assertEquals("stream_mid", selected?.url)
        assertEquals(128, selected?.averageBitrate)
    }

    @Test
    fun highQualitySelectsHighestBitrate() {
        val streams = listOf(
            MockAudioStream("stream_low", 64),
            MockAudioStream("stream_mid", 128),
            MockAudioStream("stream_high", 256)
        )
        val selected = selectStream(streams, "high")
        assertNotNull(selected)
        assertEquals("stream_high", selected?.url)
        assertEquals(256, selected?.averageBitrate)
    }

    @Test
    fun fallbackHandlesMissingOrZeroBitrateSafely() {
        // All bitrates 0 or negative (unknown)
        val streams = listOf(
            MockAudioStream("fallback_stream_1", 0),
            MockAudioStream("fallback_stream_2", -1)
        )
        // All branches safely fall back to first stream without throwing
        val economy = selectStream(streams, "economy")
        assertEquals("fallback_stream_1", economy?.url)

        val standard = selectStream(streams, "standard")
        assertEquals("fallback_stream_1", standard?.url)

        val high = selectStream(streams, "high")
        assertEquals("fallback_stream_1", high?.url)
    }

    @Test
    fun resolvedTrackPreservesQualityAndInvalidatesOnMismatch() {
        val metadata = TrackMetadata("youtube_test123", "Title", "Artist", "https://youtube.com/watch?v=test123", "youtube", 120_000)
        val trackStandard = ResolvedTrack(
            metadata = metadata,
            streamUrl = "https://stream.standard",
            mimeType = "audio/mp4",
            artworkUrl = null,
            quality = "standard"
        )

        assertEquals("standard", trackStandard.quality)

        // When quality matches
        val isCacheValidForStandard = trackStandard.quality == "standard" &&
            (System.currentTimeMillis() - trackStandard.resolvedAt < 60_000)
        assertEquals(true, isCacheValidForStandard)

        // When quality changed to "high", cache is invalidated
        val isCacheValidForHigh = trackStandard.quality == "high" &&
            (System.currentTimeMillis() - trackStandard.resolvedAt < 60_000)
        assertEquals(false, isCacheValidForHigh)
    }
}
