# Thông báo bạn bè và tin nhắn

Ứng dụng nhận thông báo ngay khi có **lời mời kết bạn mới** hoặc **tin nhắn mới**:

- Khi đang mở app: backend gửi sự kiện qua SSE có JWT. App hiện thông báo kèm nút **Xem**, cập nhật lời mời, hộp thư và cuộc chat đang mở.
- Trong Locket có biểu tượng chuông, số chưa đọc và lịch sử thông báo. Bấm thông báo mở **Lời mời nhận** hoặc đúng cuộc chat.
- Khi chạy nền hoặc đóng app: backend gửi FCM notification + data, hệ điều hành hiện thông báo. Cần cấu hình Firebase bên dưới.
- Lời mời gửi lại hoặc tin nhắn gửi lại với cùng `clientMessageId` không tạo thông báo trùng. SSE và FCM dùng chung ID để tránh báo hai lần trong app.
- Thông báo chỉ gửi cho người nhận. Thông báo tin nhắn không chứa nội dung tin nhắn hoặc ảnh riêng tư.

## Chạy phần realtime trong app

Trong thư mục backend `travel-trust-network-be`:

```powershell
docker compose up -d --wait
```

Docker tự chạy migration `08_social_notifications.sql`, giữ lại dữ liệu đã có. Sau đó khởi động lại Spring Boot. Docker Compose hiện chạy PostgreSQL; phần Java vẫn cần khởi động lại riêng.

Trong thư mục mobile:

```powershell
flutter run
```

Cần build/chạy lại ứng dụng vì có thay đổi Android manifest, channel thông báo và Gradle. Hai tài khoản khác nhau, hai máy/emulator đều truy cập được cùng backend.

## Bật thông báo khi chạy nền hoặc đóng app

Dự án chưa có Firebase project, nên phần push chưa thể gửi thật. Không cần Firebase để sử dụng realtime và lịch sử thông báo trong app.

