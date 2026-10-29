# HƯỚNG DẪN & TÀI LIỆU PACKAGE: `lib/views/`

---

## 1. Tổng quan & Mục đích của Package
Package `views/` là **Tầng Giao diện Người dùng & Trình bày (Presentation Layer)** trong kiến trúc 4 tầng:
> **Views** $\rightarrow$ **Controllers** $\rightarrow$ **Services** $\rightarrow$ **Models**

### Mục đích chính:
- **Trực quan hóa dữ liệu và Tiếp nhận tương tác (UI & User Interaction):** Chịu trách nhiệm hiển thị các thành phần trực quan (Màn hình, Nút bấm, Danh sách, Dialog, Animation) và tiếp nhận mọi thao tác cử chỉ từ người dùng (chạm, vuốt, cuộn, nhập liệu).
- **Tuân thủ nguyên tắc "Thin Views" (Giao diện tinh gọn):** Views tuyệt đối **không chứa logic nghiệp vụ**, không tự tính toán khoảng cách GPS, không trực tiếp gửi request HTTP và không truy vấn SQLite. Khi người dùng thao tác, View chỉ đơn thuần kích hoạt hàm tương ứng trong Controller và lắng nghe trạng thái (State) để cập nhật giao diện.
- **Thực thi Chuỗi 5 Màn hình Nghiệp vụ Liên thông (Yêu cầu 3):** Xây dựng luồng trải nghiệm người dùng khép kín và liên tục, truyền dữ liệu mượt mà từ khâu chọn địa điểm $\rightarrow$ Check-in thực địa $\rightarrow$ Thiết kế Postcard 360° $\rightarrow$ Đăng đánh giá xác thực & Bắn ảnh Locket.
- **Tổ chức Khung điều hướng chuẩn mực:** Tích hợp bộ khung giao diện chung (`MainLayout`) gồm Top AppBar nhận diện người dùng, Thanh điều hướng dưới đáy (Bottom Navigation Bar 4 tab) và Menu ngăn kéo cạnh bên (Side Drawer).

---

## 2. Danh mục các file & Thư mục trong Package

```
lib/views/
├── widgets/                       # Các thành phần giao diện dùng chung (Reusable Widgets)
│   ├── main_layout.dart           # Khung Layout chuẩn: Top AppBar + BottomNav 4 tab + Drawer
│   └── trust_score_badge.dart     # Huy hiệu hiển thị Điểm uy tín (Trust Score Badge)
│
├── login_screen.dart              # Màn hình Đăng nhập bằng email và mật khẩu
├── profile_screen.dart            # Màn hình Hồ sơ cá nhân & Lịch sử Trust Score
│
├── place_list_screen.dart         # [Màn liên thông 1] Khám phá & Tìm kiếm địa điểm
├── place_detail_screen.dart       # [Màn liên thông 2] Chi tiết địa điểm & Nút bấm Check-in
├── gps_checkin_screen.dart        # [Màn liên thông 3] Xác thực vị trí GPS & Check-out chuyến đi
├── postcard_studio_screen.dart    # [Màn liên thông 4] Chụp ảnh 360° & Ghép lớp hiệu ứng Postcard
└── publish_review_screen.dart     # [Màn liên thông 5] Đăng Review xác minh & Bắn ảnh Locket Widget
```

---

## 3. Chi tiết từng Thành phần & Màn hình Giao diện

### 3.1. Thư mục `widgets/` (Thành phần dùng chung)

#### `main_layout.dart` (Khung Layout chuẩn của Ứng dụng)
- **Mục đích:** Đóng vai trò là "vỏ bọc" cố định cho các màn hình chính của ứng dụng, đảm bảo tính nhất quán trong trải nghiệm người dùng.
- **Cấu trúc bao gồm 3 khu vực chính:**
  1. **Top AppBar:**
     - Hiển thị Avatar tròn của người dùng lấy từ hồ sơ backend (`auth_controller`).
     - Tên hiển thị của người dùng (`fullName`).
     - Tích hợp huy hiệu `TrustScoreBadge` hiển thị điểm uy tín hiện tại ngay góc trên bên phải.
  2. **Bottom Navigation Bar (4 Tab chính):**
     - Tab 1: **Khám phá** (Dẫn tới `place_list_screen.dart`).
     - Tab 2: **Check-in** (Dẫn tới màn hình quản lý chuyến đi đang hoạt động).
     - Tab 3: **Locket Feed** (Xem dòng thời gian ảnh bạn bè gửi tới).
     - Tab 4: **Hồ sơ** (Dẫn tới `profile_screen.dart`).
  3. **Side Drawer Menu (Menu ngăn kéo bên cạnh):**
     - Lối tắt đến mục **Địa điểm đã lưu ngoại tuyến** (lấy từ bảng SQLite `cached_places`).
     - **Lịch sử chuyến đi** đã hoàn thành.
     - **Cài đặt thông báo & Locket Widget**.
     - Nút **Đăng xuất** (kích hoạt `AuthController.logout()`).

