# Đặc tả BCMusic Android cá nhân

## Hành vi

BCMusic mở được khi không có mạng và hiển thị các bản tải còn trong thiết bị. Người dùng có thể khám phá và tìm bài qua dữ liệu công khai của [BCMusic](https://bc-music-gilt.vercel.app/) khi có mạng, chọn một bài hoặc nhập link YouTube/SoundCloud, xem thông tin và chủ động yêu cầu tải. Từ thư viện, người dùng phát hoặc tua bản tải, tạo playlist từ các bài đã tải và tiếp tục nghe khi khóa màn hình.

| Thành phần | Phạm vi |
| --- | --- |
| [Android shell](SPEC-android-shell.md) | Giao diện Flutter tiếng Việt theo web BCMusic. |
| [Nguồn nhạc](SPEC-source-resolver.md) | Xác thực link, lấy metadata và luồng âm thanh tương thích. |
| [Thư viện offline](SPEC-offline-library.md) | Tải, tiến độ, hủy, thử lại, xóa và lưu playlist trên máy. |
| [Bộ phát](SPEC-native-playback.md) | Media3, cache offline, thông báo, audio focus, hàng đợi và màn hình khóa. |
| [Chuyển link](SPEC-bcmusic-handoff.md) | Nhận link chia sẻ/dán, khám phá từ API web, mở trang web trong trình duyệt. |

## Triển khai

- Project Flutter 3.47.1 / Dart 3.13.1 ở `mobile/`. Kotlin native nằm trong `mobile/android/app/src/main/kotlin/app/bcmusic/personal/`.
- Android application ID `app.bcmusic.personal`, minSdk 26, compile/target SDK 36. Gradle 9.3.1, AGP 9.1.0, JDK 17, Kotlin tích hợp với compiler 2.4.0.
- AndroidX Media3 1.11.1 tải/phát luồng progressive hoặc HLS. SimpleCache và DownloadIndex giữ dữ liệu trong thư mục riêng của app. Cache của bộ phát offline không có nguồn mạng dự phòng.
- NewPipeExtractor v0.26.5 và OkHttp 4.12.0 xử lý nguồn. Adapter SoundCloud hỗ trợ luồng HLS AAC 96k công khai. Khi nền tảng đổi cách cung cấp nguồn, cần chạy lại kiểm tra nguồn thật.
- Flutter gọi MethodChannel và quan sát snapshot qua EventChannel. Android MediaSessionService quản lý phát độc lập với màn hình Flutter. Metadata và dữ liệu tải sống qua lần đóng app.
- Dữ liệu duyệt web và tìm kiếm cần mạng. Playlist tạo trong app lưu cục bộ. Android đăng nhập và đăng ký cùng tài khoản web bằng API NextAuth hiện có. Kết nối Google dùng trang xác nhận web và mã trao đổi một lần có PKCE. Phiên Android nằm trong vùng lưu trữ mã hóa bằng Keystore.
- Cài đặt âm lượng, tốc độ, giao diện và chuyển động lưu trên máy. Dịch vụ phát Android nạp cài đặt âm thanh khi khởi tạo.

Xem lệnh build, cài và kiểm thử ở [mobile/README.md](mobile/README.md).

## Kiểm chứng

1. Flutter analyze và widget/controller tests. Android unit test cho link, playlist, cache chỉ đọc offline và định dạng SoundCloud. Test nguồn thật chạy riêng.
2. Trên điện thoại Android, cài bản test, mở các tab chính và kiểm tra kết quả khám phá/tìm kiếm.
3. Tải thử từ YouTube và SoundCloud với bài phù hợp. Tắt Wi-Fi và dữ liệu, đóng/mở app, phát bài có trạng thái **Đã tải**, khóa màn hình và kiểm tra Android MediaSession vẫn phát.
4. Tạo và phát playlist cục bộ. Xuất APK cá nhân, kiểm tra chữ ký và cài cập nhật để kiểm tra dữ liệu được giữ.

## Tham khảo

- [Media3 tải offline](https://developer.android.com/media/media3/exoplayer/downloading-media)
- [Media3 phát nền](https://developer.android.com/media/media3/session/background-playback)
- [NewPipeExtractor v0.26.5](https://github.com/TeamNewPipe/NewPipeExtractor/tree/v0.26.5)
