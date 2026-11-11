# Phiên đăng nhập và refresh token

Backend mặc định cấp access JWT 15 phút và refresh token ngẫu nhiên 256 bit cho một phiên 30 ngày. Các giá trị có thể đổi bằng `TTN_JWT_EXPIRATION_MS` (mặc định `900000`) và `TTN_REFRESH_EXPIRATION_MS` (mặc định `2592000000`). Thay đổi thời hạn chỉ áp dụng cho token/phiên mới. Đăng nhập email, đăng ký và Google đều nhận `accessToken`, `refreshToken`, `expiresIn` (giây), `refreshExpiresAt` (UTC) và `userProfile`.

## API

| API | Body | Kết quả |
| --- | --- | --- |
| `POST /api/v1/auth/refresh` | `{"refreshToken":"<token>"}` | `accessToken`, `refreshToken` mới, `expiresIn`, `refreshExpiresAt` |
| `POST /api/v1/auth/logout` | `{"refreshToken":"<token>"}` | Thu hồi cả chuỗi token của phiên đó; gọi lại an toàn |

Hai API dùng refresh token trong body, không cần access token còn hạn. Phản hồi auth đặt `Cache-Control: no-store`. Không gửi token trên URL hoặc theo redirect. Backend lưu SHA-256 của refresh token, không lưu chuỗi gốc; các token đã dùng được giữ đến hết hạn để phát hiện dùng lại. Dùng lại token cũ làm thu hồi toàn bộ phiên đó, kể cả token mới nhất. Các thiết bị đăng nhập khác có phiên riêng. Thời hạn 30 ngày được giữ nguyên khi refresh, không kéo dài vô hạn. Cách xoay vòng và thu hồi khi phát hiện dùng lại tham khảo [RFC 9700, mục 4.14.2](https://www.rfc-editor.org/rfc/rfc9700.html#section-4.14.2).

Đăng xuất thu hồi refresh token; access JWT đã cấp vẫn có thể được backend chấp nhận đến khi hết hạn. Chưa có danh sách thu hồi JWT hay tính năng đăng xuất mọi thiết bị. Phiên hết hạn được dọn định kỳ, cùng các bản băm liên quan.

## Mobile

Access và refresh token được ghi cùng một giá trị Secure Storage để tránh lưu lệch cặp token. Dữ liệu access-only của bản cũ vẫn đọc được; cần đăng nhập lại một lần để có refresh token.

API được bảo vệ trả 401 sẽ chờ một lần refresh chung, rồi thử lại tối đa một lần. JSON giữ nguyên body và `clientMessageId`; multipart được clone để đọc lại file; ảnh riêng tư và SSE dùng chung cơ chế. Request auth không gọi refresh đệ quy. App không tự thử lại yêu cầu ghi chỉ vì mất mạng. Nếu refresh bị từ chối, app xóa phiên; lỗi mạng, 5xx hoặc phản hồi refresh không hợp lệ giữ thông tin để thử lại.

Chat, phân trang, gửi ảnh, hồ sơ bạn bè, đăng ký push và thông báo kiểm tra danh tính phiên thay vì chuỗi access JWT, nên không ngừng hoạt động khi token xoay vòng. Phản hồi muộn của phiên cũ không ghi đè phiên mới. Đăng xuất chờ refresh đang chạy, thu hồi phiên trên server rồi xóa dữ liệu local; nếu không liên lạc được với server, app giữ phiên và cho thử đăng xuất lại.

Worker widget nền chỉ dùng access token, không xoay vòng refresh token song song với foreground. Sau khi access token hết hạn, việc cập nhật widget đợi phiên foreground được gia hạn. FCM nhận thông báo nền hoạt động độc lập với access JWT.

Refresh token dùng một lần. Nếu server đã xoay token nhưng phản hồi bị mất hoặc không thể lưu cặp mới, lần refresh tiếp theo có thể yêu cầu đăng nhập lại. Không có cơ chế bỏ qua phát hiện dùng lại token.

## Triển khai và kiểm tra

Trong backend chạy `docker compose up -d --wait` để áp dụng `doc/10_refresh_tokens.sql`, sau đó khởi động lại Spring Boot. Giữ nguyên volume database. Dừng và Run lại Flutter, rồi đăng xuất/đăng nhập lại một lần.

Đã kiểm tra ngày 2026-11-11: analyzer sạch, **163 kiểm thử Flutter** và **80 kiểm thử backend** đều đạt; Docker kiểm tra volume cũ/mới và giữ bản băm refresh qua restart. API localhost thật đã kiểm tra refresh → đọc hồ sơ, logout → từ chối refresh, và dùng lại token cũ → thu hồi token mới. Các phiên kiểm tra tạm được tạo riêng và xóa sau kiểm tra; tài khoản và tin nhắn hiện có không bị sửa.
