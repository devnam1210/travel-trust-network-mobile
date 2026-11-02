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

- Main compile: **thành công**, 67 source file.
- Test compile: **thành công**, 10 source file.
- Tổng: **37 test, 0 assertion failure, 3 error, 0 skipped**. Lệnh kết thúc **BUILD FAILURE**.
- **34 test pass**, gồm JWT, Haversine, auth service Google/email-password, media, place, review và visit service.
- **3 test error**: `TravelTrustNetworkBeApplicationTests.contextLoads` (1) và `EmailPasswordAuthHttpTests` (2).
- Nguyên nhân context không khởi tạo: PostgreSQL báo **`password authentication failed for user "ttn_local_app"`**, SQLState `28P01`. Đây là lỗi cấu hình kết nối DB, không phải 3 assertion nghiệp vụ thất bại.

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
| EmailPasswordAuthHttpTests | 2 | 2 | 0 |
| TravelTrustNetworkBeApplicationTests | 1 | 1 | 0 |

Nguồn kết quả: `target/surefire-reports/TEST-*.xml`. Không commit toàn bộ log test vì có thể chứa cấu hình môi trường. Chưa kiểm chứng đầy đủ tích hợp PostgreSQL/HTTP, lock đồng thời, runtime Swagger hay luồng điện thoại thật. Không chỉnh/reset mật khẩu database để ép test pass.

Cách xử lý: cập nhật credentials đúng trong `.env` tại máy, bảo đảm schema/migration đã áp dụng; chạy lại toàn bộ `mvnw.cmd -B test`. Không gửi mật khẩu vào chat hoặc commit `.env`.

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

1. Xử lý kết nối DB và chạy lại test tích hợp.
2. Hoàn tất dependency, analyzer/test, build APK, thử trên điện thoại/máy chiếu.
3. Thêm Google Sign-In, menu ≥3 mục và ≥5 màn nghiệp vụ liên thông; tích hợp GPS/review/media theo ma trận tính năng.
4. Thực hiện đúng phạm vi ảnh 360, postcard nhiều lớp, nhận nền và widget nếu nhóm cam kết những phần đó.
5. Xác nhận phân công thực tế, ghi cặp SHA FE/BE, kiểm tra remote branch và working tree sạch trước buổi demo.
