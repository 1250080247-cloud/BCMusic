package app.bcmusic.personal

import android.os.SystemClock
import androidx.media3.common.C
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.audio.TeeAudioProcessor
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.PI
import kotlin.math.exp
import kotlin.math.sqrt

@UnstableApi
internal class PlaybackSpectrum : TeeAudioProcessor.AudioBufferSink {
    @Volatile var enabled = false
    @Volatile var levels = listOf(0.0, 0.0, 0.0)
        private set
    private var sampleRate = 0
    private var channels = 0
    private var lowGain = 0.0
    private var midGain = 0.0
    private var low = 0.0
    private var mid = 0.0
    private var lastSample = 0L

    override fun flush(sampleRateHz: Int, channelCount: Int, encoding: Int) {
        sampleRate = if (encoding == C.ENCODING_PCM_16BIT) sampleRateHz else 0
        channels = channelCount
        if (sampleRate > 0) {
            lowGain = 1 - exp(-2 * PI * 220 / sampleRate)
            midGain = 1 - exp(-2 * PI * 2300 / sampleRate)
        }
        low = 0.0
        mid = 0.0
        lastSample = 0
        levels = listOf(0.0, 0.0, 0.0)
    }

    override fun handleBuffer(buffer: ByteBuffer) {
        if (!enabled || sampleRate == 0 || channels < 1) return
        val now = SystemClock.elapsedRealtime()
        if (now - lastSample < 55) return
        val step = channels * 2
        val count = minOf(buffer.remaining() / step, 2048)
        if (count == 0) return
        lastSample = now
        val pcm = buffer.duplicate().order(ByteOrder.LITTLE_ENDIAN)
        var bass = 0.0
        var middle = 0.0
        var treble = 0.0
        repeat(count) { frame ->
            val sample = pcm.getShort(pcm.position() + frame * step) / 32768.0
            low += lowGain * (sample - low)
            mid += midGain * (sample - mid)
            bass += low * low
            middle += (mid - low) * (mid - low)
            treble += (sample - mid) * (sample - mid)
        }
        levels = listOf(bass, middle, treble).map { (sqrt(it / count) * 4).coerceIn(0.0, 1.0) }
    }
}
