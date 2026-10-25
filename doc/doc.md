# TÀI LIỆU ĐẶC TẢ KIẾN TRÚC DỰ ÁN & CHECKLIST TRIỂN KHAI
## ĐỀ TÀI: TRAVEL TRUST NETWORK MOBILE
**Môn học:** PRM393 - Lập trình Di động  
**Nhóm sinh viên thực hiện:**
- Phạm Hoàng Nam
- Hầu Văn Hòa
- Vương Thu Huyền

---

## MỤC LỤC
1. [Tổng quan Đề tài & Đối chiếu Yêu cầu Môn học](#1-tổng-quan-đề-tài--đối-chiếu-yêu-cầu-môn-học)
2. [Sơ đồ Luồng hoạt động 4 Tầng](#2-sơ-đồ-luồng-hoạt-động-4-tầng)
3. [Cấu trúc Thư mục & Chi tiết từng Package (lib/)](#3-cấu-trúc-thư-mục--chi-tiết-từng-package-lib)
4. [Chuỗi 5 Màn hình Nghiệp vụ Liên thông & Dòng chảy Dữ liệu](#4-chuỗi-5-màn-hình-nghiệp-vụ-liên-thông--dòng-chảy-dữ-liệu)
5. [Đặc tả Business Rules (PBR) phức tạp](#5-đặc-tả-business-rules-pbr-phức-tạp)
6. [Thiết kế Cơ sở Dữ liệu SQLite Local (Yêu cầu 1)](#6-thiết-kế-cơ-sở-dữ-liệu-sqlite-local-yêu-cầu-1)
7. [Bảng Checklist Toàn bộ Công việc cần làm](#7-bảng-checklist-toàn-bộ-công-việc-cần-làm)
8. [Quy chuẩn Commit Code (Git Conventions)](#8-quy-chuẩn-commit-code-git-conventions)
9. [Hướng dẫn Clone Repo & Chạy Dự án Không Bị Lỗi](#9-hướng-dẫn-clone-repo--chạy-dự-án-không-bị-lỗi)

---

## 1. TỔNG QUAN ĐỀ TÀI & ĐỐI CHIẾU YÊU CẦU MÔN HỌC

### 1.1. Đề tài
**Travel Trust Network** là ứng dụng du lịch xã hội dựa trên niềm tin thực tế, giải quyết vấn nạn "review ảo" và đem lại trải nghiệm tương tác trực quan:
- **Xác thực du lịch thực địa qua GPS:** Bắt buộc người dùng có mặt tại địa điểm ($\le 200m$) và không giả lập GPS thì mới được đánh giá có nhãn **Verified Review**.
- **Clone tính năng Locket Widget:** Nhận tín hiệu ngầm qua Firebase Cloud Messaging (FCM) ngay cả khi tắt ứng dụng, tự động hiển thị ảnh bạn bè gửi ra Widget ngoài Launcher.
- **Xử lý ảnh Postcard đa lớp:** Cho phép xếp các lớp hiệu ứng (Khung kỷ niệm, nhãn dán du lịch, đóng dấu tem GPS thực tế).
- **Trải nghiệm ảnh động 360° Panorama:** Xem ảnh địa điểm theo góc xoay trực quan dựa trên cảm biến con quay hồi chuyển (`sensors_plus`).

### 1.2. Bảng Đối chiếu 5 Yêu cầu Tối thiểu của Môn học

| Yêu cầu của Giảng viên | Cách Dự án Đáp ứng Triệt để |
|:---|:---|
| **Yêu cầu 1:** Tài liệu Design Database Local + đặc tả API và mapping dữ liệu UI. | Thiết kế 3 bảng SQLite bằng thư viện `drift` (`cached_places`, `draft_visits`, `locket_history`). Cấu hình `dio` gọi API Java Microservices, mapping 2 chiều qua `models/`. |
| **Yêu cầu 2:** Đăng nhập/Đăng xuất Gmail + Màn hình Profile. | Tích hợp `google_sign_in` lấy thông tin Google, màn hình Profile hiển thị Avatar, Email, thống kê lịch sử điểm uy tín (Trust Score). |
| **Yêu cầu 3:** Tối thiểu 5 màn hình liên thông + Menu điều hướng (ít nhất 3 mục) + Layout cân đối + Nghiệp vụ có Business Rules + Quản lý State. | - Chuỗi 5 màn hình liên thông (Khám phá $\rightarrow$ Chi tiết $\rightarrow$ Check-in GPS $\rightarrow$ Postcard Studio $\rightarrow$ Review & Locket).<br>- `MainLayout` gồm Top AppBar (Avatar, Tên, Huy hiệu Trust Score), Bottom Navigation Bar (4 tab), Side Drawer Menu.<br>- Business Rules: PBR-013, PBR-014, PBR-017, PBR-023, PBR-024, PBR-025.<br>- State Management bằng `flutter_riverpod`. |
| **Yêu cầu 4:** Code, commit, message chuẩn mực. | Tuân thủ tuyệt đối chuẩn Conventional Commits (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`) và Git Flow. |
| **Yêu cầu 5:** Khả năng tùy biến theo yêu cầu giảng viên. | Kiến trúc phân tách rõ ràng; toàn bộ Business Rules đặt tại `controllers/`, dễ dàng sửa đổi tham số (ví dụ đổi bán kính GPS từ 200m sang 500m) mà không ảnh hưởng giao diện hay tầng dịch vụ. |

---

## 2. SƠ ĐỒ LUỒNG HOẠT ĐỘNG 4 TẦNG

Ứng dụng được tổ chức nghiêm ngặt theo 4 tầng phân lập trách nhiệm:

```
┌────────────────────────────────────────────────────────┐
│                   VIEWS (Giao diện)                    │
│   Hiển thị màn hình, bắt sự kiện chạm/vuốt, lắng nghe  │
│   trạng thái (State) từ Controller để vẽ lại giao diện │
└───────────────────────────┬────────────────────────────┘
                            │ Người dùng thao tác -> Gọi hàm
                            ▼
┌────────────────────────────────────────────────────────┐
│             CONTROLLERS (Trạng thái & Nghiệp vụ)        │
│   Kiểm tra Business Rules (GPS <= 200m, Check-out),    │
│   lưu giữ State chuyển giữa các màn hình, gọi Services │
└───────────────────────────┬────────────────────────────┘
                            │ Yêu cầu dữ liệu / phần cứng
                            ▼
┌────────────────────────────────────────────────────────┐
│             SERVICES (Xử lý Kỹ thuật & Hạ tầng)        │
│   Gọi REST API (Dio), Đọc/Ghi SQLite Local, Lấy GPS,   │
│   xử lý ảnh Isolate, cập nhật Home Widget ngoài Launcher│
└───────────────────────────┬────────────────────────────┘
                            │ Chuyển đổi thành Object chuẩn
                            ▼
┌────────────────────────────────────────────────────────┐
│                    MODELS (Dữ liệu)                    │
│   Chứa Data Classes thuần túy, hàm fromJson, toJson,   │
│   toMap, fromMap dùng chung cho API, SQLite và View    │
└────────────────────────────────────────────────────────┘
```

---

## 3. CẤU TRÚC THƯ MỤC & CHI TIẾT TỪNG PACKAGE (`lib/`)

```
lib/
├── main.dart                          # Khởi tạo App, cấu hình Riverpod ProviderScope, Router & FCM Background Handler
│
├── models/                            # PACKAGE 1: ĐỊNH NGHĨA THỰC THỂ DỮ LIỆU
│   ├── hd.md                          # Hướng dẫn chi tiết package models
│   ├── user_model.dart                # User profile, Google ID, Trust Score, JWT Token
│   ├── place_model.dart               # Thông tin địa điểm, tọa độ lat/lng chuẩn, điểm đánh giá, cờ offline
│   ├── visit_model.dart               # Phiên chuyến đi, giờ check-in/out, GPS thực tế, cờ isVerified
│   ├── review_model.dart              # Đánh giá 1-5 sao, nội dung cảm nhận, đường dẫn ảnh Postcard
│   └── locket_item_model.dart         # Dữ liệu ảnh nhận từ bạn bè để nạp ra Home Widget
│
├── services/                          # PACKAGE 2: KỸ THUẬT NỀN, DATABASE & PHẦN CỨNG
│   ├── hd.md                          # Hướng dẫn chi tiết package services
│   ├── api_service.dart               # Cấu hình Dio, đính kèm JWT, Interceptor tự Refresh Token khi 401
│   ├── local_db_service.dart          # Quản trị SQLite bằng sqflite (3 bảng: cached_places, draft_visits, locket_history)
│   ├── gps_service.dart               # Geolocator, chặn Fake GPS (isMocked), công thức toán học Haversine
│   ├── image_studio_service.dart      # Xuất ảnh RepaintBoundary, tích hợp panorama_viewer & xử lý Isolate.run
│   └── locket_widget_service.dart     # Nhận FCM ngầm @pragma('vm:entry-point'), cập nhật ảnh ra HomeWidget
│
├── controllers/                       # PACKAGE 3: QUẢN TRỊ STATE & BUSINESS RULES
│   ├── hd.md                          # Hướng dẫn chi tiết package controllers
│   ├── auth_controller.dart           # Đăng nhập Google, quản lý currentUser, tăng giảm Trust Score, logout
│   ├── place_controller.dart          # Tìm kiếm, lọc danh mục, lưu/xóa địa điểm Bookmark vào SQLite
│   ├── visit_controller.dart          # Thực thi PBR-013, PBR-017, PBR-014; tạo và giữ verifiedVisit
│   ├── studio_controller.dart         # Quản lý lớp Layers (Sticker, Khung, Tem GPS), cảm biến sensors_plus xoay 360°, xuất postcardFile
│   └── review_locket_controller.dart  # Thực thi PBR-023, PBR-024, PBR-025; đăng bài đánh giá & bắn signal Locket
│
└── views/                             # PACKAGE 4: GIAO DIỆN & MENU ĐIỀU HƯỚNG
    ├── hd.md                          # Hướng dẫn chi tiết package views
    ├── widgets/                       # Các widget dùng chung
    │   ├── main_layout.dart           # Khung chung: Top AppBar + BottomNav 4 tab + Drawer bên cạnh
    │   └── trust_score_badge.dart     # Huy hiệu hiển thị điểm uy tín đổi màu theo cấp bậc
    ├── login_screen.dart              # Màn hình Đăng nhập bằng Gmail (Google Sign-In)
    ├── profile_screen.dart            # Màn hình Hồ sơ cá nhân, lịch sử Trust Score & Đăng xuất
    ├── place_list_screen.dart         # [Màn liên thông 1] Khám phá & Tìm kiếm địa điểm, tích hợp bản đồ flutter_map
    ├── place_detail_screen.dart       # [Màn liên thông 2] Chi tiết địa điểm & Nút bấm Check-in
    ├── gps_checkin_screen.dart        # [Màn liên thông 3] Radar quét GPS thực địa & Check-out chuyến đi
    ├── postcard_studio_screen.dart    # [Màn liên thông 4] Trải nghiệm 360° với panorama_viewer & Ghép lớp hiệu ứng Postcard
    └── publish_review_screen.dart     # [Màn liên thông 5] Đăng Review xác minh & Bắn ảnh Locket Widget
```

### Thư mục Tài nguyên tĩnh (`assets/`)
```
assets/
├── images/                            # Ảnh đại diện mẫu, logo Travel Trust Network
├── frames/                            # Khung viền bưu thiếp du lịch (Vintage, Retro, Hiện đại)
└── stickers/                          # Nhãn dán trang trí (Tem địa danh, Cờ, Check-in icon)
```

---

## 4. CHUỖI 5 MÀN HÌNH NGHIỆP VỤ LIÊN THÔNG & DÒNG CHẢY DỮ LIỆU

### Sơ đồ luồng liên thông 5 bước
```
[Màn 1: place_list_screen]
          │
          │  Truyền đối tượng: PlaceModel
          ▼
[Màn 2: place_detail_screen]
          │
          │  Truyền đối tượng: PlaceModel & Kích hoạt Check-in
          ▼
[Màn 3: gps_checkin_screen]
          │
          │  Kiểm tra GPS Haversine <= 200m -> Check-out -> Tạo verifiedVisit (VisitModel)
          ▼
[Màn 4: postcard_studio_screen]
          │
          │  Đóng dấu Tem GPS từ verifiedVisit -> Chụp 360° -> Xuất postcardFile (.png)
          ▼
[Màn 5: publish_review_screen]
          │
          └──► Thẩm định verifiedVisit.isVerified == true -> Đăng bài -> Tăng Trust Score & Bắn Locket
```

### Chi tiết Dữ liệu Chuyển giao:
1. **Từ Màn 1 sang Màn 2:** Khi bấm vào một địa điểm bất kỳ trong danh sách, `PlaceModel` được gửi kèm qua tham số điều hướng (`context.push('/place-detail', extra: place)`).
2. **Từ Màn 2 sang Màn 3:** Màn 2 hiển thị toàn bộ thông tin chi tiết. Khi bấm "Bắt đầu Check-in", gọi `VisitController.startCheckIn(place)`. Hệ thống kiểm tra điều kiện rồi chuyển sang Màn 3.
3. **Từ Màn 3 sang Màn 4:** Màn 3 quét vị trí GPS. Khi người dùng bấm "Check-out chuyến đi", `VisitController.completeCheckOut()` xác nhận khoảng cách $\le 200m$, đóng dấu `isVerified = true` và sinh ra đối tượng `verifiedVisit` lưu tại Controller, sau đó chuyển sang Màn 4.
4. **Từ Màn 4 sang Màn 5:** Màn 4 lấy thông tin từ `verifiedVisit` để in Tem GPS lên bức ảnh, người dùng gắn thêm sticker/khung. Khi bấm "Hoàn thành Postcard", `StudioController` xuất file ảnh hoàn chỉnh `postcardFile` và điều hướng sang Màn 5.
5. **Tại Màn 5:** Tiếp nhận cả `verifiedVisit` và `postcardFile`. Sau khi người dùng chọn số sao (1-5 sao) và nhập nhận xét, `ReviewLocketController` gọi API xuất bản bài đánh giá, tự động cộng `+10 điểm` vào `AuthController.currentUser.trustScore`, đồng thời cập nhật Home Widget.

---

## 5. ĐẶC TẢ BUSINESS RULES (PBR) PHỨC TẠP

| Mã Quy tắc | Tên Quy tắc | Điều kiện Kiểm tra | Xử lý khi Vi phạm | Xử lý khi Hợp lệ |
|:---:|:---|:---|:---|:---|
| **PBR-013** | Không Check-in Trùng lặp | `activeVisit != null` khi bấm Check-in nơi mới | Báo lỗi: *"Bạn đang có chuyến đi chưa hoàn tất tại [Địa điểm cũ]. Vui lòng Check-out trước."* | Bắt đầu phiên chuyến đi mới. |
| **PBR-017** | Giới hạn Bán kính GPS Thực tế | $\Delta d \le 200.0\text{ m}$ và `position.isMocked == false` | Từ chối xác thực. Hiển thị thông báo: *"Vị trí quá xa (cách ...m) hoặc phát hiện phần mềm giả lập GPS."* | Chấp thuận Check-in thực địa. |
| **PBR-014** | Hợp lệ hóa Thời gian Check-out | `checkOutTime > checkInTime` | Không cho phép Check-out trước thời điểm bắt đầu. | Gán `isVerified = true`, lưu vào State và bảng `draft_visits`. |
| **PBR-023** | Bắt buộc Xác thực Thực địa | `verifiedVisit.isVerified == true` | Nút "Đăng bài" bị vô hiệu hóa; chặn tạo Review ảo. | Mở khóa form đăng bài. |
| **PBR-025** | Khoảng Đánh giá Hợp lệ | $1 \le \text{rating} \le 5$ | Thông báo yêu cầu người dùng chọn từ 1 đến 5 sao. | Gửi đánh giá lên API Backend. |

---

## 6. THIẾT KẾ CƠ SỞ DỮ LIỆU SQLITE LOCAL (YÊU CẦU 1)

Dự án sử dụng thư viện `sqflite` (SQLite Engine nguyên bản trên Flutter) để tạo và truy vấn 3 bảng đáp ứng đúng nghiệp vụ lưu trữ offline và Widget:

### Bảng 1: `cached_places` (Địa điểm yêu thích & Offline)
* **Mục đích:** Lưu trữ các địa điểm người dùng đánh dấu Bookmark để xem hướng dẫn, thông tin khi mất mạng.
* **Cấu trúc:**
  - `id` (TEXT, PRIMARY KEY): Mã định danh địa điểm.
  - `name` (TEXT): Tên địa điểm.
  - `category` (TEXT): Danh mục (Di tích, Ẩm thực...).
  - `address` (TEXT): Địa chỉ chi tiết.
  - `latitude` (REAL), `longitude` (REAL): Tọa độ chuẩn của địa điểm.
  - `averageRating` (REAL): Điểm đánh giá trung bình.
  - `verifiedReviewCount` (INTEGER): Số lượt đánh giá xác thực.
  - `isSaved` (INTEGER): Cờ đánh dấu đã lưu (1: đã lưu, 0: chưa lưu).

### Bảng 2: `draft_visits` (Chuyến đi tạm thời khi mất mạng)
* **Mục đích:** Lưu trữ phiên check-in GPS ngoại tuyến tại thực địa khi không có kết nối 4G/Wifi. Tự động đồng bộ lên Java Microservices khi có mạng lại.
* **Cấu trúc:**
  - `visitId` (TEXT, PRIMARY KEY): Mã chuyến đi (UUID).
  - `placeId` (TEXT): Mã địa điểm.
  - `userId` (TEXT): Mã người dùng.
  - `checkInTime` (TEXT), `checkOutTime` (TEXT): Chuỗi ISO8601 thời gian.
  - `userLat` (REAL), `userLng` (REAL): Tọa độ GPS thực tế.
  - `distanceMeters` (REAL): Khoảng cách Haversine tính toán được.
  - `isVerified` (INTEGER): Cờ xác nhận GPS hợp lệ (1: hợp lệ, 0: không hợp lệ).

### Bảng 3: `locket_history` (Lịch sử ảnh Locket Widget)
* **Mục đích:** Lưu các bức ảnh bạn bè gửi tới để nạp dữ liệu cho Home Widget ngoài Launcher ngay cả khi máy không có kết nối mạng.
* **Cấu trúc:**
  - `id` (TEXT, PRIMARY KEY): Mã tin nhắn ảnh.
  - `senderName` (TEXT): Tên người bạn gửi.
  - `senderAvatar` (TEXT): Avatar người gửi.
  - `imageUrl` (TEXT): Đường dẫn ảnh gốc trên Cloud.
  - `localFilePath` (TEXT): Đường dẫn file ảnh đã tải về lưu trong bộ nhớ máy.
  - `caption` (TEXT): Lời chú thích ảnh.
  - `receivedAt` (TEXT): Thời điểm nhận ảnh.

---

## 7. BẢNG CHECKLIST TOÀN BỘ CÔNG VIỆC CẦN LÀM

| Giai đoạn | Hạng mục công việc | Mô tả chi tiết | Người phụ trách | Trạng thái |
|:---:|:---|:---|:---:|:---:|
| **1. Khởi tạo** | Bổ sung dependencies | Cập nhật `image_picker`, `flutter_rating_bar`, `cached_network_image`, `intl`, `uuid`, `permission_handler` vào `pubspec.yaml` | Nam |  Hoàn thành |
| **1. Khởi tạo** | Tài liệu kiến trúc | Viết tài liệu `doc/doc.md` và các file `hd.md` cho từng package | Nhóm |  Hoàn thành |
| **2. Tầng Models** | Khởi tạo 5 Model | Tạo `user_model.dart`, `place_model.dart`, `visit_model.dart`, `review_model.dart`, `locket_item_model.dart` kèm `fromJson/toJson/toMap` | Huyền | 🔲 Chưa bắt đầu |
| **3. Tầng Services**| Cấu hình `ApiService` | Cấu hình Dio, Interceptor đính kèm JWT, xử lý 401 tự động Refresh Token | Hòa | 🔲 Chưa bắt đầu |
| **3. Tầng Services**| Xây dựng `LocalDbService` | Viết code khởi tạo 3 bảng SQLite bằng Drift/Sqflite, các hàm CRUD dữ liệu | Hòa | 🔲 Chưa bắt đầu |
| **3. Tầng Services**| Xây dựng `GpsService` | Xin quyền, lấy vị trí, kiểm tra `isMocked`, viết hàm Haversine tính khoảng cách | Nam | 🔲 Chưa bắt đầu |
| **3. Tầng Services**| Xây dựng `ImageStudioService` | Chụp `RepaintBoundary` xuất ảnh .png, xử lý ảnh 360°/chuỗi ảnh trên `Isolate.run` | Nam | 🔲 Chưa bắt đầu |
| **3. Tầng Services**| Xây dựng `LocketWidgetService`| Đăng ký `@pragma('vm:entry-point')` với FCM, tích hợp `HomeWidget.updateWidget()` | Nam | 🔲 Chưa bắt đầu |
| **4. Controllers** | `AuthController` | Đăng nhập Google, quản trị `currentUser`, cập nhật `trustScore`, hàm `logout` | Hòa | 🔲 Chưa bắt đầu |
| **4. Controllers** | `PlaceController` | Quản lý danh sách địa điểm, tìm kiếm, lọc danh mục, lưu/xóa Bookmark offline | Huyền | 🔲 Chưa bắt đầu |
| **4. Controllers** | `VisitController` | Thực thi **PBR-013** (ngăn check-in trùng), **PBR-017** (GPS $\le 200m$), **PBR-014** (check-out) | Nam | 🔲 Chưa bắt đầu |
| **4. Controllers** | `StudioController` | Quản lý Layers (Sticker, Khung, Tem GPS), cảm biến `sensors_plus`, xuất file ảnh | Nam | 🔲 Chưa bắt đầu |
| **4. Controllers** | `ReviewLocketController` | Thực thi **PBR-023**, **PBR-024**, **PBR-025**; đăng Review & bắn Locket Push | Huyền | 🔲 Chưa bắt đầu |
| **5. Tầng Views** | Khung giao diện chung | Tạo `MainLayout` (Top AppBar, BottomNav 4 tab, Drawer) & `TrustScoreBadge` | Huyền | 🔲 Chưa bắt đầu |
| **5. Tầng Views** | Màn hình độc lập | Viết `login_screen.dart` (Google Sign-In) và `profile_screen.dart` | Hòa | 🔲 Chưa bắt đầu |
| **5. Tầng Views** | Màn liên thông 1 & 2 | Viết `place_list_screen.dart` và `place_detail_screen.dart` | Huyền | 🔲 Chưa bắt đầu |
| **5. Tầng Views** | Màn liên thông 3 | Viết `gps_checkin_screen.dart` (Radar GPS, khoảng cách Haversine, nút Check-out) | Nam | 🔲 Chưa bắt đầu |
| **5. Tầng Views** | Màn liên thông 4 | Viết `postcard_studio_screen.dart` (Giao diện 360°, ghép sticker, tem GPS) | Nam | 🔲 Chưa bắt đầu |
| **5. Tầng Views** | Màn liên thông 5 | Viết `publish_review_screen.dart` (Rating 1-5 sao, xem trước Postcard, gửi Locket) | Hòa | 🔲 Chưa bắt đầu |
| **6. Kiểm thử** | Test liên thông 5 màn | Chạy thử nghiệm toàn bộ luồng từ Bước 1 đến Bước 5 trên máy thật/máy ảo | Nhóm | 🔲 Chưa bắt đầu |
| **6. Kiểm thử** | Test ngoại tuyến (Offline) | Tắt mạng, kiểm tra xem địa điểm đã lưu trong SQLite và check-in nháp | Nhóm | 🔲 Chưa bắt đầu |

---

## 8. QUY CHUẨN COMMIT CODE (GIT CONVENTIONS)

Để đáp ứng **Yêu cầu 4: Code, commit, message chuẩn mực**, toàn bộ thành viên trong nhóm phải tuân thủ nghiêm ngặt quy chuẩn **Conventional Commits**:

### 8.1. Cấu trúc Message Commit Chuẩn
```
<type>(<scope>): <mô tả ngắn gọn về thay đổi bằng tiếng Việt hoặc tiếng Anh>

[Tùy chọn: Mô tả chi tiết lý do và ngữ cảnh thay đổi]
```

### 8.2. Danh sách các `<type>` hợp lệ:
* `feat`: Thêm tính năng mới (Feature) cho người dùng.
* `fix`: Sửa lỗi (Bug fix).
* `docs`: Thêm hoặc sửa đổi tài liệu (README, doc.md, hd.md...).
* `style`: Thay đổi giao diện, định dạng, khoảng trắng, không ảnh hưởng logic code.
* `refactor`: Tái cấu trúc mã nguồn, tối ưu hóa code mà không thay đổi tính năng.
* `test`: Thêm mới hoặc chỉnh sửa các bài kiểm thử (Unit test, Widget test).
* `chore`: Cập nhật cấu hình build, dependencies trong `pubspec.yaml`, gradle...

### 8.3. Bảng Ví dụ Commit Đúng vs. Sai

| Ví dụ Commit Đúng Chuẩn  | Lý do đúng | Ví dụ Sai Không Được Phép  |
|:---|:---|:---|
| `feat(gps): implement haversine distance and anti-mock gps check` | Nêu rõ loại `feat`, phạm vi `gps` và hành động cụ thể. | `update code` (Quá mơ hồ) |
| `feat(database): initialize drift local db with 3 tables` | Rõ ràng tính năng tạo SQLite Database. | `fix bug` (Không biết sửa bug gì) |
| `fix(auth): handle refresh token loop on 401 status code` | Xác định rõ lỗi được khắc phục tại module `auth`. | `nam push code` (Không mang tính chuyên nghiệp) |
| `docs(architecture): add project doc.md and package hd.md` | Đúng loại tài liệu `docs`. | `done màn 1` (Viết tắt, thiếu ngữ cảnh) |

---

## 9. HƯỚNG DẪN CLONE REPO & CHẠY DỰ ÁN KHÔNG BỊ LỖI

Khi một thành viên mới clone dự án về máy, hoặc khi kéo code mới từ Git, hãy thực hiện **chính xác theo thứ tự các bước sau** để không gặp lỗi thiếu thư viện hay lỗi xung đột:

### Bước 1: Clone Repository về máy
```bash
git clone https://github.com/devnam1210/travel-trust-network-mobile.git
cd travel-trust-network-mobile
```

### Bước 2: Tải toàn bộ thư viện phụ thuộc (Dependencies)
```bash
flutter pub get
```
> [!NOTE]
> Lệnh này sẽ đọc `pubspec.yaml` và tải chính xác tất cả các thư viện cần thiết vào máy.

### Bước 3: Chạy Code Generator (Cực kỳ quan trọng với SQLite Drift / Riverpod)
Do dự án sử dụng `drift` và `build_runner` để sinh mã nguồn tự động cho Database và Providers, bạn **bắt buộc** phải chạy lệnh sau:
```bash
dart run build_runner build --delete-conflicting-outputs
```
*(Lệnh này giúp tự động tạo ra các file `.g.dart` cho database mà không bao giờ bị lỗi thiếu class).*

### Bước 4: Kiểm tra Môi trường Flutter & Android
```bash
flutter doctor -v
```
Đảm bảo các mục sau hiển thị dấu tích xanh:
- Flutter & Dart SDK
- Android toolchain (Android SDK Command-line Tools)
- Connected device (Có máy ảo Emulator hoặc máy thật cắm cáp USB Debugging).

### Bước 5: Cấu hình Khóa & Quyền Phần cứng (Một lần duy nhất)
1. **Android Permissions:** Mở file `android/app/src/main/AndroidManifest.xml` và đảm bảo đã khai báo các quyền:
   - `<uses-permission android:name="android.permission.INTERNET"/>`
   - `<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>`
   - `<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>`
   - `<uses-permission android:name="android.permission.CAMERA"/>`
   - `<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>`
2. **Google Services:** Đảm bảo file cấu hình `google-services.json` đã được đặt vào thư mục `android/app/` để Firebase và Google Sign-In hoạt động.

### Bước 6: Khởi chạy Ứng dụng
```bash
flutter run
```
Nhấn phím `r` trong terminal để Hot Reload hoặc `R` để Hot Restart trong quá trình lập trình.