#### `trust_score_badge.dart` (Huy hiệu Điểm Uy Tín)
- **Mục đích:** Hiển thị số điểm uy tín (`trustScore`) của người dùng hoặc địa điểm kèm icon chiếc khiên xác minh.
- **Đặc điểm hiển thị:** Tự động đổi màu sắc theo cấp bậc uy tín (ví dụ: Vàng kim cho thành viên Uy tín cao > 100 điểm, Bạc cho mức trung bình, Đồng cho thành viên mới) nhằm tăng tính kích thích du khách đi trải nghiệm thực địa.

---

### 3.2. Màn hình Độc lập

#### `login_screen.dart` (Đăng nhập email và mật khẩu)
- **Mục đích:** Màn hình đầu tiên người dùng nhìn thấy khi chưa có phiên đăng nhập hợp lệ.
- **Giao diện:** Logo Travel Trust Network, ô email, mật khẩu và nút đăng nhập; màn đăng ký có thêm họ tên và xác nhận mật khẩu.
- **Tương tác:** Gọi `AuthController.login()` hoặc `register()`, hiển thị tiến trình và chuyển sang hồ sơ khi backend cấp JWT.

#### `profile_screen.dart` (Hồ sơ cá nhân & Thống kê Trust Score)
- **Mục đích:** Quản lý thông tin cá nhân và minh bạch hóa lịch sử điểm số.
- **Giao diện:**
  - Ảnh đại diện lớn, Họ tên, Email tài khoản.
  - Bảng thống kê số lần Check-in thực tế, số bài Đánh giá đã xác thực qua GPS, và tổng điểm Trust Score.
  - Danh sách lịch sử các mốc cộng điểm uy tín (ví dụ: `+10 điểm: Check-in tại Dinh Độc Lập`).
  - Nút **Đăng xuất tài khoản**.

---

### 3.3. Chuỗi 5 Màn hình Nghiệp vụ Liên thông Truyền dữ liệu (Yêu cầu 3)

Chuỗi 5 màn hình liên thông tạo thành một kịch bản trải nghiệm xuyên suốt từ lúc tìm kiếm địa điểm đến khi đăng tải bằng chứng thực tế:

```
[Màn 1: place_list_screen]
          │
          │  Truyền PlaceModel
          ▼
[Màn 2: place_detail_screen]
          │
          │  Truyền PlaceModel & Kích hoạt Check-in
          ▼
[Màn 3: gps_checkin_screen]
          │
          │  Xác thực GPS (PBR-017) & Check-out -> Tạo verifiedVisit
          ▼
[Màn 4: postcard_studio_screen]
          │
          │  Đóng dấu Tem GPS từ verifiedVisit -> Xuất postcardFile
          ▼
[Màn 5: publish_review_screen]
          │
          └──► Đăng Verified Review & Bắn Signal ảnh ra Locket Widget
```

#### Bước 1: `place_list_screen.dart` [Màn liên thông 1: Khám phá & Tìm kiếm]
- **Chức năng:** Hiển thị danh sách các địa điểm du lịch dưới dạng thẻ (Cards) sinh động. Có thanh tìm kiếm theo tên và danh sách Chip danh mục (Di tích, Văn hóa, Ẩm thực...).
- **Nút Bookmark:** Cho phép người dùng bấm lưu để tải về đọc Offline thông qua `place_controller`.
- **Hành động chuyển tiếp:** Khi người dùng chạm vào một địa điểm bất kỳ, màn hình sẽ **đóng gói đối tượng `PlaceModel` và điều hướng sang Màn hình 2 (`place_detail_screen`)**.

