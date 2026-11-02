# Hướng dẫn chạy, sử dụng và demo

## 1. Chuẩn bị môi trường

Cần JDK 21, PostgreSQL đã cấu hình, Flutter tương thích pubspec (Dart ^3.13.1), Android SDK và thiết bị/emulator. Chạy trong đúng thư mục để backend đọc `.env`. Không đưa `.env`, JWT, mật khẩu hoặc file dữ liệu cá nhân lên Git/máy chiếu.

### Backend

```powershell
Set-Location 'D:\FU\FA26\PRM393\Project\be\travel-trust-network-be'
# Đặt JAVA_HOME trỏ JDK 21 trên máy nếu chưa cấu hình.
# Chỉ copy khi chưa có .env, tránh ghi đè cấu hình hiện tại.
if (-not (Test-Path -LiteralPath '.env')) {
  Copy-Item -LiteralPath '.env.example' -Destination '.env'
}
```

Sửa `.env` tại máy: `TTN_DB_URL`, `TTN_DB_USERNAME`, `TTN_DB_PASSWORD` đúng PostgreSQL; `GOOGLE_CLIENT_ID` nếu dùng Google Sign-In. Không gõ mật khẩu vào lịch sử shell hay gửi vào chat. Chuẩn bị schema/migration theo file 03 và README backend, rồi:

```powershell
.\mvnw.cmd spring-boot:run
```

Mở `http://localhost:8080/swagger-ui/index.html` và thử GET `/api/v1/places`. Phải thấy response `success=true` trước khi mở app. Lỗi “password authentication failed” cần sửa cấu hình credentials đúng tài khoản DB; không tự reset password server.

### Flutter

```powershell
Set-Location 'D:\FU\FA26\PRM393\Project\fe'
flutter pub get
flutter devices
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1
```

Điện thoại thật: cùng mạng với backend; thay `10.0.2.2` bằng IP LAN máy, chọn device với `-d <device-id>`. Kiểm tra cổng 8080/firewall trên đúng mạng. Emulator `10.0.2.2` không dùng được trực tiếp trên điện thoại thật. Nếu đổi `dart-define`, chạy lại ứng dụng với giá trị mới.

HTTP local chỉ được cấu hình trong Android debug; release cần backend HTTPS. Không coi bản APK release HTTP thất bại là lỗi form đăng nhập.

## 2. Hướng dẫn dùng bản mobile hiện tại

1. Mở app: chờ kiểm tra phiên. Chưa có token → form đăng nhập.
2. Chọn “Chưa có tài khoản? Đăng ký”. Điền họ tên, email hợp lệ, mật khẩu 8–128 ký tự, xác nhận khớp. Đây là mật khẩu riêng của TTN; không phải mật khẩu tài khoản Google.
3. Đăng ký thành công tự mở “Hồ sơ của bạn”. Nếu email trùng, dùng tài khoản khác hoặc đăng nhập bằng mật khẩu đã tạo.
4. Hồ sơ hiện tên, email, avatar nếu có, bio nếu có, điểm uy tín, số chuyến đã xác minh và lịch sử điểm. Nhấn refresh hoặc kéo xuống để cập nhật.
5. Nhấn “Đăng xuất” → quay về đăng nhập. Đăng nhập lại bằng email/mật khẩu TTN. Đóng/mở lại app: token đã lưu được kiểm tra bằng API profile.
6. Sai mật khẩu → lỗi tại form. Lỗi mạng khi khôi phục → màn “Chưa thể khôi phục phiên”, có “Thử lại” và “Đăng xuất phiên đã lưu”. Lỗi mạng tạm thời không tự xóa token đã lưu.

Tài khoản seed và Google-only chưa có mật khẩu, không thể dùng form email/password để đăng nhập. Bản hiện tại chưa có chức năng quên mật khẩu, Google Sign-In trên mobile, khám phá/GPS/review/studio/Locket.

## 3. Kịch bản demo trung thực cho bản hiện tại (5–7 phút)

| Thời gian | Thao tác | Điều cần nói / bằng chứng |
|---|---|---|
| 0:00–0:40 | Giới thiệu đề tài, mở ma trận tính năng | Phân biệt phần mobile hoàn thành và phần API chưa tích hợp |
| 0:40–1:40 | Đăng ký tài khoản demo mới | Validate email, mật khẩu, confirm; thành công nhận JWT và hồ sơ |
| 1:40–2:30 | Xem hồ sơ, refresh | Điểm khởi tạo 50 với account mới, lịch sử điểm; dữ liệu từ backend |
| 2:30–3:20 | Đăng xuất, login sai rồi đúng | Sai → lỗi rõ, đúng → hồ sơ; không đọc token lên màn chiếu |
| 3:20–4:00 | Đóng/mở app | Khôi phục token, profile API xác minh phiên |
| 4:00–5:30 | Swagger minh họa places và business rules | Nói rõ đây là demo API, chưa phải luồng nghiệp vụ trên điện thoại |
| 5:30–7:00 | Mở file code theo câu hỏi | AuthGate, controller, Dio interceptor, storage, DTO và service |

