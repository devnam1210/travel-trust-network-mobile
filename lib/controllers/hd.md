# HƯỚNG DẪN & TÀI LIỆU PACKAGE: `lib/controllers/`

---

## 1. Tổng quan & Mục đích của Package
Package `controllers/` được xem là **Trái tim điều khiển, Trung tâm Quản lý Trạng thái & Quy tắc Nghiệp vụ (State Management & Business Rules Engine)** trong kiến trúc 4 tầng:
> **Views** $\rightarrow$ **Controllers** $\rightarrow$ **Services** $\rightarrow$ **Models**

### Mục đích chính:
- **Tập trung hóa toàn bộ Business Rules (PBR - Project Business Rules):** Tách biệt hoàn toàn logic kiểm tra điều kiện (ví dụ: khoảng cách GPS $\le 200m$, không check-in 2 nơi cùng lúc, đánh giá 1-5 sao, xác thực trước khi review) ra khỏi giao diện View. Khi giảng viên hoặc nghiệp vụ yêu cầu thay đổi quy tắc, lập trình viên **chỉ cần mở đúng thư mục `controllers/` để chỉnh sửa**.
- **Quản lý trạng thái dùng chung (Shared Application State):** Sử dụng các mô hình quản lý trạng thái hiện đại trong Flutter (`ChangeNotifier` với Provider hoặc `StateNotifier` với Riverpod) để lưu trữ và chia sẻ dữ liệu liên tục giữa 5+ màn hình trong chuỗi liên thông nghiệp vụ.
- **Điều phối tầng Dịch vụ (Orchestrator):** Tiếp nhận hành động từ View, thực thi kiểm tra tính hợp lệ (Validation), gọi tuần tự các hàm xử lý bên `services/` (gọi API, truy vấn SQLite, đọc GPS, xuất ảnh), cập nhật lại State và thông báo cho View cập nhật giao diện (`notifyListeners()`).

---

## 2. Danh mục các file trong Package