1. Mở [Firebase Console](https://console.firebase.google.com/), tạo project và thêm ứng dụng **Android** với package:

   ```text
   com.example.travel_trust_network_mobile
   ```

2. Tải `google-services.json` vào:

   ```text
   android/app/google-services.json
   ```

   Gradle đã tự áp dụng Google Services khi file này có mặt. Không thay package name trong file bằng tay.

3. Trong Firebase Project settings → Service accounts → Firebase Admin SDK, tạo private key cho backend. Lưu ngoài mobile, ví dụ:

   ```text
   D:/Ky8/PRM392/project/travel-trust-network-be/secrets/firebase-service-account.json
   ```

   Bật **Firebase Cloud Messaging API (HTTP v1)** cho cùng project. Service account cần quyền gửi Cloud Messaging. Không đưa private key này vào Flutter hoặc Git.

4. Thêm vào `.env` trong backend (Java properties, dùng dấu `/` cho đường dẫn Windows):

   ```properties
   TTN_FIREBASE_CREDENTIALS=D:/Ky8/PRM392/project/travel-trust-network-be/secrets/firebase-service-account.json
   ```

5. Khởi động lại Spring Boot và chạy lại `flutter run`. Đăng nhập, cho phép thông báo khi Android hỏi. App đăng ký địa chỉ thiết bị tự động. Phiên bản `firebase_messaging` 17 sử dụng `register()` / `onRegistered` và FID; backend gửi HTTP v1 qua trường `fid`.

6. Dùng tài khoản A gửi kết bạn cho B. Đưa app B về màn hình chính của điện thoại rồi kiểm tra thông báo; bấm để mở lời mời nhận. Sau khi kết bạn, gửi tin nhắn và kiểm tra thông báo mở đúng cuộc chat. Thử thêm trường hợp đóng app bình thường rồi bấm thông báo để mở lại.

Trên Android, **Force stop** trong Settings sẽ chặn FCM cho đến khi mở app lại. Emulator cần Google Play services và kết nối Internet. Quyền thông báo và cài đặt pin của thiết bị có thể ảnh hưởng việc hiển thị. Tham khảo [Firebase: nhận thông báo Flutter](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages).

Repository hiện có nền tảng Android. Nếu bổ sung iOS sau này, cần tạo target iOS, cấu hình Firebase/APNs và capability Push Notifications trước khi kiểm tra trên iPhone.

## Vòng đời và độ tin cậy

- Một địa chỉ FID chỉ thuộc một tài khoản tại một thời điểm; đăng nhập tài khoản khác cập nhật chủ sở hữu. Khi đăng xuất, app hủy đăng ký backend và Firebase; khi JWT hết hạn, app hủy đăng ký Firebase. Các thao tác mạng này được thực hiện theo thứ tự để tránh đăng ký muộn sau đăng xuất.
- SSE dừng khi app chạy nền/đăng xuất, kết nối lại khi trở về app, có heartbeat và tự thử lại khi mất mạng. Kết nối được tạo lại ít nhất mỗi phút để xác thực JWT lại.
- Sự kiện và thao tác gửi kết bạn/tin nhắn được lưu cùng transaction. SSE chỉ gửi sau commit. Rollback không để lại thông báo.
- FCM chạy qua outbox trong database, không làm chậm thao tác gửi. Lỗi mạng được thử lại tối đa 5 lần, với thời gian chờ tăng dần. Thiết bị bị FCM xác nhận `UNREGISTERED` được loại bỏ. Thông báo đã đọc hoặc quá 24 giờ được giữ trong lịch sử nhưng không gửi push muộn.
- Push có thể giao lại; thông báo hệ điều hành dùng tag theo ID để gộp cùng một sự kiện. Khi mở lại app, chuông và lịch sử tải dữ liệu từ backend.
- SSE hiện dùng các kết nối của một Spring Boot instance. Nếu triển khai nhiều instance, cần thêm cơ chế chuyển sự kiện giữa các instance (ví dụ Redis pub/sub).

## API

Tất cả endpoint yêu cầu `Authorization: Bearer <JWT>`; người nhận lấy từ JWT:

| Phương thức | Endpoint | Chức năng |
| --- | --- | --- |
| GET | `/api/v1/notifications?size=30&before=<id>` | Lịch sử mới nhất trước, phân trang theo ID |
| GET | `/api/v1/notifications/unread-count` | Số chưa đọc |
| PUT | `/api/v1/notifications/{id}/read` | Đánh dấu đã đọc, chỉ cho chủ sở hữu |
| GET | `/api/v1/notifications/stream` | SSE `ready`, `notification`, `heartbeat` |
| PUT | `/api/v1/notifications/devices` | Đăng ký FID, JSON `{"token":"<FID>"}` |
| DELETE | `/api/v1/notifications/devices` | Bỏ đăng ký FID, cùng JSON body |

Các key/token bí mật không nằm trong URL hoặc log.

## Kiểm tra

```powershell
flutter analyze --no-pub
flutter test --no-pub
```

Backend có test PostgreSQL tạm qua `scripts/test-locket-friends.ps1` và migration Docker trên project/volume riêng qua `scripts/test-docker-migrations.ps1`. Không dùng database ứng dụng để chạy test. Test FCM giả lập kiểm tra payload, retry, chủ sở hữu thiết bị, điều hướng và loại trùng; gửi push thật cần hoàn thành cấu hình Firebase ở trên.

Đã xác nhận trong lần triển khai này:

- Analyzer không có lỗi; **131 test Flutter** đạt.
- **70 test backend** đạt, gồm SSE qua HTTP/TCP thực nhận sự kiện trong thời hạn 3 giây sau thao tác kết bạn.
- Migration Docker đạt trên database cũ, database mới và qua nhiều lần khởi động, giữ nguyên tài khoản/tin nhắn đã có.
- `flutter build apk --debug --no-pub` thành công, APK ở `build/app/outputs/flutter-apk/app-debug.apk`.
- Chưa kiểm tra gửi FCM thật vì chưa có Firebase project/cấu hình thiết bị.

Khi kiểm tra APK, các JAR SDK Android 34/35/36 trên máy bị hỏng đã được thay bằng đúng revision từ kho Google, có kiểm checksum và giữ nguyên bản cũ. Bản sao lưu nằm trong `%TEMP%/ttn-sdk-verification-yiikoup1/original-sdk` (34), `%TEMP%/ttn-sdk-verification-f6b_fcwy/original-sdk` (35) và `%TEMP%/ttn-sdk-verification-o4k4blp8/original-sdk` (36). Không thay SDK Android 37.
