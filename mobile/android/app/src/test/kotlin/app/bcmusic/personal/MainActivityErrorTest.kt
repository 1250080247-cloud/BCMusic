package app.bcmusic.personal

import org.junit.Assert.assertEquals
import org.junit.Test
import java.net.ConnectException
import java.net.SocketTimeoutException
import java.net.UnknownHostException

class MainActivityErrorTest {
    @Test
    fun sourceFailurePreservesCodeAndMessage() {
        val failure = SourceFailure("NOT_FOUND", "Không tìm thấy bài hát.")
        val (code, message) = mapExceptionToFlutterError(failure)
        assertEquals("NOT_FOUND", code)
        assertEquals("Không tìm thấy bài hát.", message)
    }

    @Test
    fun networkExceptionsMapToNetworkCode() {
        val unknownHost = UnknownHostException("Unable to resolve host")
        val (code1, message1) = mapExceptionToFlutterError(unknownHost)
        assertEquals("NETWORK", code1)
        assertEquals("Không có kết nối mạng. Hãy kiểm tra kết nối và thử lại.", message1)

        val connect = ConnectException("Failed to connect to 127.0.0.1")
        val (code2, _) = mapExceptionToFlutterError(connect)
        assertEquals("NETWORK", code2)

        val timeout = SocketTimeoutException("Read timed out")
        val (code3, _) = mapExceptionToFlutterError(timeout)
        assertEquals("NETWORK", code3)
    }

    @Test
    fun generalExceptionsMapToInternalCode() {
        val illegalState = IllegalStateException("Corrupted state")
        val (code, message) = mapExceptionToFlutterError(illegalState)
        assertEquals("INTERNAL", code)
        assertEquals("Chưa thực hiện được thao tác. Hãy mở lại app và thử lại.", message)
    }
}
