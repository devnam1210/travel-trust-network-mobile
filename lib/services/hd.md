# HƯỚNG DẪN & TÀI LIỆU PACKAGE: `lib/services/`

---

## 1. Tổng quan & Mục đích của Package
Package `services/` là **Tầng xử lý dữ liệu nền, Phần cứng & Tích hợp hệ thống (Infrastructure & Hardware Services Layer)** trong kiến trúc 4 tầng:
> **Views** $\rightarrow$ **Controllers** $\rightarrow$ **Services** $\rightarrow$ **Models**

### Mục đích chính:
- **Giao tiếp tầng mạng (Networking):** Kết nối trực tiếp với hệ sinh thái Java Microservices thông qua REST API, quản lý phiên làm việc JWT và tự động làm mới mã xác thực (Refresh Token).
- **Quản lý dữ liệu cục bộ (Local Database - Yêu cầu 1):** Khởi tạo, bảo trì và thao tác CRUD trên 3 bảng SQLite Local bằng `sqflite` phục vụ chế độ làm việc ngoại tuyến (Offline Mode) và lưu trữ dữ liệu Widget.
- **Tương tác phần cứng & Cảm biến (Hardware & Sensors):** Lấy vị trí GPS chính xác, phát hiện giả mạo vị trí (Anti-Fake GPS), tính toán khoảng cách địa lý theo thuật toán Haversine.
- **Xử lý đồ họa nặng & Đa luồng (Background Processing & Isolates):** Thực hiện xuất ảnh Postcard từ `RenderRepaintBoundary` và xử lý ghép chuỗi ảnh / Panorama 360° trên luồng phụ (`Isolate.run`) nhằm tránh giật khung hình (frame drop) trên UI chính.
- **Tích hợp tiện ích ngoài màn hình chính (Locket Widget Clone):** Lắng nghe tín hiệu ngầm từ Firebase Cloud Messaging (FCM) ngay cả khi ứng dụng đã tắt, tự động tải ảnh và đồng bộ giao diện Widget ngoài Launcher thông qua `HomeWidget`.
- **Nguyên tắc thiết kế:** Không chứa logic giao diện (`Widget`), không phụ thuộc vào `BuildContext` để có thể tái sử dụng tối đa và dễ dàng viết Unit Test độc lập.

---

## 2. Danh mục các file trong Package

