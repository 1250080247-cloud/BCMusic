# Đặc tả module offline-library

Trạng thái: dự thảo. Phụ thuộc: source-resolver. Quy ước chung: [SPEC-android.md](SPEC-android.md).

## Mục tiêu

Người dùng tải âm thanh về điện thoại, theo dõi tiến độ, hủy/thử lại/xóa và giữ thư viện qua các lần mở app. Một mục chỉ được hiển thị sẵn sàng offline khi toàn bộ dữ liệu cần phát đã tải hoàn tất.

## Hợp đồng và dữ liệu

```kotlin
interface OfflineLibrary {
    fun observeTracks(): Flow<List<OfflineTrack>>
    suspend fun enqueue(track: ResolvedTrack)
    suspend fun retry(trackId: String)
    suspend fun remove(trackId: String)
}
```

- `OfflineTrack` chứa track ID, source URL, metadata cục bộ, trạng thái và tiến độ. Trạng thái thể hiện đang đợi mạng, đang tải, tạm dừng, lỗi, đã tải hoặc đang xóa.
- Metadata được lưu cùng DownloadRequest; trạng thái và dữ liệu cache do Media3 sở hữu. Danh tính bài không phụ thuộc URL âm thanh tạm thời.
- Nội dung tải và metadata nằm trong vùng tệp riêng bền vững của app, tách vùng cache tạm; cache tải dùng NoOpCacheEvictor. Ảnh bìa lỗi không biến âm thanh đã tải thành tải lỗi.
- Dùng Media3 DownloadService/DownloadManager và DownloadIndex/StandaloneDatabaseProvider; tải HLS bằng downloader phù hợp, không lưu playlist m3u8 rồi coi đó là âm thanh hoàn chỉnh.
- Một tải đồng thời theo mặc định. Bấm tải lại cùng ID không tạo hai bản. Đọc input URI/headers từ descriptor đã xác thực và giữ HTTPS.
- Mạng bị mất hoặc tiến trình bị tạo lại phải hiện trạng thái thật; việc tiếp tục thực hiện theo cơ chế service/scheduler được Android cho phép. Người dùng force-stop có thể cần mở lại app để tiếp tục.
- Lỗi URL nguồn hết hạn có thể thử lại bằng cách resolve canonical URL mới. Giữ trạng thái cũ cho đến khi thao tác thay thế nhất quán; không đánh dấu hoàn tất trước lúc dữ liệu sẵn sàng.
- Hủy tác vụ không để bản tải dở xuất hiện trong “Đã tải”. Xóa phải loại đúng bản tải và metadata do app sở hữu, kể cả khi thao tác được lặp lại.
- Thiếu dung lượng phải dừng/báo lỗi phù hợp; hiển thị số byte hoặc tiến độ không xác định khi nguồn thiếu Content-Length. Không tạo phần trăm hoàn tất giả.
- Tắt sao lưu hệ thống cho âm thanh/URL có token; thư viện không được đồng bộ lên tài khoản web ngoài yêu cầu.

## Công nghệ và cấu trúc

Media3 download/cache 1.11.1 theo đặc tả chung. Mã `mobile/android/app/src/main/kotlin/app/bcmusic/personal/`, metadata/schema và các test tích hợp tại `src/test/` hoặc `src/androidTest/` cùng package. Các đường dẫn cache được tạo từ khóa nội bộ, không từ title/URL người dùng.

## Quy ước mã

Áp dụng Kotlin và ánh xạ lỗi chung. Tập trung vòng đời DownloadManager/cache/database tại cấp Application; UI quan sát trạng thái thay vì mở cache instance thứ hai.

## Lệnh và kiểm thử

Từ `D:\music\android`: `./gradlew.bat :app:testDebugUnitTest --tests "*Download*"`; `./gradlew.bat :app:connectedDebugAndroidTest`; `./gradlew.bat :app:assembleDebug`.

Test với HTTP server và âm thanh fixture: tải hoàn tất, dữ liệu rỗng/bị cắt, ngắt mạng, URL hết hạn, cancel, thiếu dung lượng, chống trùng, xóa lặp và khởi tạo lại repository. Kiểm tra cold start trong chế độ máy bay và khôi phục sau process death trên thiết bị.

## Ranh giới

- Luôn: giới hạn đồng thời, ghi dữ liệu bền vững nhất quán, kiểm tra phạm vi đường dẫn và dọn đúng tài nguyên của app.
- Cần trao đổi: export audio ra bộ nhớ chung, đồng bộ cloud, tải playlist hàng loạt hoặc tự tải không có thao tác người dùng.
- Không đánh dấu sẵn sàng chỉ vì đã có metadata; không xóa tệp bên ngoài vùng app quản lý hoặc lưu media vào MongoDB/Vercel.

## Tiêu chí hoàn thành

1. Một bài được tải hoàn tất xuất hiện và phát được offline sau khi đóng/mở app.
2. Mất mạng, lỗi nguồn, hủy và thiếu dung lượng không tạo bản tải hoàn tất giả; retry và chống trùng hoạt động.
3. Xóa giải phóng đúng bản tải, cập nhật UI và không làm hỏng bài khác.

## Điểm còn lại

HLS/progressive cụ thể phụ thuộc descriptor mà source-resolver trả về. Luồng tương ứng phải được kiểm chứng bằng dữ liệu thật và fixture phù hợp.
