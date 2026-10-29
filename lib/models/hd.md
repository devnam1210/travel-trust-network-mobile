# HƯỚNG DẪN & TÀI LIỆU PACKAGE: `lib/models/`

---

## 1. Tổng quan & Mục đích của Package
Package `models/` là **Tầng định nghĩa cấu trúc dữ liệu (Data Definition Layer)** trong kiến trúc 4 tầng của ứng dụng Travel Trust Network:
> **Views** $\rightarrow$ **Controllers** $\rightarrow$ **Services** $\rightarrow$ **Models**

### Mục đích chính:
- **Đại diện thực thể dữ liệu (Data Entities):** Chứa các Data Class đại diện cho tất cả thực thể nghiệp vụ của ứng dụng (Người dùng, Địa điểm, Chuyến đi, Đánh giá, Locket Widget).
- **Cầu nối chuyển đổi dữ liệu đa nguồn:** 
  - Đọc và ánh xạ JSON từ hệ thống **Java Microservices** (`fromJson`).
  - Đóng gói dữ liệu gửi lên REST API (`toJson`).
  - Ánh xạ 2 chiều với các bảng trong cơ sở dữ liệu **SQLite Local** (`toMap` và `fromMap`).
- **Bất biến và tính toàn vẹn dữ liệu (Immutability & Data Integrity):** Giữ dữ liệu chuẩn xác, nhất quán xuyên suốt quá trình truyền tải giữa các tầng Service, Controller và hiển thị trên View.
- **Hoàn toàn độc lập:** Không chứa code giao diện (`Widget`, `BuildContext`), không chứa logic nghiệp vụ và không trực tiếp gọi API hay truy vấn database.

---

## 2. Danh mục các file trong Package

