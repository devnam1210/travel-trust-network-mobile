# TÀI LIỆU GIẢI THÍCH MÃ NGUỒN - GIAI ĐOẠN 1
**Thành viên thực hiện:** Phạm Hoàng Nam  
**Phạm vi:** Tạo Model DTO, Service gọi API (Places & Reviews) và Khung điều hướng đa màn hình (`MainNavigationScreen`)  
**Công nghệ:** Flutter (Dart), Flutter Riverpod v3, Dio HTTP Client  

---

## 1. Mục tiêu của Giai đoạn 1
Giai đoạn 1 đặt nền móng kiến trúc cho toàn bộ các tính năng tiếp theo của Phạm Hoàng Nam, bao gồm:
1. **Chuẩn hóa tầng dữ liệu (Data Modeling):** Xây dựng các Data Class ánh xạ 1:1 với các DTO phản hồi và request từ Spring Boot Backend (`PlaceSummaryResponse`, `PlaceDetailResponse`, `ReviewResponse`, `CreateReviewRequest`).
2. **Xây dựng tầng dịch vụ (Service Layer):** Tận dụng `ApiService` đóng gói `Dio` để định nghĩa các phương thức gọi API RESTful cho Module Địa điểm (`PlaceService`) và Module Đánh giá (`ReviewService`).
3. **Thiết lập Khung điều hướng chính (Main Navigation):** Cung cấp thanh điều hướng `NavigationBar` gồm 3 Tab (*Khám phá*, *Chuyến đi*, *Cá nhân*) giải quyết triệt để yêu cầu bắt buộc của giảng viên về *"Menu điều hướng $\ge$ 3 mục và liên thông màn hình"*.

---

## 2. Chi tiết các tệp mã nguồn và Giải thích Code

```
travel_trust_network_mobile/lib/
├── models/
│   ├── place_model.dart       # [MỚI] Model tóm tắt và chi tiết địa điểm
│   └── review_model.dart      # [MỚI] Model bài đánh giá (Review)
├── services/
│   ├── place_service.dart     # [MỚI] Service gọi API /places
│   └── review_service.dart    # [MỚI] Service gọi API /reviews
└── views/
    ├── main_navigation_screen.dart # [MỚI] Thanh điều hướng 3 Tab (Khám phá, Chuyến đi, Cá nhân)
    └── auth/
        └── auth_gate.dart     # [CẬP NHẬT] Đổi đích đến sau đăng nhập sang MainNavigationScreen
```

---

### 2.1. Tầng Model DTO (`lib/models/`)

#### A. Tệp `review_model.dart`
* **Vị trí:** `lib/models/review_model.dart`
* **Mục đích:** Ánh xạ dữ liệu trả về từ `ReviewResponse.java` của Backend.
* **Các trường dữ liệu quan trọng:**
  - `id`: Khóa chính UUID của bài review.
  - `userId`, `fullName`, `avatarUrl`: Thông tin tác giả viết review.
  - `placeId`, `visitId`: Liên kết bài review với một địa điểm cụ thể và chuyến đi đã được check-out.
  - `rating`: Số sao đánh giá (từ 1 đến 5).
  - `comment`: Nội dung nhận xét của người dùng.
  - `postcardImageUrl`: Đường dẫn URL ảnh chụp (nếu có đính kèm ảnh postcard).
  - `isVerifiedReview`: Cờ boolean do server xác thực (mặc định là `true` khi gắn với visit hợp lệ).
  - `createdAt`: Thời gian tạo review (`DateTime`).
* **Kỹ thuật xử lý trong code:**
  - `(json['rating'] as num).toInt()`: Tránh lỗi ép kiểu dữ liệu giữa `int` và `double` khi parse JSON.
  - `DateTime.parse(...)`: Chuyển đổi chuỗi thời gian ISO-8601 từ server thành đối tượng `DateTime` trong Dart.

#### B. Tệp `place_model.dart`
* **Vị trí:** `lib/models/place_model.dart`
* **Mục đích:** Định nghĩa 2 lớp:
  1. `PlaceSummaryModel`: Dùng cho màn hình danh sách tìm kiếm (tiết kiệm băng thông, chỉ chứa thông tin tóm tắt: tên, danh mục, địa chỉ, ảnh đại diện, rating trung bình, số lượng review).
  2. `PlaceDetailModel`: Dùng cho màn hình chi tiết địa điểm, bổ sung thêm:
     - `description`: Mô tả chi tiết về địa điểm.
     - `openingHours`: Giờ mở cửa.
     - `latitude`, `longitude`: Tọa độ GPS chuẩn để phục vụ tính toán khoảng cách.
     - `allowedRadiusM`: Bán kính cho phép check-in tính bằng mét (ví dụ: FPT Campus là 500m, nơi khác là 200m).
     - `reviews`: Danh sách `List<ReviewModel>` các bài đánh giá của người dùng khác.
* **Kỹ thuật xử lý trong code:**
  - Parse danh sách review an toàn:
    ```dart
    final rawReviews = json['reviews'] as List<dynamic>? ?? [];
    reviews: rawReviews
        .map((item) => ReviewModel.fromJson(item as Map<String, dynamic>))
        .toList(growable: false),
    ```
  - `growable: false`: Tối ưu hiệu năng bộ nhớ RAM, tránh cấp phát lại mảng khi không cần sửa đổi danh sách.

---

### 2.2. Tầng Dịch vụ (`lib/services/`)

