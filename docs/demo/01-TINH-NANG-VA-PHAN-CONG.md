# Danh sách tính năng và phân công

## 1. Mục tiêu sản phẩm

Travel Trust Network giúp người dùng khám phá địa điểm và viết đánh giá gắn với chuyến đi được kiểm tra vị trí. Luồng mục tiêu: đăng nhập → khám phá → chi tiết → check-in/check-out → tạo ảnh → đăng review → xem Locket/hồ sơ.

Kiến trúc hiện tại: Flutter + Riverpod + Dio ở mobile; Java 21 + Spring Boot 3.3.13 + Spring Security/JWT + PostgreSQL ở backend. Backend là modular monolith dùng chung database, chia module `auth`, `place`, `visit`, `media`, `review_locket`.

Quy ước: **Có code** nghĩa là đã tìm thấy triển khai; không tự đồng nghĩa đã chạy trên điện thoại thật. **Chưa có FE** nghĩa là API có code nhưng chưa có màn hình gọi API đó.

## 2. Ma trận tính năng thực tế

| ID | Tính năng | FE | BE và dữ liệu | Điều kiện nghiệm thu/demo |
|---|---|---|---|---|
| F01 | Đăng ký email/mật khẩu | Có form, validate tên/email/password/xác nhận | `POST /auth/register`, hash PBKDF2, chống trùng email, tạo 50 điểm và log | Tài khoản mới → hồ sơ; email trùng → 409 |
| F02 | Đăng nhập email/mật khẩu | Có | `POST /auth/login`, JWT | Sai mật khẩu → thông báo; đúng → hồ sơ |
| F03 | Khôi phục phiên, đăng xuất | Có secure storage, gọi profile, retry lỗi mạng | Profile xác thực JWT; chưa có refresh/revoke/logout API | Mở lại app kiểm tra token; logout xóa token |
| F04 | Google Sign-In | **Chưa có** SDK/nút Google | Có `POST /auth/google`, xác minh Google ID token; cần `GOOGLE_CLIENT_ID` | Chọn tài khoản Google thực → JWT → hồ sơ |
| F05 | Hồ sơ và lịch sử điểm | Có xem, refresh, logout; chưa có form sửa | GET/PUT profile, `users`, `trust_score_logs` | Xem đúng tên/email/điểm; PUT cập nhật qua API |
| F06 | Khám phá, tìm kiếm, lọc địa điểm | **Chưa có FE** | GET places, keyword/category, loại địa điểm ẩn | Danh sách, trạng thái rỗng/lỗi, nhấn mở chi tiết |
| F07 | Chi tiết địa điểm, review | **Chưa có FE** | GET place detail và reviews | Truyền `placeId`; Back giữ kết quả tìm kiếm |
| F08 | Check-in GPS | **Chưa có FE/quyền vị trí** | Kiểm tra tọa độ, mock flag, Haversine, bán kính, tối đa 1 visit OPEN/user | Ngoài bán kính bị từ chối; hợp lệ tạo OPEN |
| F09 | Check-out, xác minh visit | **Chưa có FE** | Đồng hồ server, chủ sở hữu, OPEN → VERIFIED, cộng 2 điểm, log trong transaction | Gọi lần hai → 409; không cộng điểm lần hai |
| F10 | Lịch sử chuyến đi | **Chưa có FE** | GET history theo JWT user | Chỉ thấy visit của mình |
| F11 | Upload ảnh | **Chưa có FE** | Multipart JPEG/PNG/WebP ≤20 MiB, tên UUID, `/uploads/...` | Upload → mở được ảnh bằng host backend |
| F12 | Studio postcard nhiều lớp | **Chưa có FE** | Backend chỉ lưu file, không dựng lớp ảnh | Chọn ảnh/khung/chữ, sửa lớp, xuất ảnh, upload |
| F13 | Ảnh panorama/360 | **Chưa có FE** | Chỉ có URL và cờ boolean; không stitch/chuyển ảnh thành 360 | Cần chụp/xử lý/viewer thực, không chỉ bật cờ |
| F14 | Đăng review đã xác minh | **Chưa có FE** | Visit thuộc user/đúng place/VERIFIED; 1 review/user/place; 1–5 sao; cập nhật aggregate; +5 điểm | Chưa check-out bị chặn; đăng thành công cập nhật detail/profile |
| F15 | Locket feed và signal | **Chưa có FE** | Lưu signal, feed 20 mới nhất toàn hệ thống | Gửi ảnh → feed xuất hiện; hiện chưa lọc bạn bè |
| F16 | Nhận nền, widget màn hình chính | **Chưa có triển khai** | Có trường FCM token nhưng chưa có luồng gửi FCM | Phải kiểm chứng khi app background/killed; widget native Android |
| F17 | Menu ≥3 mục, ≥5 màn nghiệp vụ | **Chưa có** | Không áp dụng | Điều hướng thật, truyền/refresh dữ liệu qua các màn |

