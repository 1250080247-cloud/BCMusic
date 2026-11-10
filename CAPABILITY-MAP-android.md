# BCMusic Android

Bản Flutter cá nhân ở `mobile/` chạy từ Android 8.0. Giao diện dùng logo và phong cách của web BCMusic. Chọn bài trong app, dán link hoặc dùng chức năng chia sẻ của Android để tải trước. Bản tải và playlist dùng được khi không có mạng hoặc khi khóa màn hình.

| Module | Trách nhiệm |
| --- | --- |
| [Android shell](SPEC-android-shell.md) | Trang chủ, tìm kiếm, thư viện, playlist, SoundCloud, điều hướng và trình phát Flutter. |
| [Nguồn nhạc](SPEC-source-resolver.md) | Chuẩn hóa link và lấy thông tin cùng luồng âm thanh YouTube/SoundCloud tương thích. |
| [Thư viện offline](SPEC-offline-library.md) | Tải, quản lý cache, theo dõi trạng thái và lưu playlist trong app. |
| [Bộ phát](SPEC-native-playback.md) | Phát từ cache, thông báo media, audio focus và điều khiển màn hình khóa. |
| [Chuyển link](SPEC-bcmusic-handoff.md) | Chia sẻ/dán link, đọc API công khai của BCMusic và mở web trong trình duyệt. |

[Xem cấu hình và tiêu chí kiểm thử](SPEC-android.md). [Xem hướng dẫn build và cài](mobile/README.md).
