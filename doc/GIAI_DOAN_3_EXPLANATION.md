# TÀI LIỆU GIẢI THÍCH MÃ NGUỒN - GIAI ĐOẠN 3
**Thành viên thực hiện:** Phạm Hoàng Nam  
**Phạm vi:** Màn hình Đăng đánh giá đã xác minh vị trí (`CreateReviewScreen`) và Liên thông nghiệp vụ Review - GPS - Profile  
**Công nghệ:** Flutter (Dart), Flutter Riverpod v3, Validation, Rating Bar, Đồng bộ State tự động  

---

## 1. Mục tiêu của Giai đoạn 3
Giai đoạn 3 hoàn thiện mắt xích quan trọng nhất trong đề tài **Travel Trust Network**:
> *"Chỉ người dùng thực sự có mặt tại địa điểm (đã Check-in và Check-out thành công qua GPS) mới được phép viết đánh giá để chống review ảo/spam."*

Khi người dùng gửi đánh giá thành công:
1. Backend kiểm tra điều kiện ràng buộc trong Database Transaction.
2. Cập nhật điểm sao trung bình (`averageRating`) và số lượng review (`verifiedReviewCount`) của địa điểm.
3. Cộng **+5 điểm uy tín** cho người dùng và ghi lịch sử vào `trust_score_logs`.
4. Mobile tự động **làm mới toàn bộ State** (Profile, Chi tiết địa điểm, Lịch sử chuyến đi) để phản ánh điểm số mới ngay lập tức.

---

## 2. Cấu trúc tệp tin triển khai

```
travel_trust_network_mobile/lib/views/
├── reviews/
│   └── create_review_screen.dart     # [MỚI] Màn hình Form Viết đánh giá xác minh
├── places/
│   └── place_detail_screen.dart      # [CẬP NHẬT] Thêm nút "Viết đánh giá" tại Bottom Bar
└── visits/
    └── visit_history_screen.dart     # [CẬP NHẬT] Thêm nút "Viết đánh giá (+5 điểm)" trên card chuyến đi VERIFIED
```

---

## 3. Phân tích chi tiết từng tệp mã nguồn

### 3.1. `lib/views/reviews/create_review_screen.dart`

#### A. Tham số đầu vào:
```dart
const CreateReviewScreen({
  super.key,
  required this.placeId,
  required this.placeName,
  this.initialVisitId,
});
```
- `placeId`, `placeName`: Thông tin địa điểm đang đánh giá.
- `initialVisitId`: Cho phép truyền sẵn mã chuyến đi (khi bấm "Viết đánh giá" từ màn hình Lịch sử chuyến đi).

#### B. Kiểm tra tính hợp lệ của Chuyến đi (Client-side Check):
Màn hình đọc danh sách chuyến đi từ `visitHistoryProvider`:
```dart
final verifiedVisits = visits
    .where((v) => v.placeId == widget.placeId && v.status == 'VERIFIED')
    .toList(growable: false);
```
- **Trường hợp 1 (Chưa có chuyến đi nào đạt VERIFIED):**
  - Hiển thị banner cảnh báo màu vàng: *"Quy chuẩn chống đánh giá ảo yêu cầu bạn phải Check-in và Check-out thực tế tại địa điểm này trước khi đăng nhận xét."*
  - Cung cấp nút bấm *"Check-in ngay"* $\rightarrow$ chuyển thẳng người dùng sang màn hình `VisitScreen`.
- **Trường hợp 2 (Đã có chuyến đi VERIFIED):**
  - Hiển thị `DropdownButtonFormField` liệt kê các chuyến đi hợp lệ kèm ngày giờ để người dùng chọn liên kết.

#### C. Bộ chọn sao đánh giá tương tác (Rating Bar):
- Sử dụng 5 icon `Icons.star_rounded` to bản (42px) cho phép chạm chọn từ 1 đến 5 sao.
- Kèm nhãn cảm xúc trực quan: `1: Rất tệ`, `2: Tạm được`, `3: Bình thường`, `4: Hài lòng`, `5: Tuyệt vời!`.

#### D. Validate nhận xét & Đính kèm ảnh:
- Ô `TextFormField` nhận xét: bắt buộc nhập, tối thiểu 5 ký tự.
- Ô nhập đường dẫn ảnh Postcard (hoặc `/uploads/...`).
- Checkbox cờ `is360Media` (đánh dấu nội dung đa phương tiện 360 độ).

#### E. Xử lý gửi Form & Đồng bộ State (Crucial Step):
```dart
await reviewService.createReview(...);

// Cập nhật lại các Provider liên quan
ref.invalidate(placeDetailProvider(widget.placeId));
ref.invalidate(visitHistoryProvider);
await ref.read(authControllerProvider.notifier).refreshProfile();
```
- `ref.invalidate(...)`: Đánh dấu dữ liệu của màn hình Chi tiết địa điểm và Lịch sử chuyến đi là đã cũ để Riverpod tự động kéo dữ liệu mới nhất khi người dùng quay lại.
- `refreshProfile()`: Gọi lại `GET /api/v1/users/me/profile` $\rightarrow$ Điểm uy tín của người dùng được cộng thêm **+5 điểm** và cập nhật ngay lên Tab Cá nhân!

