# Travel Trust Network Mobile

Ứng dụng Flutter Android với đăng ký/đăng nhập email, Google Sign-In, quản lý JWT, GPS Check-in/Check-out và lịch sử chuyến đi. Mật khẩu email được tạo riêng cho ứng dụng, không dùng mật khẩu tài khoản Google.

Xem [báo cáo phần được giao](doc/ASSIGNED_FEATURES.md) để cấu hình OAuth Android, GPS, mở VisitScreen bằng `placeId`, chạy trên emulator và xem kết quả kiểm tra.

## API xác thực

Backend nằm ở `../travel-trust-network-be`:

| API | Request | Kết quả |
| --- | --- | --- |
| `POST /api/v1/auth/register` | `email`, `fullName`, `password` | JWT và hồ sơ mới |
| `POST /api/v1/auth/login` | `email`, `password` | JWT và hồ sơ hiện có |
| `POST /api/v1/auth/refresh` | `refreshToken` | Cặp access token và refresh token mới |
| `POST /api/v1/auth/logout` | `refreshToken` | Thu hồi phiên trên thiết bị hiện tại |
| `GET /api/v1/users/me/profile` | `Authorization: Bearer <accessToken>` | Hồ sơ người dùng |

Đăng ký yêu cầu mật khẩu 8–128 ký tự và email chưa có trong hệ thống. Backend chuẩn hóa email về chữ thường, so khớp không phân biệt hoa/thường và lưu **hash PBKDF2**, không lưu mật khẩu gốc. Lần đăng ký đầu nhận điểm uy tín khởi tạo. API trả dữ liệu trong envelope `success`, `code`, `message`, `data` với `data.accessToken` và `data.userProfile`.

App lưu cặp access/refresh token trong một giá trị mã hóa bằng `flutter_secure_storage`. Khi mở lại app hoặc API trả 401, app tự gia hạn và thử lại yêu cầu một lần; các yêu cầu đồng thời dùng chung một lần refresh. Lỗi mạng/máy chủ giữ phiên để thử lại. Đăng xuất thu hồi refresh token trên backend trước khi xóa thông tin trên máy. Access token mặc định 15 phút, phiên refresh tối đa 30 ngày. Tài khoản đang dùng bản cũ cần đăng xuất/đăng nhập lại một lần để nhận refresh token. Chi tiết cấu hình, giới hạn và kiểm thử: [docs/AUTH_SESSIONS.md](docs/AUTH_SESSIONS.md).

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

### Kiểm tra GPS trước khi check-in

Trong màn **GPS Check-in / Check-out**, bấm **Kiểm tra GPS / Đo lại** để xem
tọa độ địa điểm lấy từ API, tọa độ điện thoại, sai số ước tính và khoảng cách.
Nút này chỉ đo vị trí, chưa tạo chuyến đi. Khi bấm **Check-in**, app đo lại vị trí
và giữ thông tin đã gửi trên màn hình nếu máy chủ từ chối vì ngoài bán kính.

App yêu cầu quyền vị trí chính xác, bỏ qua mẫu quá 30 giây và chờ tối đa 20 giây
để lấy mẫu có sai số ước tính ≤50 m. Nếu hết thời gian, app dùng mẫu gần đây có
sai số nhỏ nhất đã nhận và hiển thị cảnh báo nếu chưa đạt độ chính xác này.
50 m là mục tiêu lấy mẫu, không thay đổi bán kính xác thực của địa điểm trên backend.
Vị trí trong nhà có thể kém chính xác; kiểm tra quyền **Vị trí chính xác** và thử
đo lại ở nơi thoáng. Chưa thể xác định nguyên nhân lệch vị trí cụ thể nếu chưa có
số đo từ điện thoại đang gặp lỗi.

### Kiểm tra tự động

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

Test dùng HTTP adapter giả lập để kiểm tra payload đăng ký/đăng nhập, lỗi thông tin xác thực, JWT, khôi phục phiên, logout và luồng giao diện. Test backend kiểm tra hash, trùng email, sai mật khẩu và tài khoản cũ không có mật khẩu.

### Thông báo bạn bè và tin nhắn

Xem [hướng dẫn realtime và cấu hình Firebase](docs/NOTIFICATIONS.md). Trong app có thông báo realtime, chuông chưa đọc và lịch sử; thông báo khi chạy nền/đóng app cần Firebase project. Docker backend tự áp dụng migration 08; sau đó khởi động lại Spring Boot và build lại Flutter.
