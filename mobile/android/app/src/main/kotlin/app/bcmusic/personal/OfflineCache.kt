package app.bcmusic.personal

import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.cache.Cache
import androidx.media3.datasource.cache.CacheDataSource

@UnstableApi
object OfflineCache {
    // Cache misses must fail locally. A signed remote URL in a DownloadRequest is
    // retained only as the cache key and never becomes a playback network fallback.
    fun reader(cache: Cache): CacheDataSource.Factory = CacheDataSource.Factory()
        .setCache(cache).setUpstreamDataSourceFactory(null).setCacheWriteDataSinkFactory(null)
}
