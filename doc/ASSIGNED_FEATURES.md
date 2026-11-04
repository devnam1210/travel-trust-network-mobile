# Báo cáo phần Flutter được giao

Phạm vi: Google Sign-In, JWT/session, GPS Check-in, Check-out, Visit History và tích hợp API liên quan. Giữ Riverpod, Dio, Flutter Secure Storage; không thêm tầng Repository/UseCase. Không sửa backend, không commit/push, không triển khai Explore, Place Detail hay các tính năng của thành viên khác.

## Tệp mới

| Tệp | Nội dung |
| --- | --- |
| `lib/models/visit_model.dart` | Parse VisitResponse thực tế từ backend |
| `lib/services/visit_service.dart` | API Visit và Riverpod provider lịch sử theo phiên |
| `lib/services/location_service.dart` | Kiểm tra GPS/quyền, lấy vị trí hiện tại với giới hạn 20 giây |
| `lib/views/visits/visit_screen.dart` | Check-in, Check-out, xác nhận lại trạng thái |
| `lib/views/visits/visit_history_screen.dart` | Loading, empty/error/retry, refresh, tiếp tục OPEN visit |
| `lib/views/visits/visit_summary.dart` | Hiển thị thông tin Visit dùng chung cho hai màn |
| `test/google_auth_test.dart` | Google token exchange, hủy, lỗi, lưu JWT backend |
| `test/location_service_test.dart` | Mock API thiết bị để kiểm tra quyền/GPS/mock flag |
| `test/visit_service_test.dart` | Payload, bodyless PUT, history array, lỗi nghiệp vụ/timeout |
| `test/visit_flow_test.dart` | Luồng giao diện, timeout/reconcile, refresh, 401 và bấm lặp |
| `test/support/visit_fakes.dart` | Dữ liệu Visit giả lập cho test |
| `doc/ASSIGNED_FEATURES.md` | Báo cáo và hướng dẫn cấu hình |

## Tệp sửa

- `pubspec.yaml`, `pubspec.lock`: thêm `google_sign_in ^7.2.0` và dependency phụ của SDK; giữ các phiên bản thư viện đã có.
- `lib/config/app_config.dart`: thêm `GOOGLE_SERVER_CLIENT_ID`, `TEST_PLACE_ID`; giữ `API_BASE_URL`.
- `lib/services/auth_service.dart`: SDK Google, kiểm tra ID token, exchange JWT và thông báo backend thiếu cấu hình.
- `lib/controllers/auth_controller.dart`: tái sử dụng luồng lưu session cho Google, xử lý Visit 401, chặn phản hồi profile đến muộn khôi phục phiên đã hết hạn.
- `lib/services/api_service.dart`: GET danh sách, POST JSON, PUT không body, giữ code/message/status, đánh dấu lỗi kết nối có kết quả chưa xác định; xử lý 401 Visit theo JWT của request.
- `lib/views/auth/widgets/auth_screen.dart`: nút Đăng nhập với Google trên form đăng nhập.
- `lib/views/auth/auth_gate.dart`: đóng các route đang mở khi phiên hết hạn hoặc đăng xuất.
- `lib/views/profile_screen.dart`: lối vào lịch sử và nút kiểm thử GPS khi có cấu hình debug; không thêm chức năng sửa hồ sơ.
- `android/app/src/main/AndroidManifest.xml`: quyền vị trí gần đúng/chính xác khi dùng app.
- `test/auth_controller_test.dart`, `test/support/auth_fakes.dart`: test 401 đồng thời, phản hồi đến muộn, restore lỗi mạng và hỗ trợ envelope danh sách.
- `README.md`: cập nhật phạm vi và liên kết báo cáo.

## Luồng xử lý

