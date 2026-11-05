package app.bcmusic.personal

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class SourceUrlTest {
    @Test fun normalizesYouTubeLinks() {
        assertEquals("https://www.youtube.com/watch?v=M7lc1UVf-VE",
            SourceUrl.parse("https://youtu.be/M7lc1UVf-VE?si=ignored").url)
    }

    @Test fun rejectsDeceptiveHostsAndPlaylists() {
        listOf("https://youtube.com.evil.test/watch?v=M7lc1UVf-VE",
            "https://user@youtube.com/watch?v=M7lc1UVf-VE", "file:///a.mp3",
            "https://youtube.com/playlist?list=x", "https://soundcloud.com/a/sets/b")
            .forEach { input -> assertThrows(SourceFailure::class.java) { SourceUrl.parse(input) } }
    }

    @Test fun recognizesSoundCloudTrack() {
        assertEquals("soundcloud", SourceUrl.parse("https://soundcloud.com/artist/track").provider)
    }
}
