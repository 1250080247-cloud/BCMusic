package app.bcmusic.personal

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class SoundCloudFormatTest {
    @Test fun recognizesCurrentAac96kHlsPreset() {
        val format = SoundCloudFormat.parse("aac_96k", "hls", false)!!
        assertEquals(96, format.bitrate)
        assertEquals("application/x-mpegURL", format.mimeType)
    }
    @Test fun skipsEncryptedPreviewAndUnknownFormats() {
        assertNull(SoundCloudFormat.parse("aac_96k", "encrypted_hls", false))
        assertNull(SoundCloudFormat.parse("aac_96k", "hls", true))
        assertNull(SoundCloudFormat.parse("abr_sq", "hls", false))
        assertNull(SoundCloudFormat.parse("aac_96k", "unknown", false))
    }
}
