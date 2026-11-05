package app.bcmusic.personal

import android.app.Application
import androidx.media3.common.util.UnstableApi
import androidx.media3.database.StandaloneDatabaseProvider
import androidx.media3.datasource.DataSpec
import androidx.media3.datasource.cache.NoOpCacheEvictor
import androidx.media3.datasource.cache.SimpleCache
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertThrows
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import java.io.ByteArrayOutputStream
import java.io.IOException

@UnstableApi
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], application = Application::class)
class OfflineCacheTest {
    @get:Rule val folder = TemporaryFolder()

    @Test fun cachedBytesSurviveReopeningAndNoNetworkFallbackIsPossible() {
        val database = StandaloneDatabaseProvider(RuntimeEnvironment.getApplication())
        val root = folder.newFolder("offline")
        val uri = "https://example.invalid/test.m4a"
        val payload = ByteArray(4096) { (it % 251).toByte() }
        var cache = SimpleCache(root, NoOpCacheEvictor(), database)
        val span = cache.startReadWrite(uri, 0, payload.size.toLong())!!
        val file = cache.startFile(uri, 0, payload.size.toLong())
        file.writeBytes(payload)
        cache.commitFile(file, payload.size.toLong())
        cache.releaseHoleSpan(span)
        cache.release()
        cache = SimpleCache(root, NoOpCacheEvictor(), database)
        try {
            val source = OfflineCache.reader(cache).createDataSource()
            source.open(DataSpec.Builder().setUri(uri).setLength(payload.size.toLong()).build())
            val output = ByteArrayOutputStream()
            val buffer = ByteArray(512)
            try {
                while (true) {
                    val count = source.read(buffer, 0, buffer.size)
                    if (count == -1) break
                    output.write(buffer, 0, count)
                }
            } finally { source.close() }
            assertArrayEquals(payload, output.toByteArray())
            val missing = OfflineCache.reader(cache).createDataSource()
            try {
                assertThrows(IOException::class.java) {
                    missing.open(DataSpec.Builder().setUri("https://example.invalid/missing.m4a").build())
                }
            } finally { missing.close() }
        } finally { cache.release(); database.close() }
    }
}
