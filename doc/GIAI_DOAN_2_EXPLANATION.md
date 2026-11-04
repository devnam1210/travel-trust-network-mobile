# TÀI LIỆU GIẢI THÍCH MÃ NGUỒN - GIAI ĐOẠN 2
**Thành viên thực hiện:** Phạm Hoàng Nam  
**Phạm vi:** Màn hình Khám phá & Tìm kiếm (`ExploreScreen`), Màn hình Chi tiết địa điểm (`PlaceDetailScreen`) và Liên thông nghiệp vụ GPS  
**Công nghệ:** Flutter (Dart), Flutter Riverpod v3, CustomScrollView / Slivers, Debounce 500ms  

---

## 1. Mục tiêu của Giai đoạn 2
Giai đoạn 2 hiện thực hóa 2 màn hình nghiệp vụ trọng tâm trong hành trình trải nghiệm người dùng của Travel Trust Network:
1. **Màn hình Khám phá (`ExploreScreen`):**
   - Cho phép người dùng tìm kiếm địa điểm theo từ khóa (tên, địa chỉ) với kỹ thuật **Debounce 500ms**.
   - Lọc địa điểm theo danh mục (`CAMPUS`, `HERITAGE`, `NATURE`).
   - Xử lý đầy đủ 4 trạng thái UI chuẩn: **Loading**, **Empty**, **Error (kèm Retry)**, **Success**.
2. **Màn hình Chi tiết địa điểm (`PlaceDetailScreen`):**
   - Hiển thị thông tin toàn diện của địa điểm: ảnh bìa, danh mục, giờ mở cửa, mô tả, rating trung bình.
   - Thể hiện rõ **Quy chuẩn xác thực GPS (Server-side)**: Tọa độ chuẩn (`lat`, `lng`) và Bán kính cho phép check-in (`allowedRadiusM` m) tính bằng công thức Haversine.
   - Hiển thị danh sách các bài đánh giá đã xác minh (`ReviewItemCard`) kèm huy hiệu xác thực.
   - **Liên thông nghiệp vụ:** Nút cố định ở chân màn hình *"Check-in tại đây"* gọi trực tiếp sang `VisitScreen(placeId: place.id)` của thành viên Hầu Văn Hòa.

---

## 2. Cấu trúc tệp tin triển khai

```
travel_trust_network_mobile/lib/views/
├── places/
│   ├── explore_screen.dart       # [MỚI] Màn hình Khám phá, Tìm kiếm & Lọc
│   └── place_detail_screen.dart  # [MỚI] Màn hình Chi tiết địa điểm & Danh sách Review
└── main_navigation_screen.dart    # [CẬP NHẬT] Gắn ExploreScreen vào Tab 0 của thanh điều hướng
```

---

## 3. Phân tích chi tiết từng tệp mã nguồn

### 3.1. `lib/views/places/explore_screen.dart`

#### A. Provider quản lý danh sách địa điểm:
```dart
final placesListProvider = FutureProvider.autoDispose
    .family<List<PlaceSummaryModel>, ({String keyword, String category})>(
  (ref, query) async {
    final service = ref.watch(placeServiceProvider);
    return service.searchPlaces(
      keyword: query.keyword,
      category: query.category == 'ALL' ? null : query.category,
    );
  },
);
```
- **Kỹ thuật:** Sử dụng `FutureProvider.autoDispose.family` với tham số là một **Record Type** của Dart 3: `({String keyword, String category})`.
- **Lợi ích:** Khi người dùng thay đổi từ khóa hoặc danh mục, Riverpod tự động cache và tái sử dụng kết quả, đồng thời `autoDispose` tự động dọn dẹp bộ nhớ RAM khi màn hình không còn được hiển thị.

#### B. Kỹ thuật Debounce 500ms và Chống Race Condition:
Bám sát câu hỏi phản biện 5.6 trong tài liệu dự án:
```dart
Timer? _debounce;
int _requestVersion = 0;

void _onSearchChanged(String value) {
  _debounce?.cancel();
  final version = ++_requestVersion;
  _debounce = Timer(const Duration(milliseconds: 500), () {
    if (!mounted || version != _requestVersion) return;
    setState(() => _keyword = value.trim());
  });
}

@override
void dispose() {
  ++_requestVersion;
  _debounce?.cancel();
  _searchController.dispose();
  super.dispose();
}
```
* **Tại sao cần `_debounce`?** Người dùng gõ bàn phím liên tục sẽ không kích hoạt gọi API ngay mà chỉ gọi sau khi người dùng ngừng gõ 500ms $\rightarrow$ Giảm tải áp lực cho server.
* **Tại sao cần `_requestVersion`?** Khi mạng chập chờn, request gõ trước (phiên bản cũ) có thể phản hồi chậm hơn request gõ sau (phiên bản mới). Biến `_requestVersion` đảm bảo **kết quả cũ không bao giờ được phép ghi đè lên kết quả mới**.

#### C. Card hiển thị địa điểm (`_PlaceCard`):
- Bo góc 16px, đổ bóng nhẹ theo Material 3.
- Xử lý ảnh thông minh bằng `_resolveImageUrl`:
  ```dart
  Uri.parse(AppConfig.apiBaseUrl).resolve(rawUrl.trim()).toString()
  ```
  Tự động ghép nối đường dẫn tương đối `/uploads/...` với URL máy chủ Backend (`http://10.0.2.2:8080`), đồng thời giữ nguyên nếu đã là URL tuyệt đối (`http://...`).
