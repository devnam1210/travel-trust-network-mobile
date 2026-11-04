# TÀI LIỆU GIẢI THÍCH MÃ NGUỒN - GIAI ĐOẠN 4
**Thành viên thực hiện:** Phạm Hoàng Nam  
**Phạm vi:** Cập nhật Hồ sơ cá nhân (`PUT /api/v1/users/me/profile`), Màn hình Chỉnh sửa hồ sơ (`EditProfileScreen`) & Hoàn thiện Đồng bộ State Profile  
**Công nghệ:** Flutter (Dart), Flutter Riverpod v3, Dio HTTP PUT, State Mutation  

---

## 1. Mục tiêu của Giai đoạn 4
Giai đoạn 4 hoàn thiện trọn vẹn quyền năng quản lý thông tin tài khoản người dùng:
1. **Nâng cấp tầng mạng (`ApiService`):** Mở rộng phương thức `put` để cho phép truyền JSON request body lên Backend (trước đây `put` chỉ hỗ trợ request không body cho API check-out).
2. **Tích hợp API Sửa hồ sơ (`AuthService` & `AuthController`):** Gọi `PUT /api/v1/users/me/profile` với các trường `fullName`, `bio`, `avatarUrl`.
3. **Màn hình Chỉnh sửa hồ sơ (`EditProfileScreen`):** Form trực quan có validate, preview ảnh đại diện thời gian thực.
4. **Tối ưu hóa `ProfileScreen`:**
   - Bổ sung nút icon Chỉnh sửa trên AppBar và nút bấm dưới phần tiểu sử.
   - Luôn ưu tiên hiển thị `state.user ?? user` để mọi biến động về điểm uy tín (từ Check-out +2 điểm hay Viết Review +5 điểm) và thông tin cá nhân đều được phản ánh ngay lập tức.

---

## 2. Cấu trúc tệp tin triển khai

```
travel_trust_network_mobile/lib/
├── services/
│   ├── api_service.dart          # [CẬP NHẬT] Hỗ trợ truyền data trong method put()
│   └── auth_service.dart         # [CẬP NHẬT] Bổ sung method updateProfile()
├── controllers/
│   └── auth_controller.dart      # [CẬP NHẬT] Bổ sung action updateProfile() và cập nhật AuthState
└── views/
    ├── profile/
    │   └── edit_profile_screen.dart # [MỚI] Màn hình Form Chỉnh sửa hồ sơ
    └── profile_screen.dart       # [CẬP NHẬT] Thêm nút chỉnh sửa & đồng bộ state người dùng
```

---

## 3. Phân tích chi tiết từng tệp mã nguồn

### 3.1. Nâng cấp `lib/services/api_service.dart`

Trước đây, phương thức `put` chỉ dùng cho check-out nên không nhận tham số dữ liệu:
```dart
// Code cũ:
Future<Map<String, dynamic>> put(String path) async => ...
```
Đã được nâng cấp để hỗ trợ cả request không body lẫn request có JSON body:
```dart
// Code mới:
Future<Map<String, dynamic>> put(
  String path, [
  Map<String, dynamic>? data,
]) async => _object(await _request(path, method: 'PUT', data: data));
```
- **Kỹ thuật:** Sử dụng `[Map<String, dynamic>? data]` (Optional positional parameter) giúp giữ tính tương thích ngược 100% với lời gọi check-out cũ của Hầu Văn Hòa, đồng thời phục vụ hoàn hảo cho API cập nhật profile.

---

### 3.2. Cập nhật `lib/services/auth_service.dart`

```dart
Future<UserModel> updateProfile({
  required String fullName,
  String? bio,
  String? avatarUrl,
}) async => UserModel.fromJson(
  await api.put('/users/me/profile', {
    'fullName': fullName,
    'bio': bio,
    'avatarUrl': avatarUrl,
  }),
);
```
- Ánh xạ trực tiếp với `UpdateProfileRequest.java` của Backend (`fullName`, `bio`, `avatarUrl`).
- Nhận phản hồi là `UserProfileResponse` mới nhất từ server và parse thành `UserModel`.

---

### 3.3. Cập nhật `lib/controllers/auth_controller.dart`

```dart
Future<void> updateProfile({
  required String fullName,
  String? bio,
  String? avatarUrl,
}) async {
  if (state.isBusy || state.status != AuthStatus.authenticated) return;
  final user = state.user;
  final token = _api.accessToken;
  state = AuthState(
    status: AuthStatus.authenticated,
    user: user,
    isBusy: true,
  );
  try {
    final updated = await _auth.updateProfile(
      fullName: fullName,
      bio: bio,
      avatarUrl: avatarUrl,
    );
    if (ref.mounted && token == _api.accessToken) {
      state = AuthState(status: AuthStatus.authenticated, user: updated);
    }
  } catch (error) { ... }
}
```
- Quản lý trạng thái bận (`isBusy = true`) để hiển thị loading indicator.
- Khi cập nhật thành công, gán đối tượng `UserModel` mới vào `state.user`. Toàn bộ các màn hình đang lắng nghe `authControllerProvider` (Tab Khám phá, Tab Cá nhân) sẽ tự động re-render dữ liệu mới mà không cần restart app.