1. **Google Sign-In:** nhấn nút → SDK Android mở chọn tài khoản → lấy `account.authentication.idToken` → gửi email/tên/avatar thực từ SDK và ID token tới `/auth/google` → nhận JWT riêng và `userProfile` → lưu Secure Storage → gán Dio → cập nhật AuthState → AuthGate hiện hồ sơ. Chỉ JWT backend được lưu. Hủy chọn trở về form, không gọi backend. ID token rỗng, SDK lỗi, mất mạng, backend 401 hoặc thiếu GOOGLE_CLIENT_ID đều có xử lý. Khi Google không có displayName, dùng email của chính tài khoản làm tên để đáp ứng DTO NotBlank.
2. **Session:** login/register/Google dùng chung `_authenticate`, khóa thao tác khi đang xử lý. Khởi động đọc JWT và gọi profile; 401 hoặc user không còn tồn tại thì xóa phiên. Lỗi mạng/server giữ JWT trong Secure Storage, hiện Retry. Logout xóa Secure Storage và token RAM/Dio, cập nhật signedOut. Nếu storage không xóa được, hiện lỗi để thử lại. Mọi API Visit dùng cùng cơ chế 401; các phản hồi 401 đồng thời chỉ xóa phiên một lần. HTTP 403 giữ phiên và hiển thị lỗi quyền. Không thêm refresh token, revoke hay API logout.
3. **Check-in:** VisitScreen nhận `placeId` → kiểm tra dịch vụ vị trí → kiểm tra/xin quyền → lấy vị trí hiện tại, accuracy nếu thiết bị có cung cấp, `isMocked` từ SDK → POST → giữ Visit trả về (id/status/thời gian/khoảng cách). Backend kiểm tra bán kính, mock flag và một OPEN visit. Flutter hiển thị nguyên message/code nghiệp vụ, không tự xác minh khoảng cách.
4. **Check-out:** nhận `visitId` và tải lại Visit từ history của chính user để xác nhận trạng thái. Chỉ OPEN đã xác nhận mới có nút Check-out. PUT không body, không gửi GPS → hiển thị status/time từ response → làm mới history và profile để đọc điểm từ backend. Không tự cộng điểm. Khi timeout/mất phản hồi, ẩn nút gửi lại và yêu cầu tải trạng thái hoặc mở history. `ALREADY_CHECKED_OUT` cũng yêu cầu tải lại trước khi thao tác tiếp.
5. **History:** GET history không truyền userId → parse `data` array → hiển thị tên/ảnh/thời gian/status/khoảng cách/lý do từ chối nếu có. Có loading, empty, error, retry và pull-to-refresh. Nhấn OPEN để tiếp tục Check-out. Mutation thành công invalidate provider, nên danh sách được cập nhật khi quay về. Dữ liệu provider tách theo user đang đăng nhập và tự giải phóng khi không còn sử dụng.

Nếu Check-in bị mất phản hồi, tải lại trạng thái tìm OPEN visit hiện có, kể cả tại địa điểm khác (trường hợp SINGLE_OPEN_VISIT). Không tự gửi lại mutation khi chưa xác nhận qua history.

## API đã tích hợp

Base URL gồm `/api/v1`. ApiService giữ envelope `success/code/message/data/timestamp` của backend.

| Method | Path tương đối | Dữ liệu |
| --- | --- | --- |
| POST | `/auth/register` | email, fullName, password (đã có) |
| POST | `/auth/login` | email, password (đã có) |
| POST | `/auth/google` | email, fullName, idToken, avatarUrl, fcmToken=null |
| GET | `/users/me/profile` | Bearer JWT; restore/refresh điểm thật |
| POST | `/visits/check-in` | placeId, userLat, userLng, gpsAccuracy, isMocked |
| PUT | `/visits/{visitId}/check-out` | Bearer JWT, không có body |
| GET | `/visits/my-history` | Bearer JWT, không có userId/query |

VisitModel đọc `id` (không phải `visitId`), `placeId`, `placeName`, `placeImageUrl`, `checkInTime`, `checkOutTime`, `status`, `distanceMeters`, `rejectionReason` từ VisitResponse Java. Không sửa API contract/business rules. Ảnh tùy chọn hỗ trợ URL tuyệt đối và đường dẫn `/uploads/...`.

## Dependency và Google OAuth

Chỉ thêm dependency trực tiếp `google_sign_in ^7.2.0` để mở SDK tài khoản Google thật. GPS tiếp tục dùng `geolocator` đã có, không thêm thư viện xin quyền khác. Không cần Firebase Authentication hay client secret cho luồng này.