- Hiển thị số sao trung bình màu vàng và số lượng review đã xác minh.

---

### 3.2. `lib/views/places/place_detail_screen.dart`

#### A. Provider lấy chi tiết địa điểm:
```dart
final placeDetailProvider =
    FutureProvider.autoDispose.family<PlaceDetailModel, String>(
  (ref, placeId) async {
    final service = ref.watch(placeServiceProvider);
    return service.getPlaceDetail(placeId);
  },
);
```
- Fetch dữ liệu từ API `GET /api/v1/places/{id}` theo `placeId` được truyền vào.

#### B. Giao diện cuộn mượt mà với `CustomScrollView` & `SliverAppBar`:
- Ảnh bìa địa điểm nằm trong `SliverAppBar` có hiệu ứng co giãn mượt mà khi cuộn trang (`expandedHeight: 250`, `pinned: true`).
- Nút Back hình tròn bán trong suốt cho phép quay lại danh sách tìm kiếm bất kỳ lúc nào mà không làm mất trạng thái tìm kiếm trước đó.

#### C. Card Thể hiện Quy chuẩn Xác thực GPS:
```dart
Text('• Tọa độ chuẩn: ${place.latitude.toStringAsFixed(4)}, ${place.longitude.toStringAsFixed(4)}')
Text('• Bán kính check-in hợp lệ: ≤ ${place.allowedRadiusM.toStringAsFixed(0)} mét (Công thức Haversine)')
```
- Minh chứng trực tiếp cho hội đồng phản biện thấy quy tắc nghiệp vụ: Server tính khoảng cách dựa trên tọa độ này. Bán kính của từng nơi là độc lập (ví dụ FPT Campus là 500m, địa điểm khác là 200m).

#### D. Danh sách Đánh giá đã xác minh (`_ReviewItemCard`):
- Mỗi item thể hiện: Avatar chữ cái đầu của tác giả, Tên người dùng, Ngày đánh giá định dạng `dd/MM/yyyy`, Số sao tương ứng (1–5 sao vàng).
- Nội dung nhận xét (`comment`).
- Ảnh Postcard kỷ niệm nếu bài đánh giá có đính kèm ảnh.
- Huy hiệu màu xanh lá: **"Đã xác thực chuyến đi qua GPS"** khẳng định tính tin cậy của bài đánh giá.

#### E. Liên thông nghiệp vụ (Cross-Screen Navigation):
Ở chân màn hình có thanh Bottom Bar cố định:
```dart
FilledButton.icon(
  icon: const Icon(Icons.gps_fixed_rounded),
  label: const Text('Check-in tại đây'),
  onPressed: () {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VisitScreen(placeId: place.id),
      ),
    );
  },
)
```
- Khi người dùng nhấn nút này, hệ thống sẽ mở ngay màn hình `VisitScreen` do Hầu Văn Hòa phụ trách với tham số `placeId` của địa điểm hiện tại.

---

### 3.3. Cập nhật `MainNavigationScreen`

Tại `lib/views/main_navigation_screen.dart`:
- Thay thế màn hình chờ bằng `const ExploreScreen()`.
- Bây giờ, khi mở ứng dụng ở Tab 1 (Khám phá), người dùng sẽ thấy ngay danh sách các địa điểm thực tế từ cơ sở dữ liệu `ttn_db`.

---

## 4. Kết quả Kiểm thử & Đánh giá

1. **Phân tích mã nguồn (`flutter analyze`):**
   ```
   Analyzing travel_trust_network_mobile...
   No issues found! (ran in 2.9s)
   ```
   * 100% không còn bất kỳ lỗi (0 errors) hay cảnh báo (0 warnings).
2. **Kiểm tra luồng liên thông:**
   - [x] Khám phá $\rightarrow$ Tìm kiếm từ khóa / Lọc danh mục $\rightarrow$ Dữ liệu phản hồi tức thì.
   - [x] Chọn địa điểm $\rightarrow$ Chi tiết địa điểm $\rightarrow$ Xem rating, tọa độ và review.
   - [x] Chi tiết $\rightarrow$ Nhấn "Check-in tại đây" $\rightarrow$ Mở `VisitScreen` đúng `placeId`.

---

## 5. Hướng dẫn Trình bày & Phản biện cho Phạm Hoàng Nam

Khi bảo vệ trước giảng viên:
1. **Trình diễn Tìm kiếm & Debounce:**
   - Gõ nhanh vào ô tìm kiếm từ khóa "FPT" hoặc "Hồ".
   - *Giải thích:* *"Em cài đặt cơ chế Debounce 500ms bằng Timer. Khi em gõ liên tục, app không gửi request rác lên server. Khi em dừng tay 500ms, request mới chính thức được gửi đi. Biến `_requestVersion` ngăn chặn hoàn toàn hiện tượng phản hồi cũ về muộn ghi đè lên kết quả mới."*
2. **Trình diễn Chi tiết địa điểm & Quy chuẩn vị trí:**
   - Mở địa điểm Campus Đại học FPT Hòa Lạc.
   - *Giải thích:* *"Mỗi địa điểm có bán kính riêng (`allowedRadiusM`). Ở FPT Campus bán kính là 500m, trong khi các nơi khác là 200m. Khi người dùng bấm nút 'Check-in tại đây', hệ thống sẽ truyền `placeId` sang màn hình GPS để server tính công thức Haversine."*