| STT | Tên file | Mục đích & Thực thể quản lý |
|:---:|:---|:---|
| 1 | [`user_model.dart`](file:///d:/FALL26/PRM393/travel_trust_network_mobile/lib/models/user_model.dart) | Quản lý thông tin tài khoản người dùng, phiên đăng nhập và Điểm uy tín (Trust Score). |
| 2 | [`place_model.dart`](file:///d:/FALL26/PRM393/travel_trust_network_mobile/lib/models/place_model.dart) | Quản lý thông tin địa điểm du lịch, tọa độ chuẩn GPS và trạng thái lưu ngoại tuyến. |
| 3 | [`visit_model.dart`](file:///d:/FALL26/PRM393/travel_trust_network_mobile/lib/models/visit_model.dart) | Quản lý phiên chuyến đi (Check-in / Check-out) và cờ xác thực vị trí thực tế. |
| 4 | [`review_model.dart`](file:///d:/FALL26/PRM393/travel_trust_network_mobile/lib/models/review_model.dart) | Quản lý bài đánh giá đã xác minh (Verified Review), số sao và đường dẫn ảnh Postcard. |
| 5 | [`locket_item_model.dart`](file:///d:/FALL26/PRM393/travel_trust_network_mobile/lib/models/locket_item_model.dart) | Quản lý dữ liệu ảnh tương tác nhanh nhận từ bạn bè để hiển thị lên Home Widget. |

---

## 3. Chi tiết từng File & Cấu trúc Thuộc tính

### 3.1. `user_model.dart`
- **Mục đích:** Lưu trữ hồ sơ người dùng hiện tại sau khi đăng nhập bằng email và mật khẩu.
- **Các thuộc tính chính:**
  - `String id`: Mã định danh duy nhất của người dùng (UUID).
  - `String email`: Địa chỉ Gmail của người dùng.
  - `String fullName`: Tên hiển thị của người dùng.
  - `String? avatarUrl`: Đường dẫn ảnh đại diện nếu có.
  - `int trustScore`: Điểm uy tín cộng dồn từ các lần Review xác thực thành công.
  - JWT `accessToken` được lưu riêng trong `flutter_secure_storage`, không nằm trong `UserModel`.
- **Phương thức bắt buộc:**
  - `factory UserModel.fromJson(Map<String, dynamic> json)`
  - `Map<String, dynamic> toJson()`
  - `UserModel copyWith({...})`

---

### 3.2. `place_model.dart`
- **Mục đích:** Đại diện cho một địa điểm tham quan/du lịch trong danh sách khám phá và hỗ trợ lưu vào bảng SQLite `cached_places` để xem ngoại tuyến (Offline Mode).
- **Các thuộc tính chính:**
  - `String id`: Mã định danh địa điểm.
  - `String name`: Tên địa điểm (ví dụ: "Hồ Hoàn Kiếm", "Dinh Độc Lập").
  - `String category`: Phân loại (Di tích, Ẩm thực, Phong cảnh, Lưu trú...).
  - `String address`: Địa chỉ hiển thị.
  - `double latitude`: Vĩ độ chuẩn của địa điểm.
  - `double longitude`: Kinh độ chuẩn của địa điểm.
  - `double averageRating`: Điểm đánh giá trung bình (1.0 - 5.0).
  - `int verifiedReviewCount`: Số lượng đánh giá đã xác thực qua GPS.
  - `bool isSaved`: Cờ đánh dấu người dùng đã lưu địa điểm này vào SQLite Local hay chưa.
- **Phương thức bắt buộc:**
  - `factory PlaceModel.fromJson(Map<String, dynamic> json)`
  - `Map<String, dynamic> toJson()`
  - `factory PlaceModel.fromMap(Map<String, dynamic> map)` (SQLite)
  - `Map<String, dynamic> toMap()` (SQLite)

---

### 3.3. `visit_model.dart`
- **Mục đích:** Lưu trữ thông tin một phiên viếng thăm thực tế tại địa điểm. Là trung tâm để kiểm tra các Business Rules (PBR-013, PBR-014, PBR-017) và xác thực tính hợp lệ trước khi cho phép đăng Review.
- **Các thuộc tính chính:**
  - `String visitId`: Mã phiên chuyến đi.
  - `String placeId`: Địa điểm đang check-in.
  - `String userId`: Người dùng thực hiện check-in.
  - `DateTime checkInTime`: Thời điểm bấm Check-in.
  - `DateTime? checkOutTime`: Thời điểm bấm Check-out (phải sau Check-in).
  - `double userLat`: Tọa độ vĩ độ thực tế từ GPS điện thoại.
  - `double userLng`: Tọa độ kinh độ thực tế từ GPS điện thoại.
  - `double distanceMeters`: Khoảng cách tính bằng Haversine từ tọa độ GPS thực tế đến tọa độ chuẩn của địa điểm.
  - `bool isVerified`: Cờ xác nhận chuyến đi đã thỏa mãn khoảng cách $\le 200m$ và không bị Fake GPS.
- **Phương thức bắt buộc:**
  - `factory VisitModel.fromJson(Map<String, dynamic> json)`
  - `Map<String, dynamic> toJson()`
  - `factory VisitModel.fromMap(Map<String, dynamic> map)` (Bảng `draft_visits` trong SQLite)
  - `Map<String, dynamic> toMap()`

---

### 3.4. `review_model.dart`
- **Mục đích:** Lưu trữ nội dung bài đánh giá uy tín kèm ảnh Postcard sau khi đã hoàn tất chuyến đi xác thực.
- **Các thuộc tính chính:**
  - `String reviewId`: Mã đánh giá.
  - `String visitId`: Tham chiếu tới chuyến đi đã xác minh (`isVerified == true`).
  - `String placeId`: Mã địa điểm được đánh giá.
  - `int rating`: Số sao đánh giá từ 1 đến 5 (theo PBR-025).
  - `String comment`: Nội dung cảm nhận chi tiết của du khách.
  - `String postcardImagePath`: Đường dẫn file ảnh Postcard đã ghép tem GPS và các lớp hiệu ứng.
  - `bool isVerifiedReview`: Cờ xác nhận đánh giá được gắn nhãn "Đã xác thực thực địa".
  - `DateTime createdAt`: Thời gian đăng bài.
- **Phương thức bắt buộc:**
  - `factory ReviewModel.fromJson(Map<String, dynamic> json)`
  - `Map<String, dynamic> toJson()`

---

### 3.5. `locket_item_model.dart`
- **Mục đích:** Đại diện cho một bức ảnh nhận từ bạn bè trong mạng lưới Locket, dùng để lưu trữ vào bảng `locket_history` của SQLite và hiển thị lên Home Screen Widget của điện thoại.
- **Các thuộc tính chính:**
  - `String id`: Mã tin ảnh Locket.
  - `String senderName`: Tên bạn bè gửi ảnh.
  - `String? senderAvatar`: Avatar của người gửi.
  - `String imageUrl`: Link ảnh từ máy chủ.
  - `String localFilePath`: Đường dẫn file ảnh đã được tải về lưu trữ trong bộ nhớ máy để cấp cho Widget.
  - `String caption`: Lời nhắn/chú thích đính kèm ảnh.
  - `DateTime receivedAt`: Thời điểm nhận ảnh.
- **Phương thức bắt buộc:**
  - `factory LocketItemModel.fromJson(Map<String, dynamic> json)`
  - `Map<String, dynamic> toJson()`
  - `factory LocketItemModel.fromMap(Map<String, dynamic> map)` (Bảng `locket_history` SQLite)
  - `Map<String, dynamic> toMap()`

---

## 4. Mối quan hệ và Quy ước thiết kế (Conventions)
1. **JSON Serialization:** Tất cả Model đều phải tuân thủ chuẩn đặt tên `camelCase` trong Dart và ánh xạ chính xác với `snake_case` hoặc `camelCase` tương ứng của API Java Backend.
2. **SQLite Mapping:** Với các thuộc tính dạng `bool`, khi lưu vào SQLite thông qua `toMap()` sẽ chuyển đổi thành `1` (true) hoặc `0` (false); thuộc tính kiểu `DateTime` được lưu dưới dạng chuỗi `toIso8601String()`.
3. **Tính bất biến (Immutable):** Khuyến khích khai báo tất cả thuộc tính với từ khóa `final` để đảm bảo dữ liệu không bị thay đổi ngoài ý muốn trong quá trình truyền qua Controller.
