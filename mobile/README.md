# BCMusic cho Android

Bản 1.2.0 cập nhật giao diện từ folder thiết kế do người dùng cung cấp. Chi tiết phạm vi và đối chiếu mẫu nằm trong [DESIGN-1.2.md](DESIGN-1.2.md).

BCMusic là app Flutter cài bằng APK cho Android 8.0 (API 26) trở lên. Giao diện lấy màu, logo và bố cục từ [BCMusic trên web](https://bc-music-gilt.vercel.app/). Các màn hình gồm Trang chủ, Tìm kiếm, Thư viện, Playlist và SoundCloud.

## Dùng app

1. Chọn bài trên Trang chủ hoặc Tìm kiếm. Bạn cũng có thể dán link trong Thư viện hoặc chia sẻ link một bài từ YouTube, SoundCloud hay trình duyệt sang BCMusic.
2. Mở thông tin bài và chọn **Tải để nghe offline** khi có mạng. Chờ trạng thái **Đã tải**.
3. Mở **Thư viện** để phát bản đã tải, kể cả khi mất mạng. Android hiển thị điều khiển phát ở khu vực thông báo và màn hình khóa.
4. Tạo playlist trong tab **Playlist** và thêm các bài đã tải. Playlist lưu trên điện thoại. Playlist web truy cập qua mục **Mở web BCMusic**.

## Tài khoản và cài đặt

- Biểu tượng **Tài khoản** trên thanh đầu app mở menu **Đăng nhập** và **Đăng ký**. Sau khi đăng nhập, app hiện tên tài khoản và menu có mục **Đăng xuất**. Phiên Android được mã hóa bằng Android Keystore.
- **Đăng nhập bằng Google** dùng phiên BCMusic trong trình duyệt hệ thống. Trang xác nhận trả về một mã dùng một lần và Android đổi mã qua HTTPS bằng PKCE. Để bật chức năng này, triển khai các route `/mobile/sign-in` và `/api/mobile/auth/*` lên Vercel với cấu hình NextAuth và Google của website. Kiểm tra `GET /api/mobile/auth/exchange` trả về `{"google":true}`.
- Nút bánh răng mở **Cài đặt**. Âm lượng ứng dụng, tốc độ phát, giao diện sáng/tối và chuyển động mâm đĩa được lưu trên điện thoại. Cài đặt âm thanh áp dụng cho cả bản tải và bài phát trực tuyến.

Dùng những bài bạn có quyền lưu. Tải phụ thuộc vào nguồn còn truy cập được. App hỗ trợ các luồng âm thanh công khai tương thích. Các bài yêu cầu DRM, trả phí hoặc đăng nhập riêng có thể không khả dụng. Tải và playlist nằm trong bộ nhớ riêng của ứng dụng. Cài bản cập nhật có cùng chữ ký để giữ dữ liệu.

## Build trên Windows

Cần Flutter 3.47.1, JDK 17 và Android SDK 36. Script chuẩn bị bộ công cụ dòng lệnh dưới thư mục cục bộ `.android-tools` của repo. Có thể dùng JDK và SDK hiện có qua `JAVA_HOME` và `ANDROID_HOME`.

```powershell
Set-Location D:\music\mobile
.\tool\prepare-android.ps1 -InstallSdk
.\tool\bcmusic.ps1 check
.\tool\bcmusic.ps1 build
```

Có thể thêm `-LoginUsername 'ten-dang-nhap'` vào lệnh build để điền sẵn tên người dùng trong biểu mẫu đăng nhập của APK cá nhân.

APK được tạo tại `build\app\outputs\flutter-apk\app-release.apk`. Bản cài cá nhân dùng khóa debug cục bộ để có thể cập nhật bản đã cài qua USB. Khi cắm điện thoại và bật gỡ lỗi USB, dùng:

```powershell
..\.android-tools\sdk\platform-tools\adb.exe devices
..\.android-tools\sdk\platform-tools\adb.exe install -r .\build\app\outputs\flutter-apk\app-release.apk
```

`check` chạy Flutter analyze/test, Android unit test và lint. `.\tool\bcmusic.ps1 live-test` kiểm tra adapter với YouTube và SoundCloud thật khi có Internet.

## Cấu trúc

- `lib/` dựng giao diện Flutter và lấy bảng nhạc/tìm kiếm từ API công khai của BCMusic.
- `android/app/src/main/kotlin/app/bcmusic/personal/` quản lý lấy nguồn, tải, cache, playlist và phát nền bằng AndroidX Media3.
- `test/` và `android/app/src/test/` chứa kiểm thử Flutter và Android.
- App dùng [NewPipeExtractor v0.26.5](https://github.com/TeamNewPipe/NewPipeExtractor/tree/v0.26.5) theo GPL-3.0. Văn bản giấy phép có trong [assets](assets/licenses/NewPipeExtractor-GPL-3.0.txt) và mục **Về ứng dụng**.
