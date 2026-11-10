# Giao diện BCMusic Android

`mobile/lib/` chứa giao diện Flutter tiếng Việt. Logo và tông nền tối/điểm nhấn hồng dựa trên web BCMusic. Trang chủ có mâm đĩa, thể loại và các dải thịnh hành, nhiều lượt xem, mới nhất. Tìm kiếm dùng API công khai trên Vercel. Điều hướng dưới cùng có Trang chủ, Tìm kiếm, Thư viện, Playlist và SoundCloud.

Thư viện hiển thị bài đã tải, bài đang tải hoặc lỗi. SoundCloud hiển thị bản tải thuộc nguồn này và nhận link bài SoundCloud. Người dùng có thể tạo playlist cục bộ và thêm bài đã tải. Trình phát thu nhỏ hiển thị tiêu đề và tiến độ, mở rộng để tua, xem ảnh bìa và chuyển bài trong hàng đợi.

Khi mở app không có mạng, thư viện cục bộ hiện trước. Giao diện, logo và các nút điều khiển nằm trong APK. Người dùng xem trạng thái trống hoặc lỗi và thử lại khi nguồn khả dụng. Kết nối MethodChannel/EventChannel tách UI khỏi Android service.

Kiểm thử Flutter xác nhận điều hướng vào thư viện trống, nhập link và bố cục màn hình nhỏ khi tăng cỡ chữ. Kiểm tra bằng thiết bị gồm kết quả khám phá, chuyển tab, trình phát và mở app khi mất mạng.
