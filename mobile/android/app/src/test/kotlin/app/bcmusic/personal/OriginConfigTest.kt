package app.bcmusic.personal

import org.junit.Assert.assertEquals
import org.junit.Test

class OriginConfigTest {
    @Test fun bcmusicOriginUrlIsConstantAndPointsToVercel() {
        assertEquals("https://bc-music-gilt.vercel.app/", BCMUSIC_ORIGIN_URL)
    }
}