| STT | Tên file | Mục đích & Công nghệ tích hợp |
|:---:|:---|:---|
| 1 | [`api_service.dart`](file:///d:/FALL26/PRM393/travel_trust_network_mobile/lib/services/api_service.dart) | Quản lý HTTP Client (`Dio`), tự động đính kèm JWT Bearer Token và Interceptor xử lý lỗi 401 Refresh Token. |
| 2 | [`local_db_service.dart`](file:///d:/FALL26/PRM393/travel_trust_network_mobile/lib/services/local_db_service.dart) | Khởi tạo SQLite và quản lý 3 bảng: `cached_places`, `draft_visits`, `locket_history` (Đáp ứng Yêu cầu 1). |
| 3 | [`gps_service.dart`](file:///d:/FALL26/PRM393/travel_trust_network_mobile/lib/services/gps_service.dart) | Xin quyền vị trí, lấy GPS, chặn Mock Location (`isMocked`) và tính khoảng cách Haversine (mét). |
| 4 | [`image_studio_service.dart`](file:///d:/FALL26/PRM393/travel_trust_network_mobile/lib/services/image_studio_service.dart) | Ghép lớp Postcard bằng `RepaintBoundary` và xử lý ghép ảnh/Panorama 360° trên `Isolate.run`. |
| 5 | [`locket_widget_service.dart`](file:///d:/FALL26/PRM393/travel_trust_network_mobile/lib/services/locket_widget_service.dart) | Nhận Push Signal nền `@pragma('vm:entry-point')` từ FCM và cập nhật ảnh Widget qua `HomeWidget`. |

---

## 3. Chi tiết từng File & Nhiệm vụ kỹ thuật

### 3.1. `api_service.dart`
- **Mục đích:** Đóng vai trò là cổng giao tiếp duy nhất giữa ứng dụng di động và hệ thống Java Microservices thông qua API Gateway.
- **Nhiệm vụ & Chức năng cụ thể:**
  - Khởi tạo instance `Dio` với `BaseOptions` (Base URL trỏ về API Gateway, timeout 15 giây, headers chuẩn `application/json`).
  - **Auth Interceptor:** Tự động lấy `accessToken` từ bộ nhớ an toàn (`FlutterSecureStorage` hoặc SharedPreferences) để gắn vào Header: `Authorization: Bearer <accessToken>`.
  - **Refresh Token Interceptor (Tự động phục hồi phiên):** Bắt sự kiện khi nhận mã phản hồi HTTP `401 Unauthorized`. Tạm dừng các request đang chờ, tự động gọi API `/auth/refresh` bằng `refreshToken`, cập nhật token mới vào kho lưu trữ và tự động phát lại (retry) các request bị lỗi trước đó.
  - Xử lý các mã lỗi phổ biến: `400 Bad Request`, `403 Forbidden`, `404 Not Found`, `500 Server Error` và trả về thông báo lỗi thân thiện cho tầng Controller.

---

### 3.2. `local_db_service.dart` (Đáp ứng Yêu cầu 1)
- **Mục đích:** Cung cấp cơ chế lưu trữ dữ liệu bền vững (Persistence Storage) ngay trên thiết bị bằng thư viện `sqflite` (hoặc `drift`), đảm bảo app hoạt động ổn định khi du khách đến các khu vực không có kết nối Internet.
- **Quản lý 3 bảng SQLite bắt buộc:**
  1. **`cached_places` (Địa điểm yêu thích & Offline):**
     - Lưu trữ danh sách địa điểm người dùng đã bấm lưu (Bookmarks) để xem lại bản đồ, hướng dẫn tham quan mà không cần mạng.
     - Các cột: `id TEXT PRIMARY KEY, name TEXT, category TEXT, address TEXT, latitude REAL, longitude REAL, averageRating REAL, verifiedReviewCount INTEGER, isSaved INTEGER`.
  2. **`draft_visits` (Chuyến đi tạm thời khi mất mạng):**
     - Lưu phiên Check-in GPS thực địa khi mạng chập chờn. Dữ liệu này sẽ tự động được đồng bộ lên Java Server khi thiết bị có kết nối Internet trở lại.
     - Các cột: `visitId TEXT PRIMARY KEY, placeId TEXT, userId TEXT, checkInTime TEXT, checkOutTime TEXT, userLat REAL, userLng REAL, distanceMeters REAL, isVerified INTEGER`.
  3. **`locket_history` (Lịch sử ảnh Locket Widget):**
     - Lưu danh sách ảnh bạn bè gửi tới kèm đường dẫn file cục bộ (`localFilePath`) để Widget màn hình chính luôn đọc được ảnh mà không phụ thuộc vào tải mạng trực tiếp.
     - Các cột: `id TEXT PRIMARY KEY, senderName TEXT, senderAvatar TEXT, imageUrl TEXT, localFilePath TEXT, caption TEXT, receivedAt TEXT`.
- **Phương thức cung cấp:** Khởi tạo database (`initDatabase`), nâng cấp version (`onUpgrade`), và các hàm `insert`, `query`, `delete` tương ứng cho từng bảng.

---

### 3.3. `gps_service.dart` (Đáp ứng Xác thực GPS & Chống gian lận)
- **Mục đích:** Tương tác với phần cứng định vị toàn cầu của thiết bị để cung cấp tọa độ chính xác, phục vụ tính năng Check-in xác thực vị trí thực địa.
- **Nhiệm vụ & Chức năng cụ thể:**
  - **Quản lý quyền vị trí:** Kiểm tra và yêu cầu cấp quyền `LocationPermission` (`checkPermission`, `requestPermission`) từ người dùng.
  - **Lấy tọa độ chính xác:** Gọi `Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high)`.
  - **Chống Fake GPS (Anti-Mock Location):** Kiểm tra cờ `position.isMocked`. Nếu phát hiện `isMocked == true` (người dùng đang bật phần mềm giả lập vị trí như Fake GPS Location), lập tức từ chối xác thực chuyến đi để bảo vệ độ uy tín của hệ sinh thái Trust Network.
  - **Công thức tính khoảng cách Haversine:** Viết hàm toán học thuần túy:
    $$\Delta d = 2R \cdot \arcsin\left(\sqrt{\sin^2\left(\frac{\Delta\phi}{2}\right) + \cos(\phi_1)\cos(\phi_2)\sin^2\left(\frac{\Delta\lambda}{2}\right)}\right)$$
    Hàm nhận vào `(userLat, userLng)` và `(placeLat, placeLng)` và trả về khoảng cách chính xác theo đơn vị **mét**.

---

### 3.4. `image_studio_service.dart` (Xử lý Postcard & Ảnh Panorama 360°)
- **Mục đích:** Xử lý đồ họa đa lớp cho tính năng Postcard Du lịch và tối ưu hóa hiệu năng render ảnh 360 độ.
- **Nhiệm vụ & Chức năng cụ thể:**
  - **Xuất ảnh Postcard (RepaintBoundary Capture):** Chụp toàn bộ khung hình đồ họa đang được người dùng thiết kế (bao gồm ảnh nền chụp từ camera + khung viền du lịch + các nhãn dán sticker + tem tọa độ GPS xác thực) thông qua `RenderRepaintBoundary.toImage(pixelRatio: 3.0)`. Nén thành định dạng file `.png` và lưu vào thư mục tạm của ứng dụng.
  - **Xử lý đa luồng trên Isolate (`Isolate.run`):** Khi người dùng chụp chuỗi ảnh liên tiếp hoặc ghép ảnh toàn cảnh Panorama 360°, quá trình mã hóa pixel và căn chỉnh tiêu cự đòi hỏi CPU cao. Toàn bộ logic này được đẩy sang `Isolate` chạy ngầm độc lập, đảm bảo UI chính của Flutter duy trì ổn định ở tốc độ 60/120 FPS mà không hề bị đơ (UI freeze).

---

### 3.5. `locket_widget_service.dart` (Clone Locket Widget ngoài màn hình chính)
- **Mục đích:** Biến trải nghiệm chia sẻ chuyến đi thành một tiện ích sống động ngay trên màn hình chính của điện thoại thông qua tính năng Locket Widget.
- **Nhiệm vụ & Chức năng cụ thể:**
  - **Đăng ký Background Handler:** Khai báo hàm `@pragma('vm:entry-point')` với `FirebaseMessaging.onBackgroundMessage` để hệ điều hành có thể đánh thức ứng dụng khi nhận được Signal dạng Silent/Data Push Notification từ bạn bè.
  - **Tải ảnh ngầm:** Khi nhận được signal, dịch vụ tải ngay bức ảnh chất lượng cao về thư mục lưu trữ cục bộ (`getApplicationDocumentsDirectory`).
  - **Đồng bộ Widget:** Gửi dữ liệu đường dẫn ảnh cục bộ và lời nhắn chú thích vào `HomeWidget.saveWidgetData()`, sau đó kích hoạt `HomeWidget.updateWidget(name: 'LocketWidgetProvider')` để làm mới tức thì khung hiển thị ảnh ngoài màn hình chính Android/iOS.
  - Tự động ghi lại bản ghi mới vào bảng `locket_history` thông qua `LocalDbService`.

---

## 4. Nguyên tắc hoạt động & Tương tác giữa các Package
1. **Không can thiệp vào Business Rules:** `GpsService` chỉ làm nhiệm vụ tính ra khoảng cách (ví dụ: $185m$); việc kiểm tra con số này có $\le 200m$ hay không thuộc trách nhiệm của `visit_controller.dart`.
2. **Quản lý tài nguyên an toàn:** Luôn giải phóng bộ nhớ hình ảnh (Image Buffers), đóng kết nối Database khi cần và xử lý triệt để các ngoại lệ `try-catch` khi gọi phần cứng hay mạng.