#### Bước 2: `place_detail_screen.dart` [Màn liên thông 2: Chi tiết địa điểm & Bắt đầu Check-in]
- **Chức năng:** Nhận `PlaceModel` từ Màn 1 để hiển thị hình ảnh tiêu biểu, tọa độ chuẩn, mô tả chi tiết và các đánh giá đã xác minh trước đó.
- **Hành động chuyển tiếp:** Tại chân trang có nút bấm nổi bật **"Bắt đầu Check-in Chuyến đi"**. Khi bấm nút, hệ thống kiểm tra nếu đang có chuyến đi chưa hoàn tất (theo PBR-013 trong `visit_controller`) thì cảnh báo; nếu hợp lệ, lập tức điều hướng sang Màn hình 3 (`gps_checkin_screen`) kèm đối tượng `PlaceModel`.

#### Bước 3: `gps_checkin_screen.dart` [Màn liên thông 3: Xác thực vị trí GPS & Check-out]
- **Chức năng:** Hiển thị giao diện radar quét tọa độ GPS thực tế. Gọi `GpsService` để lấy vị trí hiện tại và kiểm tra Anti-Fake GPS.
- **Thực thi quy tắc:** Hiển thị khoảng cách trực tiếp tính theo Haversine tới địa điểm. Nếu khoảng cách $\le 200m$ (PBR-017), hiển thị trạng thái xanh lá: *"Bạn đang ở đúng địa điểm!"*.
- **Hành động Check-out & Chuyển tiếp:** Người dùng bấm nút **"Xác nhận Check-out"**. Controller ghi nhận thời gian hợp lệ (PBR-014), tạo ra đối tượng `verifiedVisit` với cờ `isVerified = true` lưu vào State và tự động chuyển tiếp người dùng sang Màn hình 4 (`postcard_studio_screen`).

#### Bước 4: `postcard_studio_screen.dart` [Màn liên thông 4: Chụp ảnh 360° & Thiết kế Postcard]
- **Chức năng:** Studio sáng tạo nội dung kỷ niệm chuyến đi:
  - Cho phép chụp ảnh mới tại địa điểm hoặc chuyển sang chế độ ảnh toàn cảnh **360° Panorama** (sử dụng cảm biến xoay máy).
  - Tự động đóng dấu **Tem GPS xác thực** lấy trực tiếp từ `verifiedVisit` (Hiển thị thời gian thực, Tọa độ GPS chuẩn xác, Tên địa điểm).
  - Cho phép gắn thêm nhãn dán sticker du lịch và khung bưu thiếp lưu niệm.
- **Hành động Chuyển tiếp:** Khi bấm **"Hoàn thành Bưu thiếp"**, hệ thống xuất khung hình thành file ảnh `postcardFile` thông qua `studio_controller` và chuyển tiếp thẳng sang Màn hình 5 (`publish_review_screen`).

#### Bước 5: `publish_review_screen.dart` [Màn liên thông 5: Đăng Review Xác thực & Gửi Locket]
- **Chức năng:** Màn hình kết thúc chu trình trải nghiệm:
  - Hiển thị huy hiệu **"Đánh giá đã được xác thực qua GPS thực địa"** dựa trên `verifiedVisit.isVerified == true` (thỏa mãn PBR-023, PBR-024).
  - Xem trước bức ảnh Postcard tuyệt đẹp vừa thiết kế tại Màn 4.
  - Cho phép chọn số sao đánh giá (1-5 sao theo PBR-025) và nhập lời cảm nhận.
  - Tùy chọn bật công tắc: **"Đồng thời bắn ảnh lên Locket Widget của bạn bè"**.
- **Hành động Hoàn tất:** Người dùng bấm **"Đăng bài & Chia sẻ Locket"**. `ReviewLocketController` thực hiện gọi API lưu bài, tự động cộng `trustScore` cho người dùng, gửi tín hiệu cập nhật Home Widget và điều hướng đưa người dùng trở lại Màn hình chính.

---

## 4. Quy ước Xây dựng Giao diện (UI/UX Best Practices)
1. **Phân tách Widget nhỏ:** Tách các khối giao diện phức tạp thành các Widget con độc lập để tối ưu hóa hiệu năng render (sử dụng `const` constructor tối đa).
2. **Phản hồi trạng thái tức thì:** Luôn hiển thị Skeleton/Shimmer hoặc vòng xoay tải dữ liệu khi Controller đang trong trạng thái `isLoading = true`.
3. **Thông báo lỗi thân thiện:** Hiển thị SnackBar hoặc Dialog thông báo lỗi rõ ràng khi vi phạm các quy tắc nghiệp vụ (ví dụ: khoảng cách GPS quá xa hoặc gian lận vị trí).
