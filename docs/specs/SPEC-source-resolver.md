# Đặc tả module source-resolver

Trạng thái: dự thảo. Phụ thuộc: không có. Quy ước chung: [SPEC-android.md](SPEC-android.md).

## Mục tiêu

Đổi link bài YouTube/SoundCloud do người dùng chọn thành danh tính bài ổn định, metadata và nguồn âm thanh hỗ trợ tải, thông qua adapter NewPipeExtractor. Ranh giới này dùng chung cho nhận link và thử lại bản tải có URL nguồn hết hạn.

## Hợp đồng và quy tắc

```kotlin
interface TrackResolver {
    suspend fun resolve(source: SourceRef): ResolvedTrack
}
```

- `SourceRef` chỉ chứa nhà cung cấp được hỗ trợ và URL bài được chuẩn hóa.
- `ResolvedTrack` gồm ID có namespace nhà cung cấp, canonical source URL, title, artist, duration khi biết, thumbnail khi có và nguồn âm thanh kèm MIME/headers cần thiết.
- ID lấy từ dữ liệu nhà cung cấp, không dùng URL âm thanh có token làm khóa bài. Video YouTube cùng ID qua watch/youtu.be phải cho cùng danh tính; SoundCloud lấy ID track đã resolve.
- Chỉ nhận một bài; playlist, trang tài khoản hoặc link không thuộc hai nguồn trả lỗi URL/không hỗ trợ rõ ràng. URL rút gọn được theo dõi redirect có giới hạn và xác minh lại đích.
- Kiểm tra scheme/host/path thực tế; từ chối URL giả tên miền, userinfo, địa chỉ nội bộ, scheme file/content/javascript và input quá dài. HTTP client kiểm tra lại redirect; lỗi TLS không được bỏ qua.
- Gọi mạng ngoài main thread, timeout hữu hạn, hủy được. Metadata bên ngoài được coi là không tin cậy; không đưa HTML vào WebView hoặc đường dẫn tệp.
- Ưu tiên nguồn audio-only có định dạng ExoPlayer hỗ trợ; giữ chất lượng hợp lý theo khả năng nguồn. HLS cần MIME phù hợp để downloader chọn đúng luồng. Không đổi đuôi sang MP3 khi chưa chuyển mã.
- Phân biệt `INVALID_URL`, `UNAVAILABLE`, `NETWORK`, `UNSUPPORTED`, `EXTRACTOR_FAILED`; UI nhận thông báo tiếng Việt tương ứng. Không cam kết lấy được mọi bài từ hai dịch vụ.

## Công nghệ và cấu trúc

Kotlin, NewPipeExtractor và HTTP client theo `SPEC-android.md`. Mã đặt trong `mobile/android/app/src/main/kotlin/app/bcmusic/personal/`; test tại package tương ứng dưới `src/test/`. Phần phụ thuộc extractor được giữ trong một adapter để cập nhật khi upstream thay đổi.

## Quy ước mã

Dùng data class bất biến và enum lỗi theo đặc tả chung; chuẩn hóa URL là hàm kiểm thử được độc lập. Không dùng chuỗi exception hoặc tên miền chỉ chứa substring để cấp quyền truy cập nguồn.

## Lệnh và kiểm thử

Từ `D:\music\android`: `./gradlew.bat :app:testDebugUnitTest --tests "*Source*"`; build `./gradlew.bat :app:assembleDebug`.

Test trước cho watch/youtu.be, query thừa, link SoundCloud, link giả tên miền, playlist, scheme sai, metadata thiếu và ánh xạ lỗi timeout. Kiểm tra adapter bằng fixture cục bộ; kiểm chứng riêng một bài YouTube và một bài SoundCloud được quyền tải. Nếu upstream trả chặn/challenge, ghi kết quả thật và xác định phần chưa chạy được.

## Ranh giới

- Luôn: ghim phiên bản extractor, ghi giấy phép, kiểm tra schema/URL tại ranh giới, bỏ token/cookie khỏi log.
- Cần trao đổi: yêu cầu đăng nhập YouTube/SoundCloud, dùng cookie cá nhân hoặc bổ sung nhà cung cấp.
- Không lấy bí mật web, không dùng API trả phí ngầm, không vượt DRM/paywall hoặc biến URL người dùng thành lệnh hệ thống.

## Tiêu chí hoàn thành

1. Input hợp lệ của bài mẫu mỗi nguồn tạo descriptor dùng được cho downloader; input không hợp lệ dừng trước khi tạo tác vụ tải.
2. Các biến thể link cùng bài tránh trùng danh tính; metadata hiển thị được khi có trường tùy chọn bị thiếu.
3. Timeout, nguồn hết hạn, nguồn bị chặn và lỗi extractor có trạng thái riêng; retry lấy nguồn mới từ canonical URL.

## Điểm còn lại

v0.26.5 là ứng viên. Khả năng xử lý nguồn thật phải được xác minh sớm, trước khi coi dependency và định dạng tải đã chốt.
