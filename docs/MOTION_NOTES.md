# TTN motion — triển khai và kiểm tra

- Timing chung: press 120 ms, phản hồi 180 ms, fade 220 ms, mở rộng 260 ms, chuyển trang 300 ms. Các hiệu ứng bổ sung tôn trọng `MediaQuery.disableAnimations`.
- Giữ `MaterialPageRoute` và Android predictive back. Chuyển tab dùng dịch chuyển rất nhẹ, giữ `IndexedStack`, scroll và form; tắt ticker ở tab ẩn. Không phủ opacity lên toàn bộ trang ảnh.
- Locket giữ card khi refresh và giữ cả hai tab sau lần mở đầu tiên. Ảnh chỉ fade khi có frame đã giải mã; reaction chỉ pop sau khi backend xác nhận. Ảnh riêng tư không giữ pixel cũ khi đổi media/đăng xuất.
- Nút/loading/error chuyển nhẹ; vùng loading giữ chiều cao. Các form không nằm trong `AnimatedSwitcher`. Các nút đã rời trạng thái không nhận tap hoặc xuất hiện lại trong semantics khi crossfade.
- Ảnh được giới hạn kích thước decode theo số pixel hiển thị, tối đa 2048 px chiều rộng. Repaint boundary tách ảnh Locket khỏi phản hồi reaction; key ổn định và ánh xạ ID giữ state khi danh sách cập nhật.
- Không thay service, API, model, backend, database hoặc nghiệp vụ auth/GPS/review/bạn bè; không thêm package.

## File thay đổi

| Nhóm | File (tương đối với `lib/`) |
| --- | --- |
| Chung / navigation | `main.dart`, `app/main_navigation_screen.dart`, `shared/motion/app_motion.dart`, `shared/widgets/motion_feedback.dart`, `shared/widgets/error_notice.dart` |
| Auth | `features/auth/auth_screen.dart`, `features/auth/widgets/auth_actions.dart`, `features/auth/widgets/auth_hero_banner.dart` |
| Explore / Detail | `features/places/explore_screen.dart`, `features/places/place_detail_screen.dart`, `features/places/widgets/place_card.dart`, `features/places/widgets/review_card.dart` |
| Locket | `features/locket/locket_feed_screen.dart`, `features/locket/locket_card.dart`, `features/locket/private_locket_image.dart`, `features/locket/send_locket_screen.dart` |
| Bạn bè / hồ sơ | `features/friends/friends_screen.dart`, `features/friends/friend_profile_screen.dart`, `features/profile/profile_screen.dart`, `features/profile/edit_profile_screen.dart` |
| GPS / Review | `features/visits/visit_screen.dart`, `features/visits/visit_history_screen.dart`, `features/visits/widgets/gps_position_card.dart`, `features/visits/widgets/visit_summary.dart`, `features/reviews/create_review_screen.dart`, `features/reviews/widgets/review_rating_picker.dart` |

Test: thêm `test/features/motion_state_test.dart`, cập nhật `test/views/locket_screens_test.dart` để kiểm tra provider ảnh sau resize và không tải lại ảnh khi đổi tab.

## Kiểm thử

- Trước sửa: analyzer sạch, **131/131 test**.
- Sau sửa: analyzer sạch, **139/139 test**.
- `flutter build apk --debug --no-pub -t lib/main.dart` thành công. APK thật: `build/app/outputs/flutter-apk/app-debug.apk`.
- Test mới xác nhận giữ search/scroll/request count khi đổi tab, giữ card khi refresh, reaction không xác nhận sớm/không gửi trùng, xóa ảnh ngay khi đăng xuất, back navigation giữ form/kết quả và hành vi giảm chuyển động. Có kiểm tra disposal giữa animation và chặn tap vào action cũ.
- Kiểm tra trực quan trên emulator bằng harness offline tạm: Explore, Detail/back, Locket, Bạn bè, Profile; màn đăng nhập kiểm tra từ entry point thật. Harness không gọi backend, không ghi tài khoản thật và không nằm trong source sản phẩm.
- Khung preview của Send Locket đã được kiểm tra giữ nguyên kích thước vuông ở cả placeholder và ảnh đã chọn.

Profile mode đã chạy trên emulator Android x86_64 1080×2400, với dữ liệu/ảnh mẫu offline. Sau bỏ 10 giây đầu, mẫu 787 frame trong các thao tác chuyển trang/tab, cuộn Locket và mở Profile có p95 UI **7,95 ms**, p95 raster **28,96 ms**; 220 frame vượt 16,67 ms ở ít nhất một trong hai giai đoạn. Đây là số đo quan sát trên emulator, còn raster jank; không phải cam kết 60 FPS hoặc benchmark thiết bị thật. Đã dùng dịch chuyển nhẹ thay opacity toàn trang để giảm compositing; giữ fade ở các vùng nhỏ và ảnh mới giải mã.

Chưa kiểm chứng trên thiết bị vật lý, màn hình tần số quét cao, ảnh/mạng người dùng thực hoặc tác động pin. Bản profile/harness dùng để đo là tạm; bản APK bàn giao dùng entry point `lib/main.dart`.