---

### 3.4. `lib/views/profile/edit_profile_screen.dart`

* **Giao diện trực quan:**
  - **Avatar Preview:** Xem trước ảnh đại diện ngay khi người dùng nhập hoặc thay đổi URL ảnh (`onChanged: (_) => setState(() {})`). Nếu chưa có ảnh, tự động hiển thị chữ cái đầu tiên của tên người dùng.
  - **Họ và tên:** `TextFormField` bắt buộc nhập, giới hạn 150 ký tự (`maxLength: 150`).
  - **Tiểu sử (Bio):** `TextFormField` đa dòng (3 dòng), giới hạn 500 ký tự (`maxLength: 500`).
  - **Avatar URL:** Ô nhập link ảnh (`https://...` hoặc `/uploads/...`) kèm icon xem trước.
* **Xử lý sự kiện Lưu:**
  - Validate form $\rightarrow$ Bật loading $\rightarrow$ Gọi `controller.updateProfile(...)` $\rightarrow$ Hiện SnackBar thông báo thành công $\rightarrow$ Đóng màn hình (`Navigator.pop`).

---

### 3.5. Cập nhật `lib/views/profile_screen.dart`

1. **Hiển thị dữ liệu thời gian thực:**
   ```dart
   final currentUser = state.user ?? user;
   ```
   Thay vì đọc cứng từ `widget.user` truyền vào lúc khởi tạo, màn hình đọc trực tiếp từ `state.user` của Riverpod. Nhờ đó, bất cứ khi nào điểm uy tín thay đổi (+2 từ check-out, +5 từ review) hoặc thông tin cá nhân được sửa đổi, UI đều được đồng bộ ngay tức khắc.
2. **Lối vào màn hình Chỉnh sửa:**
   - Nút icon `Icons.edit_outlined` trên `AppBar`.
   - Nút `OutlinedButton.icon` nằm ngay dưới phần Bio của người dùng.

---

## 4. Kết quả Kiểm thử & Đánh giá

1. **Phân tích mã nguồn tĩnh (`flutter analyze`):**
   ```
   Analyzing travel_trust_network_mobile...
   No issues found! (ran in 5.8s)
   ```
   * 100% không có lỗi (0 errors) hay cảnh báo (0 warnings).
2. **Kiểm tra luồng liên thông:**
   - [x] Mở Profile $\rightarrow$ Bấm nút "Chỉnh sửa hồ sơ" $\rightarrow$ Mở `EditProfileScreen`.
   - [x] Sửa tên, cập nhật bio $\rightarrow$ Bấm "Lưu thay đổi" $\rightarrow$ Gửi `PUT /api/v1/users/me/profile`.
   - [x] Server cập nhật thành công $\rightarrow$ Quay lại `ProfileScreen`, tên và bio mới hiển thị ngay lập tức.
   - [x] Kéo xuống để làm mới (Pull-to-refresh) $\rightarrow$ Dữ liệu chuẩn xác, lịch sử `trustScoreLogs` vẫn được giữ nguyên vẹn.

---

## 5. Hướng dẫn Trình bày & Phản biện cho Phạm Hoàng Nam

Khi giảng viên yêu cầu trình bày tính năng Cập nhật hồ sơ:
1. **Trình diễn Sửa thông tin:**
   - Mở Tab Cá nhân $\rightarrow$ Bấm nút icon Edit trên AppBar.
   - Thay đổi tên hiển thị (ví dụ từ *"Demo User"* thành *"Phạm Hoàng Nam"*), nhập tiểu sử ngắn.
   - Bấm "Lưu thay đổi" $\rightarrow$ Chỉ vào tên mới được cập nhật ngay trên màn hình Profile:
     - *"Em sử dụng Riverpod `NotifierProvider`. Khi gọi API `PUT /users/me/profile` thành công, `AuthController` cập nhật trực tiếp `state.user`. Do đó toàn bộ các widget lắng nghe provider đều được cập nhật dữ liệu mới mà không cần phải reload lại toàn bộ ứng dụng."*
2. **Giải thích về bảo mật:**
   - *"Trường `trustScore` (Điểm uy tín) được bảo vệ chặt chẽ phía Backend, DTO `UpdateProfileRequest` không cho phép client tự sửa điểm uy tín. Điểm chỉ có thể tăng thông qua các hành động nghiệp vụ thực tế như Check-out (+2) hoặc Viết review (+5)."*