#### F. Xử lý lỗi nghiệp vụ từ Backend:
```dart
if (e.code == 'DUPLICATE_REVIEW') {
  _error = 'Bạn đã từng gửi đánh giá cho địa điểm này rồi (Mỗi người dùng chỉ được đánh giá 1 lần).';
} else if (e.code == 'UNVERIFIED_VISIT') {
  _error = 'Chuyến đi này chưa hoàn tất Check-out (chưa đạt trạng thái VERIFIED).';
}
```
- Bắt chính xác mã lỗi nghiệp vụ của Backend để hiển thị thông báo rõ ràng, thân thiện với người dùng.

---

### 3.2. Cập nhật `lib/views/places/place_detail_screen.dart`

- Tại thanh Bottom Bar cố định:
  - Chia làm 2 nút cân xứng:
    1. **Nút "Viết đánh giá"** (`OutlinedButton`): Mở form `CreateReviewScreen`.
    2. **Nút "Check-in tại đây"** (`FilledButton`): Mở màn hình `VisitScreen`.
- Tại khu vực danh sách review: Nếu địa điểm chưa có bài đánh giá nào, bổ sung nút bấm *"Viết đánh giá ngay"* để kích thích người dùng chia sẻ trải nghiệm.

---

### 3.3. Cập nhật `lib/views/visits/visit_history_screen.dart`

- Trên mỗi thẻ chuyến đi trong lịch sử:
  - Nếu chuyến đi có trạng thái `VERIFIED` (đã Check-out):
    - Hiển thị thêm nút bấm: **"Viết đánh giá (+5 điểm)"**.
    - Nhấn vào nút sẽ mở thẳng `CreateReviewScreen` với `initialVisitId = visit.id`.
    - Đây là tính năng liên thông cực kỳ tiện lợi giúp người dùng sau khi hoàn tất chuyến đi có thể đánh giá ngay mà không cần tìm lại địa điểm.

---

## 4. Kết quả Kiểm thử & Đánh giá

1. **Phân tích mã nguồn tĩnh (`flutter analyze`):**
   ```
   Analyzing travel_trust_network_mobile...
   No issues found! (ran in 3.4s)
   ```
   * 100% không có lỗi (0 errors) hay cảnh báo (0 warnings).
2. **Kiểm tra luồng liên thông:**
   - [x] Từ Chi tiết địa điểm $\rightarrow$ Bấm "Viết đánh giá" $\rightarrow$ Mở Form $\rightarrow$ Chọn sao $\rightarrow$ Nhập comment $\rightarrow$ Gửi thành công $\rightarrow$ SnackBar thông báo +5 điểm.
   - [x] Từ Lịch sử chuyến đi $\rightarrow$ Chọn chuyến đi `VERIFIED` $\rightarrow$ Bấm "Viết đánh giá" $\rightarrow$ Mở Form đã tự điền sẵn chuyến đi tương ứng.
   - [x] Thử đánh giá lần 2 tại cùng 1 địa điểm $\rightarrow$ Bắt đúng lỗi `DUPLICATE_REVIEW` 409 từ Backend.

---

## 5. Hướng dẫn Trình bày & Phản biện cho Phạm Hoàng Nam

Khi bảo vệ trước hội đồng:
1. **Trình diễn luồng chống review ảo:**
   - Mở một địa điểm mà tài khoản chưa từng check-in.
   - Bấm nút "Viết đánh giá" $\rightarrow$ Chỉ vào banner cảnh báo màu vàng:
     - *"Thưa thầy cô, ứng dụng yêu cầu nghiêm ngặt người dùng phải có chuyến đi `VERIFIED` (đã Check-in và Check-out thành công qua GPS) mới được phép gửi đánh giá. Nếu chưa có, hệ thống sẽ chặn và hướng dẫn người dùng Check-in trước."*
2. **Trình diễn luồng hoàn tất và cộng điểm:**
   - Chọn một chuyến đi đã `VERIFIED`, đánh giá 5 sao kèm nhận xét.
   - Bấm "Đăng đánh giá" $\rightarrow$ Hiện SnackBar thông báo **+5 điểm uy tín**.
   - Mở sang Tab "Cá nhân" $\rightarrow$ Chỉ vào số điểm uy tín vừa được tăng thêm 5 điểm:
     - *"Sau khi đăng review, ứng dụng tự động gọi `refreshProfile()` và invalidate providers để cập nhật số điểm uy tín và hiển thị bài review mới ngay lập tức trên màn hình chi tiết."*