Kịch bản này **không đủ để tuyên bố đạt toàn bộ yêu cầu môn học**. Chỉ demo API đã kiểm tra chạy được; nếu DB chưa kết nối, trình bày kết quả kiểm tra và phần bị chặn, không dùng ảnh/mock thay bằng chứng chạy thật.

## 4. Kịch bản nghiệp vụ mục tiêu sau khi hoàn thiện mobile

Google Sign-In → danh sách địa điểm → tìm/lọc → chi tiết → xin quyền vị trí → check-in → check-out → studio xuất ảnh → upload → review → chi tiết/profile/feed cập nhật.

Các điểm cần chứng minh:

- Ít nhất 5 màn nghiệp vụ và 3 menu hoạt động, Back hợp lý, state không mất ngoài ý muốn.
- Chặn check-in ngoài bán kính, fake flag, check-in khi đang OPEN, review chưa VERIFIED, review trùng.
- Check-out cộng đúng 2; review cộng đúng 5; không cộng lặp khi bấm lại; app đọc điểm server sau refresh.
- URL ảnh load được trên điện thoại, không dùng localhost của điện thoại để gọi máy tính.
- Postcard nhiều lớp và 360 phải có chức năng thật. Feed không tự đồng nghĩa FCM/background/widget; trình bày từng phần bằng bằng chứng riêng.

Để luyện business rules trên Swagger: đăng ký account demo mới, lấy JWT và Authorize; GET places để chọn ID/tọa độ; POST check-in; copy visitId; PUT check-out **không body**; POST review; GET profile/detail/feed. Tọa độ nhập tay trong Swagger chỉ kiểm tra rule server, không chứng minh thiết bị đã đo GPS thật.

## 5. Ma trận nghiệm thu tối thiểu

| Ca | Đầu vào/thao tác | Mong đợi |
|---|---|---|
| A01 | Register email mới, form hợp lệ | 200; JWT + profile; điểm khởi tạo/log |
| A02 | Register lại email, kể cả khác hoa/thường | 409 DUPLICATE_EMAIL |
| A03 | Login sai password | 401; lỗi hiện trên form |
| A04 | Mở app với token hợp lệ | Profile; GET kèm Bearer |
| A05 | Token hết hạn/sai ở profile | 401; xóa phiên, về login nếu xóa storage thành công |
| A06 | Mạng lỗi trong restore | Giữ token persisted, màn retry |
| A07 | Logout | Xóa storage, token RAM; login hiện lại |
| B01 | Place ẩn | Không nằm trong list; detail bị chặn |
| B02 | GPS ngoài radius / mocked=true | 400; không tạo OPEN |
| B03 | Check-in hợp lệ rồi check-in nữa | Lần đầu OPEN, lần sau 409 |
| B04 | Check-out visit user khác | 403 |
| B05 | Check-out đúng rồi gọi lại | VERIFIED/+2 một lần; lần hai 409 |
| B06 | Review trước check-out / sai place | 400 UNVERIFIED_VISIT |
| B07 | Review hợp lệ rồi lặp | +5 và aggregate cập nhật một lần; lần hai 409 |
| B08 | Upload file trống/không đúng signature | Bị từ chối; không tin tên file |
| B09 | Review có ảnh | Signal tự tạo; tránh gửi signal lần nữa gây trùng feed |
| U01 | Máy hẹp, xoay ngang, font lớn, tên dài | Không overflow, form cuộn/keyboard không che nút; cần kiểm tra thiết bị |

Không đánh dấu tất cả “pass” chỉ từ việc tồn tại test hoặc đọc code. Kết quả đã chạy được ghi ở file 06.

## 6. Tổ chức trình bày và Git

Trước lượt nhóm: ngồi bàn 1 hướng lên, kết nối máy chiếu và chiếu điện thoại, tắt thông báo cá nhân, mở sẵn app/backend/Swagger và file code. Nhóm lên ngay sau nhóm trước; chuẩn bị cáp, pin, mạng và phương án chiếu dự phòng. Cả nhóm tập ai thao tác, ai giải thích, ai trả lời API/dữ liệu.

Trước khi dùng branch demo: fetch, xác nhận SHA đúng hai repo và working tree sạch. Không thêm feature/chuyển dependency ngay sát buổi bảo vệ. Sau thay đổi cần kiểm tra lại và cập nhật mốc Git. Không force-push branch demo.

Lệnh kiểm tra:

```powershell
# Chạy ở từng repo:
git status --short --branch
git log -1 --oneline
git rev-parse HEAD
git ls-remote --heads origin demo/prm393-2026-11-02
```

Nếu branch demo đã tồn tại và đang có thay đổi chưa commit thì giữ nguyên, kiểm tra trước khi checkout; không reset/clean để ép sạch.