1. Trong Google Cloud Console, chọn một project, cấu hình OAuth consent screen; nếu ứng dụng ở chế độ Testing, thêm tài khoản thử nghiệm vào test users.
2. Tạo **OAuth client Android**, nhập đúng package `com.example.travel_trust_network_mobile` và SHA-1 của khóa ký bản đang chạy. Nếu đổi applicationId, cần đăng ký lại package đúng.
3. Xem SHA-1 debug trên Windows:

   ```powershell
   keytool -list -v -alias androiddebugkey -keystore "$env:USERPROFILE\.android\debug.keystore" -storepass android -keypass android
   ```

   Hoặc chạy `./gradlew signingReport` trong `android` khi SDK/Gradle đã hoạt động. Bản release cần OAuth Android client khớp SHA-1 khóa release.
4. Trong cùng project, tạo **OAuth client loại Web application**. Giá trị Web Client ID dạng `...apps.googleusercontent.com` là `GOOGLE_SERVER_CLIENT_ID` cho Flutter và đồng thời là `GOOGLE_CLIENT_ID` cho backend. Không truyền Android Client ID vào tham số serverClientId.
5. Cấu hình biến môi trường cho tiến trình backend rồi khởi động lại; chỉ ghi `.env` chưa đảm bảo IDE/Maven tự đọc file đó:

   ```powershell
   $env:GOOGLE_CLIENT_ID = '<WEB_CLIENT_ID>'
   ./mvnw spring-boot:run
   ```

6. Truyền cùng Web Client ID vào lệnh flutter run phía dưới. Không đặt client secret trong app. Cách này truyền serverClientId trực tiếp nên không cần thêm google-services.json hoặc plugin Google Services chỉ để đăng nhập Google.

