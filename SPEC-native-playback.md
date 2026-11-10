# Đặc tả module native-playback

Trạng thái: dự thảo. Phụ thuộc: offline-library. Quy ước chung: [SPEC-android.md](SPEC-android.md).

## Mục tiêu

Phát bản tải hoàn tất, hỗ trợ phát/dừng, tua, bài trước/sau và tiếp tục nghe khi khóa màn hình hoặc chuyển ứng dụng. UI và hệ thống cùng điều khiển một player qua MediaSession.

## Hợp đồng và hành vi

```kotlin
interface OfflinePlayback {
    suspend fun play(trackId: String, queueIds: List<String>)
}
```

- ExoPlayer và MediaSession đặt trong MediaSessionService; Activity kết nối MediaController. Service sở hữu player, không dùng Activity để giữ nhạc sống.
- Hàng đợi chỉ chứa bài tải hoàn tất và còn khả dụng. Bài bị xóa/mất cache phải bị loại hoặc trả lỗi rõ ràng.
- Playback dùng CacheDataSource chỉ đọc với upstream mạng bị tắt. Mất dữ liệu cache phải báo cần tải lại, không âm thầm phát từ mạng.
- Metadata title/artist và artwork cục bộ khi có được đưa vào MediaItem để hiển thị thông báo/màn hình khóa khi offline.
- Tôn trọng audio focus, cuộc gọi và rút tai nghe. Chỉ phát sau thao tác người dùng; mở app/khôi phục tiến trình không tự phát bất ngờ.
- Phát tiếp khi Activity bị hủy do điều hướng hoặc màn hình khóa. Thao tác force-stop/Stop của Android dừng dịch vụ theo ý người dùng.
- Thông báo dùng foreground service loại mediaPlayback và các quyền Android yêu cầu; giải phóng session/player khi kết thúc vòng đời.
- Tua và chuyển bài không tạo phiên phát thứ hai; trạng thái trên UI và điều khiển hệ thống phải thống nhất.

## Công nghệ và cấu trúc

Media3 ExoPlayer/Session 1.11.1, manifest service và notification resource theo `SPEC-android.md`. Mã ở `mobile/android/app/src/main/kotlin/app/bcmusic/personal/`; test cùng package dưới `src/test/` và `src/androidTest/`.

## Quy ước mã

Kotlin theo đặc tả chung. Thao tác player tuân theo application looper; callback/listener được tháo đúng lifecycle. Lỗi cache/file ánh xạ thành trạng thái thư viện có thể khắc phục.

## Lệnh và kiểm thử

Từ `D:\music\android`: `./gradlew.bat :app:testDebugUnitTest --tests "*Playback*"`; `./gradlew.bat :app:connectedDebugAndroidTest`; `./gradlew.bat :app:lintDebug`; `./gradlew.bat :app:assembleDebug`.

Test queue không hợp lệ, bài đang tải, bài bị xóa và cache miss. Thiết bị Android 8/12: bật chế độ máy bay, phát/tua/chuyển bài, khóa màn hình, điều khiển qua thông báo, chuyển app, rút tai nghe và giành audio focus. Test giả lập không thay bằng chứng phát nền trên thiết bị.

## Ranh giới

- Luôn: foreground notification khi cần, audio focus đúng, player duy nhất và đọc dữ liệu offline thật.
- Cần trao đổi: tự phát lúc boot, tích hợp Android Auto/Cast hoặc stream online bằng native player.
- Không dùng WebView/IFrame làm player offline, không đặt dịch vụ chạy vô hạn khi đã dừng phát và không cố vượt force-stop của hệ điều hành.

## Tiêu chí hoàn thành

1. Bài tải hoàn tất phát được trong chế độ máy bay, kể cả sau cold start; cache thiếu báo lỗi phù hợp.
2. Nhạc tiếp tục khi khóa màn hình/chuyển app; thông báo và điều khiển màn hình khóa vận hành trên Android 8/12.
3. Pause/seek/next và audio focus làm trạng thái UI/hệ thống thống nhất, không tạo hai luồng âm thanh.

## Điểm còn lại

Hành vi tiết kiệm pin của hãng điện thoại cần kiểm tra trên thiết bị thực tế; không thể bảo đảm service tồn tại sau force-stop hoặc các hạn chế của hãng.