| STT | Tên file | Mục đích & Trách nhiệm quản lý State | Quy tắc Nghiệp vụ (PBR) thực thi |
|:---:|:---|:---|:---|
| 1 | [`auth_controller.dart`](file:///d:/FALL26/PRM393/travel_trust_network_mobile/lib/controllers/auth_controller.dart) | Quản lý phiên đăng nhập bằng email và mật khẩu, thông tin người dùng và điểm uy tín. | Đăng nhập, đăng ký, khôi phục phiên và đăng xuất. |
| 2 | [`place_controller.dart`](file:///d:/FALL26/PRM393/travel_trust_network_mobile/lib/controllers/place_controller.dart) | Quản lý danh sách địa điểm, tìm kiếm, bộ lọc danh mục và trạng thái Bookmark/Lưu ngoại tuyến. | Yêu cầu 1: Đồng bộ địa điểm yêu thích với bảng SQLite `cached_places`. |
| 3 | [`visit_controller.dart`](file:///d:/FALL26/PRM393/travel_trust_network_mobile/lib/controllers/visit_controller.dart) | Quản lý chu trình Check-in/Check-out chuyến đi thực tế và trạng thái xác minh GPS. | **PBR-013**: Ngăn check-in trùng lặp.<br>**PBR-017**: Bán kính GPS $\le 200m$.<br>**PBR-014**: Xác nhận Check-out hợp lệ. |
| 4 | [`studio_controller.dart`](file:///d:/FALL26/PRM393/travel_trust_network_mobile/lib/controllers/studio_controller.dart) | Quản lý các lớp hiệu ứng (Layers: Sticker, Khung, Tem GPS), cảm biến con quay hồi chuyển 360° và file ảnh Postcard. | Quản lý lớp vẽ đồ họa và giữ State `postcardFile` chuyển tiếp sang Review. |
| 5 | [`review_locket_controller.dart`](file:///d:/FALL26/PRM393/travel_trust_network_mobile/lib/controllers/review_locket_controller.dart) | Tiếp nhận `verifiedVisit` + `postcardFile` để thẩm định và xuất bản bài đánh giá xác minh kèm bắn tín hiệu Locket Widget. | **PBR-023, PBR-024**: Bắt buộc `isVerified == true`.<br>**PBR-025**: Số sao từ 1 đến 5.<br>Cộng Trust Score & Push Locket. |

---

## 3. Chi tiết từng File & Quy tắc Nghiệp vụ (Business Rules)

### 3.1. `auth_controller.dart` (Quản lý Xác thực & Phiên làm việc)
- **State nắm giữ:** `UserModel? currentUser`, `bool isLoading`, `String? errorMessage`.
- **Nhiệm vụ & Chức năng cụ thể:**
  - Gửi email và mật khẩu do người dùng tạo cho ứng dụng đến `/api/v1/auth/login`; đăng ký qua `/api/v1/auth/register`.
  - Lưu JWT `accessToken` bằng `flutter_secure_storage`, khôi phục phiên bằng API hồ sơ và hiển thị lỗi xác thực.
  - Cung cấp hàm `logout()`: Xóa token trên thiết bị và đặt lại trạng thái xác thực.
  - **Cập nhật điểm uy tín:** Cung cấp hàm `incrementTrustScore(int points)` để cộng điểm uy tín người dùng sau khi hoàn thành đánh giá thực địa thành công.

---

### 3.2. `place_controller.dart` (Khám phá & Lưu ngoại tuyến)
- **State nắm giữ:** `List<PlaceModel> places`, `List<PlaceModel> savedPlaces`, `String selectedCategory`, `String searchQuery`, `bool isLoading`.
- **Nhiệm vụ & Chức năng cụ thể:**
  - Tải danh sách địa điểm từ API hoặc lấy từ bảng `cached_places` trong `LocalDbService` khi không có Internet.
  - Tìm kiếm theo từ khóa và lọc danh mục thời gian thực trên danh sách địa điểm.
  - **Xử lý Bookmark Offline (Yêu cầu 1):** Cung cấp hàm `toggleSavePlace(PlaceModel place)`. Nếu lưu, gọi `LocalDbService.insertCachedPlace(place)` và cập nhật cờ `isSaved = true`; nếu bỏ lưu, xóa khỏi bảng SQLite tương ứng.

---

### 3.3. `visit_controller.dart` (Kiểm tra Quy tắc Chuyến đi)
- **State nắm giữ:** `VisitModel? activeVisit` (chuyến đi đang diễn ra), `VisitModel? verifiedVisit` (chuyến đi đã xác minh thành công), `bool isCheckingIn`, `String? checkInError`.
- **Thực thi các Business Rules quan trọng:**
  1. **Quy tắc PBR-013 (Không check-in đồng thời nhiều nơi):**
     - Khi người dùng bấm Check-in: Kiểm tra điều kiện `if (activeVisit != null)`.
     - Nếu còn chuyến đi chưa kết thúc, ném ra ngoại lệ hoặc hiển thị thông báo lỗi yêu cầu người dùng phải Check-out chuyến đi hiện tại trước khi bắt đầu chuyến đi mới.
  2. **Quy tắc PBR-017 (Giới hạn bán kính GPS thực tế):**
     - Kích hoạt `GpsService.getCurrentPosition()`.
     - Kiểm tra nếu `position.isMocked == true` $\rightarrow$ Từ chối ngay lập tức do gian lận vị trí.
     - Gọi hàm Haversine tính `distanceMeters` giữa tọa độ người dùng và tọa độ của `PlaceModel`.
     - Nếu `distanceMeters > 200.0` (ngưỡng 200m) $\rightarrow$ Từ chối xác thực check-in thực địa và thông báo: *"Bạn đang ở quá xa địa điểm quy định (cách ...m)"*.
  3. **Quy tắc PBR-014 (Hợp lệ hóa Check-out & Xác minh chuyến đi):**
     - Khi người dùng bấm Check-out: Ghi nhận `checkOutTime`, kiểm tra khoảng thời gian viếng thăm tối thiểu hợp lệ.
     - Cập nhật cờ `isVerified = true` cho phiên đi và lưu vào `verifiedVisit`.
     - Đồng thời lưu dự phòng vào bảng `draft_visits` của SQLite phòng trường hợp rớt mạng.

---

### 3.4. `studio_controller.dart` (Xử lý Đồ họa Postcard & Trải nghiệm 360°)
- **State nắm giữ:** `List<StudioLayer> layers` (danh sách nhãn dán, khung, tem), `File? rawPhoto`, `File? postcardFile` (kết quả xuất ảnh hoàn chỉnh), `bool is360ModeEnabled`, `double rotationAngle`.
- **Nhiệm vụ & Chức năng cụ thể:**
  - Thêm, xóa, di chuyển, thay đổi kích thước các nhãn dán (Stickers) và khung viền du lịch.
  - **Tem tọa độ GPS:** Tự động lấy thông tin từ `verifiedVisit` (Tên địa điểm, Kinh độ/Vĩ độ, Thời gian check-in) để tạo tem đóng dấu xác thực in chìm trên ảnh.
  - **Trải nghiệm góc nhìn 360°:** Lắng nghe dữ liệu từ cảm biến con quay hồi chuyển (`sensors_plus: gyroscopeEvents`) để xoay góc nhìn ảnh Panorama 360 độ tự nhiên theo hướng nghiêng tay của người dùng.
  - Gọi `ImageStudioService.capturePostcard()` để lưu kết quả vào `postcardFile`, sẵn sàng truyền sang Controller xuất bản Review.

---

### 3.5. `review_locket_controller.dart` (Đăng Review Xác thực & Gửi Locket)
- **State nắm giữ:** `bool isSubmitting`, `bool isSuccess`, `String? errorMessage`.
- **Nhiệm vụ & Thực thi Business Rules:**
  1. **Tiếp nhận dữ liệu liên thông:** Nhận `verifiedVisit` từ `VisitController` và `postcardFile` từ `StudioController`.
  2. **Quy tắc PBR-023 & PBR-024 (Kiểm tra Điều kiện Bắt buộc Đăng bài):**
     - Chỉ cho phép kích hoạt nút Đăng bài nếu `verifiedVisit != null` và `verifiedVisit.isVerified == true`.
     - Tuyệt đối ngăn chặn hành vi tạo Review "ảo" khi chưa có bằng chứng xác thực GPS tại thực địa.
  3. **Quy tắc PBR-025 (Khoảng giá trị Đánh giá):**
     - Số sao xếp hạng phải nằm trong khoảng hợp lệ từ 1 đến 5 sao (`rating >= 1 && rating <= 5`).
  4. **Hậu xử lý sau khi Đăng thành công:**
     - Gọi `ApiService` đăng tải bài đánh giá và ảnh Postcard lên Java Microservice.
     - Kích hoạt `AuthController.incrementTrustScore(+10)` để tăng điểm uy tín người dùng.
     - Gửi tín hiệu Locket kèm ảnh Postcard tới danh sách bạn bè qua Firebase Cloud Messaging và cập nhật vào `LocketWidgetService`.

---

## 4. Mô hình dòng chảy dữ liệu (Data Flow) giữa các Controller
```
[User Action trên UI]
         │
         ▼
place_controller (Chọn & Truyền PlaceModel)
         │
         ▼
visit_controller (Kiểm tra PBR-013, PBR-017, PBR-014 -> Tạo verifiedVisit)
         │
         ▼
studio_controller (Gắn Tem GPS từ verifiedVisit -> Xuất postcardFile)
         │
         ▼
review_locket_controller (Kiểm tra PBR-023, PBR-024, PBR-025)
         │
         ├──► auth_controller.incrementTrustScore()
         └──► locket_widget_service.pushSignal()
```