#### A. Tệp `place_service.dart`
* **Vị trí:** `lib/services/place_service.dart`
* **Mục đích:** Cung cấp phương thức tìm kiếm và lấy chi tiết địa điểm.
* **Code chi tiết:**
  ```dart
  final placeServiceProvider = Provider<PlaceService>(
    (ref) => PlaceService(api: ref.watch(apiServiceProvider)),
  );
  ```
  - Sử dụng Riverpod `Provider` để Dependency Injection `ApiService`.
  - `searchPlaces({String? keyword, String? category})`:
    - Xây dựng URI có query parameters linh hoạt (`/places?keyword=...&category=...`).
    - Nếu `category == 'ALL'`, bỏ qua tham số để Backend trả về toàn bộ địa điểm.
    - Gọi `api.getList(...)` (helper method đã viết sẵn trong `ApiService` để parse envelope `ApiResponse<List<T>>`).
  - `getPlaceDetail(String id)`:
    - Gọi `GET /places/{id}` và encode ID an toàn bằng `Uri.encodeComponent(id)`.

#### B. Tệp `review_service.dart`
* **Vị trí:** `lib/services/review_service.dart`
* **Mục đích:** Gửi yêu cầu tạo bài đánh giá lên `POST /api/v1/reviews`.
* **Payload gửi lên:**
  ```json
  {
    "visitId": "<UUID>",
    "placeId": "<UUID>",
    "rating": 5,
    "comment": "Trải nghiệm tuyệt vời!",
    "postcardImageUrl": "/uploads/...",
    "is360Media": false
  }
  ```
* **Cơ chế:** Khi gọi API thành công, Backend tự động thực hiện transaction:
  1. Khóa bảng kiểm tra visit `VERIFIED` và chống review trùng.
  2. Tính lại `averageRating` và `verifiedReviewCount` của Place.
  3. Cộng **+5 điểm uy tín** cho người dùng và ghi `trust_score_logs`.

---

### 2.3. Khung điều hướng đa màn hình (`MainNavigationScreen`)

* **Vị trí:** `lib/views/main_navigation_screen.dart`
* **Mục đích:** Đóng vai trò là Shell Screen chứa thanh điều hướng Material 3 `NavigationBar` gồm 3 Tab:
  - **Tab 0: Khám phá (`_ExplorePlaceholderView`)**: Hiển thị card chào mừng người dùng, số điểm uy tín hiện tại và giới thiệu các tính năng khám phá (sẽ được thay bằng `ExploreScreen` ở Giai đoạn 2).
  - **Tab 1: Chuyến đi (`VisitHistoryScreen`)**: Màn hình xem lịch sử các lần Check-in/Check-out của Hầu Văn Hòa.
  - **Tab 2: Cá nhân (`ProfileScreen`)**: Màn hình xem hồ sơ, xem log điểm uy tín và Đăng xuất.

#### Kỹ thuật nổi bật trong `MainNavigationScreen`:
1. **Sử dụng `IndexedStack`:**
   ```dart
   body: IndexedStack(
     index: _currentIndex,
     children: pages,
   ),
   ```
   * *Ưu điểm:* Giữ nguyên trạng thái (State) và vị trí cuộn trang (Scroll position) của từng Tab khi người dùng chuyển đổi qua lại, không bị tải lại trang gây tốn tài nguyên.
2. **Lắng nghe User State thời gian thực:**
   ```dart
   final currentUser = ref.watch(authControllerProvider).user ?? widget.user;
   ```
   * Đảm bảo khi người dùng được cộng điểm ở Tab Chuyến đi hoặc Đánh giá, thông tin ở cả Tab Khám phá và Tab Cá nhân đều được đồng bộ ngay lập tức.
3. **Cập nhật `AuthGate` (`lib/views/auth/auth_gate.dart`):**
   - Đổi trạng thái `AuthStatus.authenticated` từ trả về `ProfileScreen` sang `MainNavigationScreen(user: auth.user!)`.
   - Khi đăng nhập/khôi phục phiên thành công, người dùng lập tức bước vào không gian ứng dụng với đầy đủ 3 menu chức năng.

---

## 3. Kết quả Kiểm tra & Thẩm định Mã nguồn

1. **Phân tích tĩnh (`flutter analyze`):**
   ```
   Analyzing travel_trust_network_mobile...
   No issues found! (ran in 4.4s)
   ```
   * Không có lỗi cú pháp (Syntax errors).
   * Không có cảnh báo linter (Linter warnings).
   * Tuân thủ chuẩn strict type của Dart 3.
2. **Tính tương thích ngược:**
   * Không làm thay đổi hay phá vỡ các tính năng sẵn có của Hầu Văn Hòa (Google Sign-In, GPS Check-in, Visit History).
   * File `auth_gate.dart` đóng route và điều hướng sạch sẽ.

---

## 4. Hướng dẫn demo và trả lời phản biện cho Nam

Khi giảng viên yêu cầu Nam trình bày phần code Giai đoạn 1:
1. **Chỉ ra các file DTO:** Mở `place_model.dart` và `review_model.dart`, giải thích cách ánh xạ đúng kiểu dữ liệu với Record DTO của Java Spring Boot.
2. **Chỉ ra cấu trúc Provider:** Mở `place_service.dart`, giải thích cách Riverpod inject `apiServiceProvider` để tự động đính kèm `Bearer JWT Token` trong mọi request.
3. **Mở app thực tế:** Chỉ vào thanh Bottom Navigation 3 tab:
   - *"Em đã xây dựng khung điều hướng 3 mục theo chuẩn Material 3. Khi chuyển tab, `IndexedStack` giúp bảo lưu trạng thái cuộn của người dùng mà không bị re-render lại từ đầu."*