SDK v7 dùng singleton và `initialize()` một lần trước `authenticate()`. Trên Android, một số lỗi cấu hình cũng bị SDK báo là canceled; nếu vừa chọn tài khoản xong bị đóng mà không đăng nhập, kiểm tra lại package/SHA-1/Web Client ID. Xem [hướng dẫn chính thức google_sign_in Android](https://pub.dev/packages/google_sign_in_android) và [migration SDK v7](https://github.com/flutter/packages/blob/main/packages/google_sign_in/google_sign_in/MIGRATION.md).

## GPS và cách mở màn hình

Manifest đã có `ACCESS_COARSE_LOCATION` và `ACCESS_FINE_LOCATION`. Không xin quyền vị trí nền. Người dùng cần bật Location và cấp quyền khi dùng app; để xác minh khoảng cách nhỏ nên chọn vị trí chính xác. Từ chối quyền có thể bấm Check-in lại để xin quyền; từ chối vĩnh viễn có nút mở app settings; GPS tắt có nút mở location settings. Quay lại app rồi bấm Check-in để thử lại. Không theo dõi GPS liên tục và không lấy GPS khi Check-out.

Geolocator cung cấp mock indicator của nền tảng. `false` chỉ có nghĩa thiết bị không báo mocked, không đảm bảo vị trí là thật; không thể chống mọi dạng giả GPS/root. Emulator có thể báo mock location và bị backend từ chối, cần dùng thiết bị thật để kiểm thử thành công trong trường hợp đó. Xem [tài liệu geolocator](https://pub.dev/packages/geolocator).

Màn của thành viên khác có thể mở trực tiếp:

```dart
Navigator.of(context).push(MaterialPageRoute<void>(
  builder: (_) => VisitScreen(placeId: selectedPlaceId),
));

Navigator.of(context).push(MaterialPageRoute<void>(
  builder: (_) => VisitScreen(placeId: visit.placeId, visitId: visit.id),
));
```

Nếu chưa có Explore, truyền `TEST_PLACE_ID` từ dữ liệu kiểm thử hiện có của backend. Lấy UUID từ Swagger (`GET /api/v1/places`) hoặc database phát triển, không hardcode UUID production. Nút kiểm thử trên hồ sơ chỉ xuất hiện khi debug và TEST_PLACE_ID có giá trị. History luôn có lối vào từ hồ sơ. Không xây dựng Explore/PlaceDetail.

## Chạy trên Android Emulator

Khởi động database/backend theo README backend trước. Emulator dùng image có Google Play/Google APIs và tài khoản Google, bật GPS; Extended Controls → Location có thể đặt vị trí kiểm thử gần tọa độ place trong database (backend vẫn có thể từ chối mock).

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1 --dart-define=GOOGLE_SERVER_CLIENT_ID=<WEB_CLIENT_ID> --dart-define=TEST_PLACE_ID=<UUID_TEST_PLACE>
```

Thay các placeholder bằng giá trị của bạn, không nhập nguyên dấu `< >`. `TEST_PLACE_ID` không bắt buộc cho đăng nhập/history hoặc khi màn khác đã truyền placeId.

Điện thoại thật dùng `--dart-define=API_BASE_URL=http://<LAN_IP>:8080/api/v1`, cùng mạng với máy backend và mở firewall cổng 8080. HTTP local đã được cho phép ở debug qua network_security_config; release dùng HTTPS.

## Kiểm tra và giới hạn

Kết quả kiểm tra được ghi nhận trên Windows ngày 04/11/2026, Flutter 3.47.3 / Dart 3.13.3. Test HTTP/native channel dùng giả lập; không khẳng định đã đăng nhập Google thật hoặc đo GPS thiết bị thật.

Pub cache mặc định ban đầu có file chứa byte NUL, làm pub solver báo sai rằng geolocator không tồn tại và analyzer không đọc được các thư viện. Đã tải lại toàn bộ dependency vào cache riêng bằng lệnh dưới, giữ nguyên phiên bản dependency hiện có:

```powershell
$env:PUB_CACHE = Join-Path $env:TEMP 'ttn-feature-verification\pub-cache'
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

| Lệnh | Kết quả |
| --- | --- |
| `flutter pub get` với cache sạch | PASS; chỉ thêm SDK Google và 5 dependency phụ vào lockfile |
| `flutter analyze` | PASS — No issues found |
| `flutter test` | PASS — 57/57 test, gồm test cũ và test mới |
| `flutter build apk --debug` | FAIL do Android SDK package.xml không hợp lệ: XML `Content is not allowed in prolog` khi Gradle xác định compileDebugJavaWithJavac |

Các package.xml bị lỗi nằm trong Android SDK hiện có: build-tools/36.0.0, cmdline-tools/latest, emulator, NDK/28.2.13676358, platform-tools, platforms/android-34/35/36/37.0 và system-images/android-37.0/google_apis_playstore/x86_64. Cần sửa/cài lại các thành phần SDK này bằng Android Studio SDK Manager trước khi build lại. Chưa sửa/cài lại Android SDK của máy trong phạm vi thay đổi repo. Gradle cũng cảnh báo các plugin hiện có dchs_motion_sensors/firebase_core/home_widget cần chuyển sang Built-in Kotlin ở phiên bản Flutter tương lai; không đổi các tính năng ngoài phạm vi để xử lý cảnh báo này.

Các ca đã mô phỏng bằng test: JWT đúng/sai/mất mạng, logout, Google thành công/hủy/backend 401/ID token rỗng/backend thiếu cấu hình/mất mạng, quyền GPS bị từ chối/vĩnh viễn/GPS tắt, tọa độ và mock flag, mọi code lỗi Visit yêu cầu, history array/rỗng/lỗi/refresh, tiếp tục OPEN visit, Check-out timeout rồi xác nhận VERIFIED, bấm lặp không gửi trùng, Visit 401 đóng route và không khôi phục phiên bằng phản hồi profile đến muộn.

Cần kiểm thử thủ công sau khi cấu hình OAuth và sửa SDK: chọn tài khoản Google thật/hủy/sai audience; đăng nhập lại sau tắt mở app; GPS trong/ngoài bán kính; quyền gần đúng/chính xác; GPS bị tắt giữa lúc lấy vị trí; mock GPS; SINGLE_OPEN_VISIT; Check-out lần hai/visit người khác; timeout khi backend thật đã xử lý; history ảnh thực tế. Chưa có OAuth Client ID của dự án và chưa chạy trên thiết bị/emulator thật, nên các ca này chưa được xác nhận end-to-end.

Backend trả LocalDateTime không kèm múi giờ. UI hiển thị thời gian server cung cấp (đổi sang local khi response có offset), không tự suy đoán UTC; server và thiết bị nên có cấu hình múi giờ thống nhất. API history hiện không phân trang; client giữ đúng contract hiện có.