## 3. Đối chiếu yêu cầu giảng viên

| Yêu cầu | Kết luận từ mã nguồn | Việc còn thiếu |
|---|---|---|
| Danh sách tính năng và ai làm | Tài liệu này có tính năng; **chưa xác nhận ai đã làm** | Thành viên xác nhận phạm vi, commit và người trình bày |
| Mô tả API, dữ liệu, mapping UI | Đã soạn file 02/03 theo controller/DTO/SQL hiện tại | Cập nhật mapping khi có màn nghiệp vụ |
| Thiết kế DB local nếu có | Chưa có SQLite helper/schema hay luồng cache | Không kê khai đã dùng SQLite chỉ vì có `sqflite` trong pubspec |
| Đăng nhập/đăng xuất bằng Gmail, Profile | Email/mật khẩu + profile có FE; Google API có BE | Nếu yêu cầu là Google Sign-In thì chưa đạt; địa chỉ Gmail trong form không thay thế OAuth |
| Ít nhất 5 màn nghiệp vụ liên thông | Hiện 3 màn chính: login/register/profile | Login/register không nên tính là 5 màn nghiệp vụ du lịch |
| Menu ≥3 mục, layout, thông tin user | Layout auth/profile có code | Thêm menu Khám phá/Locket/Hồ sơ, header user và luồng nghiệp vụ |
| Một nghiệp vụ phức tạp có business rules | Có ở BE: GPS → VERIFIED → review → điểm | Đưa lên mobile, chạy trọn luồng và nhánh lỗi |
| Chuyển trang, quay lại, truyền state | AuthGate chuyển theo state; đăng ký hỗ trợ Back | Luồng điều hướng nghiệp vụ và invalidation chưa có |
| Git mới nhất, chốt branch demo | Xem file 06 | Branch snapshot không chứng minh đã đủ tính năng |
| Hướng dẫn dùng, demo rõ ràng | File 04/05 | Tập trên thiết bị thật, chuẩn bị máy chiếu và phản biện |

## 4. Phân công đề xuất — chưa xác nhận đóng góp thực tế

Tên thành viên theo ảnh. Không suy luận tác giả code từ email seed, tên tài khoản Git hoặc mô tả trong tài liệu cũ.

| Thành viên | Phần đề xuất phụ trách chính | Kết quả cần bàn giao | Phần cần hiểu để phản biện |
|---|---|---|---|
| Hầu Văn Hòa | Auth/session, GPS check-in/check-out, tích hợp FE–BE | Google Sign-In; màn GPS/history; kiểm tra 401 và quyền vị trí | JWT, secure storage, lifecycle, Haversine, transaction/lock |
| Phạm Hoàng Nam | Studio postcard, panorama, Locket/widget | Xuất ảnh nhiều lớp; viewer/capture 360 phù hợp; feed và nhận nền/widget | Xử lý ảnh, upload, RAM, FCM và Android widget |
| Vương Thu Huyền | Khám phá/chi tiết/review/profile, tài liệu và nghiệm thu | 3 màn khám phá/chi tiết/đăng review; sửa profile; kịch bản test | Mapping DTO/UI, debounce, pagination, state refresh, validation |

Mỗi người cần bổ sung: “đã làm” theo tính năng, đường dẫn file, commit SHA, kiểm tra đã chạy, phần trực tiếp demo. Các API chung do nhóm thống nhất contract trước khi tích hợp. Tất cả thành viên phải hiểu trọn luồng, không chỉ phần mình viết.

## 5. Thứ tự hoàn thiện đề xuất

1. Chốt cách hiểu “Gmail”: để đáp ứng đúng ảnh, ưu tiên Google Sign-In trên FE, giữ email/password nếu nhóm muốn.
2. Tạo navigation 3 mục và 5 màn nghiệp vụ: danh sách → chi tiết → GPS → studio → đăng review; giữ profile/history và Locket.
3. Tích hợp business rules, lỗi mạng/401, loading/empty, Back và refresh profile/detail sau thay đổi.
4. Làm ảnh nhiều lớp; làm rõ phạm vi panorama/360 và nhận nền/widget. Đánh dấu từng hạng mục chạy thật, không dùng dependency làm bằng chứng.
5. Kiểm tra thiết bị thật, chốt commit FE/BE đi cùng nhau, cập nhật tài liệu và chạy kịch bản demo trong file 04.
