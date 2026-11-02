# Kết quả kiểm tra và mốc Git

Ngày kiểm tra: **02/11/2026**, múi giờ Asia/Bangkok.

## 1. Code dùng để rà soát

| Repo | Commit code đầu vào | Trạng thái đồng bộ trước khi thêm tài liệu |
|---|---|---|
| Mobile | `4a24e33` | Fetch thành công; HEAD và origin/main không chênh lệch |
| Backend | `ebc296b` | Local ban đầu `2131be5`, chậm 2 commit; đã fast-forward tới origin/main |

Hai commit backend mới gồm `ac7f0fd` (API email/password) và `ebc296b` (tài liệu auth/migration). Vì vậy kết luận ban đầu rằng backend thiếu email/password đã được thay thế sau khi cập nhật mã nguồn.

Branch mốc được chọn cho cả hai repo: **`demo/prm393-2026-11-02`**. Branch lưu code hiện có + bộ tài liệu, **không có nghĩa đã hoàn thiện toàn bộ chức năng môn học**. SHA commit tài liệu xem bằng `git log -1 --oneline`; xác nhận bản remote bằng `git ls-remote --heads origin demo/prm393-2026-11-02`. Trạng thái push cuối cùng được báo trong bàn giao sau khi chạy lệnh và đối chiếu SHA, không suy từ tên branch.

## 2. Backend — đã chạy

Lệnh tại repo backend, sử dụng JDK Microsoft **21.0.12** và Maven wrapper **3.9.9**:

```powershell
.\mvnw.cmd -B test
```

- Main compile và test compile: **thành công**.
- Kết quả mới nhất sau cập nhật cấu hình và tạo schema: **37 test pass, 0 failure, 0 error, 0 skipped — BUILD SUCCESS**.
- Đã kiểm chứng kết nối PostgreSQL, Spring application context và HTTP integration test: đăng ký, email trùng, đăng nhập sai/đúng, đọc profile bằng JWT và validate đầu vào.
- Lượt đầu có 34 test pass, 3 error do sai thông tin đăng nhập DB (`28P01`). Sau khi người dùng sửa `.env`, kết nối thành công nhưng báo `relation "users" does not exist`.
- Kiểm tra xác nhận database **local `ttn_db`, schema `public`, chưa có bảng người dùng nào**. Đã chạy script có sẵn `doc/03_create_schema.sql` để tạo 6 bảng, sau đó chạy lại toàn bộ test thành công. Không thay đổi/reset mật khẩu, không sửa `.env`, không xóa dữ liệu cũ.

| Suite | Tests | Errors | Failures |
|---|---:|---:|---:|
| JwtTokenProviderTests | 2 | 0 | 0 |
| HaversineDistanceUtilTests | 1 | 0 | 0 |
| AuthServiceImplTests | 3 | 0 | 0 |
| EmailPasswordAuthServiceTests | 5 | 0 | 0 |
| MediaStorageServiceImplTests | 2 | 0 | 0 |
| PlaceServiceImplTests | 3 | 0 | 0 |
| ReviewServiceImplTests | 7 | 0 | 0 |
| VisitServiceImplTests | 11 | 0 | 0 |
| EmailPasswordAuthHttpTests | 2 | 0 | 0 |
| TravelTrustNetworkBeApplicationTests | 1 | 0 | 0 |

Nguồn kết quả: `target/surefire-reports/TEST-*.xml` sau lượt chạy mới nhất. Không commit toàn bộ log test vì có thể chứa cấu hình môi trường. Kiểm tra Git xác nhận `.env` vẫn được ignore. Test HTTP dùng MockMvc và PostgreSQL thật; chưa kiểm chứng server HTTP riêng đang lắng nghe cổng 8080, runtime Swagger, lock đồng thời dưới tải hay luồng điện thoại thật.

Khi chuyển sang máy khác: cấu hình `.env` tại máy và tạo schema/migration trước khi chạy backend. `.env` không được đưa lên Git nên checkout branch không tự thiết lập database. Không gửi mật khẩu vào chat hoặc commit `.env`.

## 3. Frontend

Đã gọi `flutter analyze`, dự kiến chỉ chạy `flutter test` sau khi analyzer thành công. Flutter chưa tới bước analyzer: dừng lâu ở `Resolving dependencies... / Downloading packages...`; đã dừng lượt chạy đó. Do vậy chưa có kết quả analyze/test/APK để xác nhận pass.

Chạy tiếp `flutter pub get --offline`: **thất bại**, vì package `flutter_cube` (dependency của `panorama_viewer`) chưa có trong cache. Điều này xác nhận cache local chưa đủ; không chứng minh package không tồn tại trên server. Cần tải đủ bằng `flutter pub get` khi kết nối package registry hoạt động, sau đó chạy `flutter analyze`, `flutter test`, `flutter build apk --debug`. Không sửa/xóa dependency nghiệp vụ chỉ để bỏ qua kiểm tra.

## 4. Phạm vi kiểm chứng tài liệu

- API đối chiếu với controller/DTO/service thực tế sau fetch, gồm 14 method + route; phân biệt input, business rule và response envelope.
- Dữ liệu đối chiếu `doc/03_create_schema.sql`, `doc/05_add_password_auth.sql`, entity và seed.
- Mapping FE đối chiếu `lib/main.dart`, AuthGate, AuthScreen, ProfileScreen, AuthController, ApiService, AuthService, TokenStorage và models.
- Danh sách màn còn thiếu dựa trên file Dart hiện có, không dựa vào dependency trong pubspec.
- Phân công là đề xuất; chưa có xác nhận đóng góp thực tế của từng thành viên.

## 5. Điều kiện để chốt bản đạt yêu cầu

1. **Đã hoàn tất trên máy hiện tại:** kết nối DB, tạo schema và chạy lại 37 test backend thành công. Cần cấu hình riêng khi đổi máy.
2. Hoàn tất dependency, analyzer/test, build APK, thử trên điện thoại/máy chiếu.
3. Thêm Google Sign-In, menu ≥3 mục và ≥5 màn nghiệp vụ liên thông; tích hợp GPS/review/media theo ma trận tính năng.
4. Thực hiện đúng phạm vi ảnh 360, postcard nhiều lớp, nhận nền và widget nếu nhóm cam kết những phần đó.
5. Xác nhận phân công thực tế, ghi cặp SHA FE/BE, kiểm tra remote branch và working tree sạch trước buổi demo.
