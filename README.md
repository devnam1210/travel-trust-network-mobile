# Travel Trust Network Mobile

Ứng dụng Flutter Android với đăng ký/đăng nhập email, Google Sign-In, quản lý JWT, GPS Check-in/Check-out và lịch sử chuyến đi. Mật khẩu email được tạo riêng cho ứng dụng, không dùng mật khẩu tài khoản Google.

Xem [báo cáo phần được giao](doc/ASSIGNED_FEATURES.md) để cấu hình OAuth Android, GPS, mở VisitScreen bằng `placeId`, chạy trên emulator và xem kết quả kiểm tra.

## API xác thực

Backend nằm ở `../travel-trust-network-be`:

| API | Request | Kết quả |
| --- | --- | --- |
| `POST /api/v1/auth/register` | `email`, `fullName`, `password` | JWT và hồ sơ mới |
| `POST /api/v1/auth/login` | `email`, `password` | JWT và hồ sơ hiện có |
| `GET /api/v1/users/me/profile` | `Authorization: Bearer <accessToken>` | Hồ sơ người dùng |

Đăng ký yêu cầu mật khẩu 8–128 ký tự và email chưa có trong hệ thống. Backend chuẩn hóa email về chữ thường, so khớp không phân biệt hoa/thường và lưu **hash PBKDF2**, không lưu mật khẩu gốc. Lần đăng ký đầu nhận điểm uy tín khởi tạo. API trả dữ liệu trong envelope `success`, `code`, `message`, `data` với `data.accessToken` và `data.userProfile`.

App lưu JWT bằng `flutter_secure_storage`, xác minh lại với API hồ sơ khi mở app, xóa phiên khi nhận 401, giữ phiên đã lưu để thử lại sau lỗi mạng/máy chủ. Đăng xuất xóa JWT trên thiết bị. Backend chưa có refresh token hay API thu hồi JWT.

Tài khoản cũ chỉ có đăng nhập Google hoặc dữ liệu seed chưa có mật khẩu, nên không thể đăng nhập qua form mới. Cần cơ chế khôi phục/xác minh email riêng để cấp mật khẩu cho những tài khoản này. Hệ thống hiện chưa xác minh quyền sở hữu địa chỉ email khi đăng ký.

## Chuẩn bị database

Backend dùng `spring.jpa.hibernate.ddl-auto=none`. Với database **đã tồn tại**, chạy `../travel-trust-network-be/doc/05_add_password_auth.sql` bằng tài khoản truy cập database của app trước khi khởi động backend mới. Script thêm cột `password_hash` và unique index không phân biệt chữ hoa/thường; không gán mật khẩu cho các tài khoản cũ. Database mới tạo bằng `doc/03_create_schema.sql` đã có cấu trúc cần thiết. Xem README của backend để thiết lập PostgreSQL và chạy dịch vụ.

## Chạy app

Khởi động backend trước, sau đó chạy trên Android Emulator:

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1
```

`API_BASE_URL` mặc định là `http://10.0.2.2:8080/api/v1`. Trên điện thoại thật, thay `10.0.2.2` bằng địa chỉ LAN của máy chạy backend, kết nối cùng mạng và mở cổng trong firewall. HTTP chỉ được cho phép trong bản debug để dùng backend local; bản release cần URL HTTPS vì email và mật khẩu được gửi qua API. Sao lưu Android được tắt để tránh phục hồi JWT mã hóa sang thiết bị không có khóa giải mã.

Trên Windows với repo ở ổ D: và Pub cache ở ổ C:, `android/gradle.properties` tắt Kotlin incremental compilation để tránh lỗi build do đường dẫn khác ổ. Có thể bật lại nếu cùng ổ. Xem [tài liệu Kotlin compilation](https://kotlinlang.org/docs/gradle-compilation-and-caches.html).

## Kiểm tra

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

Test dùng HTTP adapter giả lập để kiểm tra payload đăng ký/đăng nhập, lỗi thông tin xác thực, JWT, khôi phục phiên, logout và luồng giao diện. Test backend kiểm tra hash, trùng email, sai mật khẩu và tài khoản cũ không có mật khẩu.
