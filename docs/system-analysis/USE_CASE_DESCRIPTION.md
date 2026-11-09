# Mô tả chi tiết Use Case

Ngày phân tích: 2026-11-05 (Asia/Saigon). Phạm vi: working tree FE `travel-trust-network-mobile` và BE `../travel-trust-network-be`. Chỉ tài liệu trong thư mục này được tạo; không sửa mã nguồn BE/FE.

FE HEAD: `67a1c6351a4d706cc963781b744798d6d2aba4c3`. BE HEAD: `ebc296ba167c1c12ddd027e0b53349499b9f2a49`; BE có thay đổi sẵn ở cấu hình/tài liệu, nên nhận định áp dụng cho working tree đã đọc, không chỉ commit. Không sao chép giá trị secret hoặc dữ liệu cá nhân từ cấu hình/seed.

`IMPLEMENTED` nghĩa là có chuỗi xử lý trong source phù hợp phạm vi use case; **không có nghĩa đã chạy thành công end-to-end**. `PARTIAL`: có xử lý nhưng còn thiếu/sai một phần. `NOT_INTEGRATED`: BE đã có nhưng FE chưa dùng. `NOT_FOUND`: chức năng được tham chiếu nhưng không tìm thấy thực thi trong phạm vi đã quét. `UNKNOWN/NEEDS_VERIFICATION` dùng cho dữ kiện không đủ bằng chứng; `N/A` dùng cho tác vụ local không cần BE.

API-ID tham chiếu [API_SPECIFICATION.md](API_SPECIFICATION.md); Screen-ID, trạng thái mapping và điều hướng ở [UI_API_MAPPING.md](UI_API_MAPPING.md); hạn chế và kiểm thử ở [ANALYSIS_GAPS.md](ANALYSIS_GAPS.md). Source references là file thật, có symbol/line khi hữu ích. Hướng dẫn `hd.md` chỉ chứng minh chức năng từng được đề cập, không chứng minh đã triển khai.

Các bước dưới đây mô tả code hiện có, không phải yêu cầu thiết kế tương lai. Với NOT_FOUND, phần Main Success Flow ghi rõ không có flow thực thi.

## UC-01 — Đăng ký email và mật khẩu

1. **Use Case ID:** UC-01.
2. **Use Case Name:** Đăng ký email và mật khẩu.
3. **Description:** Tạo tài khoản ứng dụng và phiên JWT; không xác minh quyền sở hữu email.
4. **Primary Actor:** Khách.
5. **Preconditions:** AuthStatus.signedOut; API và database sẵn sàng.
6. **Trigger:** Bấm Đăng ký sau khi điền họ tên, email, mật khẩu và xác nhận.
7. **Main Success Flow:**

   1. Actor nhập thông tin; System kiểm tra email, tên, mật khẩu và xác nhận ở form.
   2. Actor gửi form; System gọi AuthController.register → AuthService.register → POST /auth/register.
   3. System BE chuẩn hóa email trim/lowercase, kiểm tra trùng, hash PBKDF2, lưu User và log điểm khởi tạo trong transaction.
   4. System trả AuthResponse; FE parse token/profile, ghi secure storage rồi đặt authenticated; AuthGate hiển thị MainNavigationScreen.

8. **Alternative Flows:** Xác nhận mật khẩu chỉ xử lý ở FE, không gửi BE; chuyển sang LoginScreen bằng nút đổi chế độ.
9. **Exception Flows:** Form sai: không gọi API; trùng email: 409 DUPLICATE_EMAIL; DTO sai: 400; lỗi lưu token: FE giữ signedOut và báo lỗi chung.
10. **Postconditions:** BE có user, log điểm và JWT đã phát hành; FE có phiên nếu ghi token thành công.
11. **Business Rules:** Email ≤150, fullName ≤150 và không blank; mật khẩu 8–128, không trim; điểm khởi tạo theo cấu hình, hiện là 50. Không ràng buộc miền Gmail.
12. **Related APIs:** API-01.
13. **Related UI Screens:** S02.
14. **Implementation Status:** overall **IMPLEMENTED**; BE: IMPLEMENTED; FE: IMPLEMENTED. Runtime/E2E: NEEDS_VERIFICATION.
15. **Source Code References:** [src/main/java/fu/prm393/modules/auth/service/impl/AuthServiceImpl.java:49](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/auth/service/impl/AuthServiceImpl.java#L49); [lib/views/auth/widgets/auth_screen.dart:38](../../lib/views/auth/widgets/auth_screen.dart#L38); [lib/controllers/auth_controller.dart](../../lib/controllers/auth_controller.dart).

## UC-02 — Đăng nhập email và mật khẩu

1. **Use Case ID:** UC-02.
2. **Use Case Name:** Đăng nhập email và mật khẩu.
3. **Description:** Xác thực tài khoản đã có password hash.
4. **Primary Actor:** Khách.
5. **Preconditions:** signedOut; tài khoản có passwordHash.
6. **Trigger:** Bấm Đăng nhập hoặc submit bàn phím.
7. **Main Success Flow:**

   1. Actor nhập email/mật khẩu; System FE validate và gọi AuthController.login.
   2. System gửi POST /auth/login; BE tìm email không phân biệt hoa thường và kiểm tra hash.
   3. System từ chối tài khoản không tồn tại, sai mật khẩu hoặc tài khoản Google/seed chưa có hash bằng cùng lỗi.
   4. System trả AuthResponse; FE lưu JWT, cập nhật auth state; AuthGate mở khung chính.

8. **Alternative Flows:** Actor có thể chuyển sang đăng ký hoặc chọn Google.
9. **Exception Flows:** 401 UNAUTHORIZED cho thông tin sai; 400 cho DTO sai; lỗi mạng/secure storage được hiển thị qua auth.error.
10. **Postconditions:** Phiên mới ở thiết bị khi thành công; đăng nhập không tự cộng lại điểm.
11. **Business Rules:** BE login yêu cầu password nonblank, tối đa 128; không áp min 8 ở login. FE chỉ kiểm tra chuỗi rỗng và giới hạn tối đa.
12. **Related APIs:** API-02.
13. **Related UI Screens:** S01.
14. **Implementation Status:** overall **IMPLEMENTED**; BE: IMPLEMENTED; FE: IMPLEMENTED. Runtime/E2E: NEEDS_VERIFICATION.
15. **Source Code References:** [src/main/java/fu/prm393/modules/auth/service/impl/AuthServiceImpl.java:49](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/auth/service/impl/AuthServiceImpl.java#L49); [lib/views/auth/widgets/auth_screen.dart:38](../../lib/views/auth/widgets/auth_screen.dart#L38); [lib/controllers/auth_controller.dart](../../lib/controllers/auth_controller.dart).

## UC-03 — Đăng nhập Google

1. **Use Case ID:** UC-03.
2. **Use Case Name:** Đăng nhập Google.
3. **Description:** Nhận Google ID token qua SDK rồi đổi lấy JWT của ứng dụng.
4. **Primary Actor:** Khách; Google hỗ trợ.
5. **Preconditions:** signedOut; GOOGLE_SERVER_CLIENT_ID ở FE và GOOGLE_CLIENT_ID ở BE được cấu hình phù hợp; SDK Android hoạt động.
6. **Trigger:** Bấm Đăng nhập với Google.
7. **Main Success Flow:**

   1. Actor chọn tài khoản qua GoogleSignIn.authenticate; System nhận ID token.
   2. System FE gửi email, fullName, avatarUrl, idToken và fcmToken:null đến POST /auth/google.
   3. System BE gọi HTTPS Google tokeninfo đồng bộ; kiểm tra aud, iss, email_verified, email khớp và exp.
   4. System tạo user/log điểm nếu mới, hoặc cập nhật tên/avatar/FCM nếu đã có; phát hành JWT.
   5. System FE lưu JWT và mở khung chính như đăng nhập email.

8. **Alternative Flows:** Actor hủy Google picker: service trả null, auth quay về signedOut không tạo phiên.
9. **Exception Flows:** Thiếu client ID FE: báo cấu hình trước request; BE chưa cấu hình/ID token không hợp lệ: 401; lỗi SDK/mạng: thông báo lỗi.
10. **Postconditions:** User và phiên ứng dụng được tạo/cập nhật sau xác minh; Google-only user không tự có password.
11. **Business Rules:** Không phải REST redirect/callback OAuth tự triển khai. Dữ liệu tên/avatar lấy từ request; email được xác minh qua tokeninfo; không có FCM registration trong luồng FE.
12. **Related APIs:** API-03.
13. **Related UI Screens:** S01.
14. **Implementation Status:** overall **IMPLEMENTED**; BE: IMPLEMENTED; FE: IMPLEMENTED. Runtime/E2E: NEEDS_VERIFICATION.
15. **Source Code References:** [lib/services/auth_service.dart:15](../../lib/services/auth_service.dart#L15); [src/main/java/fu/prm393/modules/auth/service/impl/GoogleTokenVerifierImpl.java:29](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/auth/service/impl/GoogleTokenVerifierImpl.java#L29); [src/main/java/fu/prm393/modules/auth/service/impl/AuthServiceImpl.java:49](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/auth/service/impl/AuthServiceImpl.java#L49); [lib/views/auth/widgets/auth_screen.dart:38](../../lib/views/auth/widgets/auth_screen.dart#L38).

## UC-04 — Khôi phục và xác minh phiên

1. **Use Case ID:** UC-04.
2. **Use Case Name:** Khôi phục và xác minh phiên.
3. **Description:** Đọc JWT đã lưu và xác minh lại bằng API hồ sơ.
4. **Primary Actor:** Người dùng.
5. **Preconditions:** Ứng dụng khởi động; TokenStorage khả dụng.
6. **Trigger:** AuthController.build lên lịch restoreSession; hoặc bấm Thử lại.
7. **Main Success Flow:**

   1. Actor mở ứng dụng; System hiển thị trạng thái restoring.
   2. System đọc token từ secure storage; nếu có, đặt token cho ApiService và GET profile.
   3. System BE lấy hồ sơ của subject JWT; FE parse UserModel.
   4. System đặt authenticated và hiện MainNavigationScreen.

8. **Alternative Flows:** Không có token: signedOut; lỗi mạng/5xx: restoreFailed, giữ token trên đĩa, xóa token trong memory để chờ retry.
9. **Exception Flows:** Profile 401 hoặc 404: _expireSession xóa phiên; xóa storage thất bại: restoreFailed.
10. **Postconditions:** Phiên đã xác minh được hiển thị; hoặc màn đăng nhập/retry tương ứng.
11. **Business Rules:** Không kiểm tra JWT cục bộ để kết luận hợp lệ; không có refresh token.
12. **Related APIs:** API-04.
13. **Related UI Screens:** C01.
14. **Implementation Status:** overall **IMPLEMENTED**; BE: IMPLEMENTED; FE: IMPLEMENTED. Runtime/E2E: NEEDS_VERIFICATION.
15. **Source Code References:** [lib/controllers/auth_controller.dart](../../lib/controllers/auth_controller.dart); [lib/views/auth/auth_gate.dart:26](../../lib/views/auth/auth_gate.dart#L26); [lib/services/token_storage.dart](../../lib/services/token_storage.dart).

## UC-05 — Đăng xuất trên thiết bị

1. **Use Case ID:** UC-05.
2. **Use Case Name:** Đăng xuất trên thiết bị.
3. **Description:** Xóa token lưu tại thiết bị và auth state.
4. **Primary Actor:** Người dùng.
5. **Preconditions:** Không có thao tác auth đang busy; có thể logout cả từ restoreFailed.
6. **Trigger:** Bấm Đăng xuất hoặc Đăng xuất phiên đã lưu.
7. **Main Success Flow:**

   1. Actor bấm logout; System khóa thao tác auth bằng isBusy.
   2. System gọi TokenStorage.clear; khi thành công xóa accessToken trong memory và chuyển signedOut.
   3. System AuthGate đưa navigator về route đầu và hiện LoginScreen.

8. **Alternative Flows:** Nếu clear thất bại: giữ state trước đó và hiện lỗi để thử lại.
9. **Exception Flows:** Lỗi secure storage; không có request logout để BE trả lỗi.
10. **Postconditions:** Phiên thiết bị bị xóa khi thành công; JWT đã phát hành vẫn có thể hợp lệ tại BE đến hết hạn.
11. **Business Rules:** Đây là chức năng local; không có API thu hồi token; không gọi GoogleSignIn.signOut.
12. **Related APIs:** N/A — không có API riêng chứng minh chức năng này.
13. **Related UI Screens:** S03, C01.
14. **Implementation Status:** overall **IMPLEMENTED**; BE: N/A — local; FE: IMPLEMENTED. Runtime/E2E: NEEDS_VERIFICATION.
15. **Source Code References:** [lib/controllers/auth_controller.dart](../../lib/controllers/auth_controller.dart); [lib/views/auth/auth_gate.dart:26](../../lib/views/auth/auth_gate.dart#L26); [lib/views/profile_screen.dart:19](../../lib/views/profile_screen.dart#L19).

## UC-06 — Xem hồ sơ và lịch sử điểm uy tín

1. **Use Case ID:** UC-06.
2. **Use Case Name:** Xem hồ sơ và lịch sử điểm uy tín.
3. **Description:** Hiển thị hồ sơ, số visit VERIFIED, tổng điểm và log biến động.
4. **Primary Actor:** Người dùng.
5. **Preconditions:** authenticated; user trong auth state.
6. **Trigger:** Mở tab Cá nhân; bấm refresh hoặc kéo làm mới.
7. **Main Success Flow:**

   1. Actor mở hồ sơ; System hiển thị UserModel đang có trong state.
   2. Actor làm mới; System gọi refreshProfile → GET /users/me/profile.
   3. System BE đọc User, đếm visit VERIFIED và lấy TrustScoreLog mới nhất trước.
   4. System cập nhật auth state; ProfileScreen render điểm, số visit, bio và danh sách log.

8. **Alternative Flows:** Dữ liệu ban đầu có thể đến từ AuthResponse/restore; không tự GET mỗi lần đổi tab.
9. **Exception Flows:** 401/404 làm hết phiên; lỗi mạng giữ user cũ và hiển thị state.error.
10. **Postconditions:** Auth state có profile mới nếu request thành công.
11. **Business Rules:** TrustScoreLog FE dùng id/delta/newScore/reason/createdAt; previousScore/policyVersion có trong BE nhưng không được hiển thị.
12. **Related APIs:** API-04.
13. **Related UI Screens:** S03.
14. **Implementation Status:** overall **IMPLEMENTED**; BE: IMPLEMENTED; FE: IMPLEMENTED. Runtime/E2E: NEEDS_VERIFICATION.
15. **Source Code References:** [lib/views/profile_screen.dart:19](../../lib/views/profile_screen.dart#L19); [lib/controllers/auth_controller.dart](../../lib/controllers/auth_controller.dart); [src/main/java/fu/prm393/modules/auth/service/impl/AuthServiceImpl.java:138](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/auth/service/impl/AuthServiceImpl.java#L138).

## UC-07 — Chỉnh sửa hồ sơ

1. **Use Case ID:** UC-07.
2. **Use Case Name:** Chỉnh sửa hồ sơ.
3. **Description:** Cập nhật họ tên, bio và URL avatar nhập tay.
4. **Primary Actor:** Người dùng.
5. **Preconditions:** authenticated; EditProfileScreen nhận currentUser.
6. **Trigger:** Bấm Chỉnh sửa và Lưu thay đổi.
7. **Main Success Flow:**

   1. Actor mở form; System điền dữ liệu cũ, giới hạn tên 150 và bio 500.
   2. Actor sửa dữ liệu và bấm lưu; System trim và gửi PUT profile qua AuthController.
   3. System BE ghi fullName, bio, avatarUrl và trả profile.
   4. System FE cập nhật state, báo thành công và pop màn sửa khi lời gọi kết thúc bình thường.

8. **Alternative Flows:** Bio/avatar rỗng được gửi null để xóa; preview avatar dùng trực tiếp NetworkImage.
9. **Exception Flows:** Lỗi API thường được rethrow và hiển thị; nhánh 401/404 chỉ expire session, không rethrow; guard busy có thể return sớm nên UI có khả năng báo thành công dù chưa lưu.
10. **Postconditions:** BE cập nhật nếu thành công; FE cần xác minh UX nhánh hết phiên/guard. Avatar /uploads/... được BE chấp nhận nhưng profile không resolve URL như các màn khác.
11. **Business Rules:** Tên nonblank ≤150; bio ≤500; avatar không có URL validation ở cả hai phía.
12. **Related APIs:** API-05.
13. **Related UI Screens:** S03, S04.
14. **Implementation Status:** overall **PARTIAL**; BE: IMPLEMENTED; FE: PARTIAL. Runtime/E2E: NEEDS_VERIFICATION.
15. **Source Code References:** [lib/views/profile/edit_profile_screen.dart:44](../../lib/views/profile/edit_profile_screen.dart#L44); [lib/controllers/auth_controller.dart](../../lib/controllers/auth_controller.dart); [src/main/java/fu/prm393/modules/auth/service/impl/AuthServiceImpl.java:107](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/auth/service/impl/AuthServiceImpl.java#L107).

## UC-08 — Khám phá, tìm kiếm và lọc địa điểm

1. **Use Case ID:** UC-08.
2. **Use Case Name:** Khám phá, tìm kiếm và lọc địa điểm.
3. **Description:** Tìm theo tên/địa chỉ và danh mục, làm mới danh sách.
4. **Primary Actor:** Người dùng.
5. **Preconditions:** FE nằm trong khung authenticated; BE cho phép truy cập public.
6. **Trigger:** Mở tab Khám phá, nhập từ khóa hoặc chọn chip.
7. **Main Success Flow:**

   1. Actor mở tab; System watch placesListProvider theo keyword/category.
   2. Actor nhập từ khóa; System debounce 500ms; chọn chip thay đổi query.
   3. System PlaceService encode query và GET /places; BE trim keyword, uppercase category.
   4. System repository loại hidden, tìm ILIKE tên/địa chỉ, lọc category bằng equality và sort name/id.
   5. System FE render loading/error/empty/list; Actor chạm card để mở chi tiết bằng placeId.

8. **Alternative Flows:** ALL không gửi category; kéo refresh/retry invalidate provider; FE chỉ có CAMPUS/HERITAGE/NATURE bên cạnh ALL.
9. **Exception Flows:** Lỗi mạng/API hiển thị và có Thử lại.
10. **Postconditions:** Danh sách phù hợp filter được hiển thị; không có ghi database.
11. **Business Rules:** Không phân trang, không tìm gần đây bằng GPS, không bookmark/offline trong code thực thi.
12. **Related APIs:** API-06.
13. **Related UI Screens:** S05.
14. **Implementation Status:** overall **IMPLEMENTED**; BE: IMPLEMENTED; FE: IMPLEMENTED. Runtime/E2E: NEEDS_VERIFICATION.
15. **Source Code References:** [lib/views/places/explore_screen.dart:12](../../lib/views/places/explore_screen.dart#L12); [lib/services/place_service.dart:16](../../lib/services/place_service.dart#L16); [src/main/java/fu/prm393/modules/place/service/impl/PlaceServiceImpl.java:27](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/place/service/impl/PlaceServiceImpl.java#L27); [src/main/java/fu/prm393/modules/place/repository/PlaceRepository.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/place/repository/PlaceRepository.java).

## UC-09 — Xem chi tiết và đánh giá xác minh của địa điểm

1. **Use Case ID:** UC-09.
2. **Use Case Name:** Xem chi tiết và đánh giá xác minh của địa điểm.
3. **Description:** Xem mô tả, vị trí chuẩn, bán kính, giờ mở cửa và review VERIFIED.
4. **Primary Actor:** Người dùng.
5. **Preconditions:** Có placeId; BE public, FE chỉ có lối vào sau auth.
6. **Trigger:** Chạm card trong ExploreScreen.
7. **Main Success Flow:**

   1. Actor chọn địa điểm; System push PlaceDetailScreen(placeId).
   2. System placeDetailProvider gọi GET /places/{id}.
   3. System BE kiểm tra tồn tại/hidden, lấy review mới nhất trước và chỉ giữ isVerifiedReview.
   4. System trả PlaceDetailResponse; FE render metadata và review card/ảnh thường.
   5. Actor chọn Viết đánh giá hoặc Check-in; System push màn với placeId và tên nếu cần.

8. **Alternative Flows:** Không có review: thông báo trống và nút viết review; lỗi có retry.
9. **Exception Flows:** 400 UUID sai; 404 RESOURCE_NOT_FOUND; 400 HIDDEN_PLACE.
10. **Postconditions:** Chi tiết hiển thị hoặc thông báo lỗi; không thay đổi trạng thái nghiệp vụ.
11. **Business Rules:** Giờ mở cửa là text hiển thị, không có kiểm tra lịch hoạt động khi check-in; ảnh 360 vẫn render Image.network.
12. **Related APIs:** API-07.
13. **Related UI Screens:** S06.
14. **Implementation Status:** overall **IMPLEMENTED**; BE: IMPLEMENTED; FE: IMPLEMENTED. Runtime/E2E: NEEDS_VERIFICATION.
15. **Source Code References:** [lib/views/places/place_detail_screen.dart:12](../../lib/views/places/place_detail_screen.dart#L12); [src/main/java/fu/prm393/modules/place/service/impl/PlaceServiceImpl.java:27](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/place/service/impl/PlaceServiceImpl.java#L27).

## UC-10 — Check-in bằng GPS thiết bị

1. **Use Case ID:** UC-10.
2. **Use Case Name:** Check-in bằng GPS thiết bị.
3. **Description:** Mở một visit sau kiểm tra GPS ở BE.
4. **Primary Actor:** Người dùng.
5. **Preconditions:** authenticated; placeId hợp lệ; quyền GPS, dịch vụ vị trí; không có visit OPEN.
6. **Trigger:** Bấm Check-in.
7. **Main Success Flow:**

   1. Actor bấm Check-in; System lấy vị trí high accuracy, giới hạn chờ 20 giây.
   2. System gửi placeId, userLat/userLng, accuracy nếu có và position.isMocked.
   3. System BE validate số hữu hạn/phạm vi, lock User rồi kiểm tra place hidden, mocked và single OPEN.
   4. System tính Haversine; nếu khoảng cách ≤ bán kính place (fallback cấu hình), lưu OPEN với giờ server.
   5. System FE lưu _visit và invalidate lịch sử; UI hiện summary và nút Check-out.

8. **Alternative Flows:** GPS tắt/quyền bị chặn: hiện hướng dẫn mở cài đặt; sai số GPS được gửi nhưng không có ngưỡng độ chính xác để chặn.
9. **Exception Flows:** 400 GPS_OUT_OF_RADIUS/MOCK_LOCATION_DETECTED/HIDDEN_PLACE/VALIDATION_ERROR; 409 SINGLE_OPEN_VISIT; lỗi kết quả không chắc chắn chuyển UC-13.
10. **Postconditions:** Visit OPEN được lưu; chưa cộng điểm.
11. **Business Rules:** Một user chỉ một OPEN, bảo vệ bằng user pessimistic lock; isMocked là thông tin client báo, không chứng minh vị trí thật.
12. **Related APIs:** API-08.
13. **Related UI Screens:** S07.
14. **Implementation Status:** overall **IMPLEMENTED**; BE: IMPLEMENTED; FE: IMPLEMENTED. Runtime/E2E: NEEDS_VERIFICATION.
15. **Source Code References:** [lib/views/visits/visit_screen.dart:49](../../lib/views/visits/visit_screen.dart#L49); [lib/services/location_service.dart](../../lib/services/location_service.dart); [lib/services/visit_service.dart:26](../../lib/services/visit_service.dart#L26); [src/main/java/fu/prm393/modules/visit/service/impl/VisitServiceImpl.java:40](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/visit/service/impl/VisitServiceImpl.java#L40).

## UC-11 — Check-out và xác minh chuyến đi

1. **Use Case ID:** UC-11.
2. **Use Case Name:** Check-out và xác minh chuyến đi.
3. **Description:** Hoàn tất visit OPEN và cộng điểm theo cấu hình.
4. **Primary Actor:** Người dùng.
5. **Preconditions:** authenticated; visit OPEN thuộc user; không _needsConfirmation.
6. **Trigger:** Bấm Check-out.
7. **Main Success Flow:**

   1. Actor bấm Check-out; System gửi PUT /visits/{visitId}/check-out không body.
   2. System BE lock User rồi Visit, kiểm tra owner và OPEN.
   3. System dùng LocalDateTime.now; yêu cầu giờ checkout sau checkin; đổi VERIFIED.
   4. System cộng điểm cấu hình (hiện +2), ghi TrustScoreLog và lưu Visit trong cùng transaction.
   5. System FE cập nhật summary, invalidate history và refresh profile.

8. **Alternative Flows:** Mở lại visit từ lịch sử phải reload xác minh trước khi thao tác.
9. **Exception Flows:** 403 FORBIDDEN; 409 ALREADY_CHECKED_OUT; 400 INVALID_CHECKOUT_TIME; 404; lỗi không chắc chắn chuyển UC-13.
10. **Postconditions:** Visit VERIFIED; trust score/log cập nhật khi transaction thành công.
11. **Business Rules:** Không lấy GPS checkout, không yêu cầu thời lượng tối thiểu ngoài thứ tự thời gian; FE không tự mở Studio sau checkout.
12. **Related APIs:** API-09, API-04.
13. **Related UI Screens:** S07.
14. **Implementation Status:** overall **IMPLEMENTED**; BE: IMPLEMENTED; FE: IMPLEMENTED. Runtime/E2E: NEEDS_VERIFICATION.
15. **Source Code References:** [lib/views/visits/visit_screen.dart:49](../../lib/views/visits/visit_screen.dart#L49); [src/main/java/fu/prm393/modules/visit/service/impl/VisitServiceImpl.java:85](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/visit/service/impl/VisitServiceImpl.java#L85).

## UC-12 — Xem lịch sử và tiếp tục chuyến đi

1. **Use Case ID:** UC-12.
2. **Use Case Name:** Xem lịch sử và tiếp tục chuyến đi.
3. **Description:** Liệt kê chuyến đi cá nhân và điều hướng theo trạng thái.
4. **Primary Actor:** Người dùng.
5. **Preconditions:** authenticated.
6. **Trigger:** Mở tab Chuyến đi hoặc nút Lịch sử.
7. **Main Success Flow:**

   1. Actor mở lịch sử; System watch visitHistoryProvider theo userId.
   2. System GET /visits/my-history; BE lọc đúng userId từ JWT, sort checkInTime giảm dần.
   3. System render summary mỗi visit.
   4. Actor chạm OPEN; System mở VisitScreen kèm initialVisit/visitId và reload; hoặc Actor bấm viết review ở VERIFIED để mở CreateReviewScreen kèm initialVisitId.

8. **Alternative Flows:** Kéo refresh hoặc bấm retry; lịch sử rỗng có thông báo.
9. **Exception Flows:** 401 visit API làm hết phiên; lỗi khác render thông báo/retry.
10. **Postconditions:** Chuyến đi hiển thị; điều hướng không tự thay đổi Visit.
11. **Business Rules:** REJECTED có enum và hiển thị nhưng chưa có thao tác nghiệp vụ tạo trạng thái đó trong service.
12. **Related APIs:** API-10.
13. **Related UI Screens:** S08, S07, S09.
14. **Implementation Status:** overall **IMPLEMENTED**; BE: IMPLEMENTED; FE: IMPLEMENTED. Runtime/E2E: NEEDS_VERIFICATION.
15. **Source Code References:** [lib/views/visits/visit_history_screen.dart:14](../../lib/views/visits/visit_history_screen.dart#L14); [lib/services/visit_service.dart:11](../../lib/services/visit_service.dart#L11); [src/main/java/fu/prm393/modules/visit/service/impl/VisitServiceImpl.java:119](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/visit/service/impl/VisitServiceImpl.java#L119).

## UC-13 — Đối soát trạng thái sau request không chắc chắn

1. **Use Case ID:** UC-13.
2. **Use Case Name:** Đối soát trạng thái sau request không chắc chắn.
3. **Description:** Tải lại lịch sử trước khi cho phép lặp mutation visit.
4. **Primary Actor:** Người dùng.
5. **Preconditions:** VisitScreen đang mở; có thể có visitId hoặc kết quả mutation chưa rõ.
6. **Trigger:** Timeout/mất kết nối sau gửi mutation, conflict; hoặc bấm Tải lại trạng thái.
7. **Main Success Flow:**

   1. Actor gửi check-in/out nhưng System FE không nhận được kết quả chắc chắn; System bật _needsConfirmation.
   2. Actor bấm reload hoặc mở lịch sử rồi quay lại; System GET my-history.
   3. System tìm theo id đã biết, nếu chưa có id thì lấy visit OPEN đầu tiên.
   4. System cập nhật _visit/_needsConfirmation; nếu VERIFIED thì refresh profile.
   5. System cho phép thao tác tương ứng với trạng thái đã tải lại.

8. **Alternative Flows:** Không tìm thấy id xác định: vẫn khóa và báo không tìm thấy; không id và không thấy OPEN: có thể check-in lại.
9. **Exception Flows:** Reload lỗi: giữ trạng thái cần xác nhận trước đó; không tự retry mutation.
10. **Postconditions:** UI phản ánh dữ liệu lịch sử đọc lại hoặc giữ khóa chờ xác nhận.
11. **Business Rules:** Không có API visit-by-id hay idempotency key; đây là cơ chế FE đối soát qua history.
12. **Related APIs:** API-10, API-04.
13. **Related UI Screens:** S07, S08.
14. **Implementation Status:** overall **IMPLEMENTED**; BE: IMPLEMENTED; FE: IMPLEMENTED. Runtime/E2E: NEEDS_VERIFICATION.
15. **Source Code References:** [lib/views/visits/visit_screen.dart:107](../../lib/views/visits/visit_screen.dart#L107); [lib/views/visits/visit_screen.dart:124](../../lib/views/visits/visit_screen.dart#L124); [lib/services/api_service.dart](../../lib/services/api_service.dart).

## UC-14 — Đăng đánh giá xác minh

1. **Use Case ID:** UC-14.
2. **Use Case Name:** Đăng đánh giá xác minh.
3. **Description:** Đăng một review cho một địa điểm từ chuyến đi VERIFIED.
4. **Primary Actor:** Người dùng.
5. **Preconditions:** authenticated; có visit VERIFIED đúng user/place; chưa review địa điểm.
6. **Trigger:** Bấm Viết đánh giá, chọn visit/sao và gửi.
7. **Main Success Flow:**

   1. Actor mở form; System đọc history và lọc visit cùng place có status VERIFIED, tự chọn đầu tiên nếu chưa chọn.
   2. Actor chọn rating, nhập comment; System FE yêu cầu tối thiểu 5 ký tự và selectedVisitId.
   3. System POST /reviews; BE lock User, kiểm tra visit owner/place/status và duplicate user/place.
   4. System lock Place, lưu review, tính lại average/count; cộng điểm cấu hình (hiện +5) và log trong transaction.
   5. System FE invalidate detail/history, refresh profile, báo thành công và pop(true).

8. **Alternative Flows:** Không có visit phù hợp: hiện nút Check-in; ảnh URL tùy chọn thuộc UC-15.
9. **Exception Flows:** 400 UNVERIFIED_VISIT/VALIDATION_ERROR; rating sai DTO trả VALIDATION_ERROR trước service, service gọi trực tiếp có INVALID_RATING; 409 DUPLICATE_REVIEW; lỗi mạng không có đối soát như visit.
10. **Postconditions:** Review và aggregate/điểm được ghi nếu transaction thành công; danh sách Explore có thể giữ aggregate cũ.
11. **Business Rules:** Một user/place chỉ một review; visit liên kết unique; comment BE chỉ nonblank. FE hiển thị +5 cố định dù BE cấu hình được.
12. **Related APIs:** API-10, API-11, API-04.
13. **Related UI Screens:** S09, S06, S08.
14. **Implementation Status:** overall **PARTIAL**; BE: IMPLEMENTED; FE: PARTIAL. Runtime/E2E: NEEDS_VERIFICATION.
15. **Source Code References:** [lib/views/reviews/create_review_screen.dart:60](../../lib/views/reviews/create_review_screen.dart#L60); [src/main/java/fu/prm393/modules/review_locket/service/impl/ReviewServiceImpl.java:37](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/review_locket/service/impl/ReviewServiceImpl.java#L37); [lib/services/review_service.dart:16](../../lib/services/review_service.dart#L16).

## UC-15 — Đính kèm URL ảnh review và tạo Locket tự động

1. **Use Case ID:** UC-15.
2. **Use Case Name:** Đính kèm URL ảnh review và tạo Locket tự động.
3. **Description:** Nhập URL ảnh và cờ 360; BE tạo signal kèm review trong cùng transaction.
4. **Primary Actor:** Người dùng.
5. **Preconditions:** Điều kiện UC-14; URL ảnh tùy chọn được nhập tay.
6. **Trigger:** Điền ảnh kỷ niệm trong form review rồi đăng.
7. **Main Success Flow:**

   1. Actor nhập postcardImageUrl và có thể tick is360Media; System FE gửi cùng request tạo review.
   2. System BE trim URL; blank thành null; lưu ảnh/cờ cùng Review.
   3. System BE có URL khác null thì lưu LocketSignal với sender/place, caption là tối đa 200 ký tự đầu comment và cờ ảnh.
   4. System trả ReviewResponse; FE cập nhật detail/history/profile; Actor mở Locket và có thể cần kéo refresh để thấy signal.

8. **Alternative Flows:** Không có URL: không tạo signal; không gọi riêng /locket/send-signal trong luồng review.
9. **Exception Flows:** Lỗi review/ghi signal làm transaction thất bại; không có validation URL/schema ảnh hay quyền sở hữu media.
10. **Postconditions:** Signal được lưu nếu review có URL; feed FE chưa bị invalidate ở handler review.
11. **Business Rules:** Đây là ghi DB đồng bộ, không push FCM; checkbox 360 không tạo hay kiểm tra panorama; không có upload trong form review.
12. **Related APIs:** API-11.
13. **Related UI Screens:** S09, S10.
14. **Implementation Status:** overall **PARTIAL**; BE: IMPLEMENTED; FE: PARTIAL. Runtime/E2E: NEEDS_VERIFICATION.
15. **Source Code References:** [lib/views/reviews/create_review_screen.dart:60](../../lib/views/reviews/create_review_screen.dart#L60); [src/main/java/fu/prm393/modules/review_locket/service/impl/ReviewServiceImpl.java:86](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/review_locket/service/impl/ReviewServiceImpl.java#L86); [lib/views/locket/locket_feed_screen.dart:14](../../lib/views/locket/locket_feed_screen.dart#L14).

## UC-16 — Chọn/chụp và tải ảnh lên máy chủ

1. **Use Case ID:** UC-16.
2. **Use Case Name:** Chọn/chụp và tải ảnh lên máy chủ.
3. **Description:** Upload file ảnh từ màn Gửi Locket; BE trả URL tương đối.
4. **Primary Actor:** Người dùng.
5. **Preconditions:** authenticated; camera/gallery khả dụng và có file đọc được.
6. **Trigger:** Chụp/chọn ảnh, sau đó bấm Gửi.
7. **Main Success Flow:**

   1. Actor chọn camera/gallery; System ImagePicker lấy ảnh maxWidth 1920 và quality 85, hiển thị preview.
   2. Actor bấm Gửi; System LocketService.uploadImage → ApiService.upload tạo FormData trường file.
   3. System BE đọc tối đa 20MiB+1, kiểm tra signature JPEG/PNG/WebP, sinh tên UUID và ghi thư mục upload.
   4. System trả url/filename/contentType/size; FE lấy url để tiếp tục UC-17.

8. **Alternative Flows:** initialFilePath có thể seed file nhưng chưa có caller truyền từ Studio; Actor hủy picker giữ trạng thái cũ.
9. **Exception Flows:** File rỗng/quá lớn/signature sai: 400 VALIDATION_ERROR ở service; lỗi multipart ngoài service cần kiểm chứng; lỗi ghi file: 500; lỗi camera/gallery hiện thông báo.
10. **Postconditions:** File được lưu độc lập; URL /uploads/... public; chưa có signal cho tới bước gửi tiếp thành công.
11. **Business Rules:** Không phải upload API cho Studio đã tồn tại. Hai request upload và gửi không chung transaction; FE không prevalidate dung lượng/định dạng.
12. **Related APIs:** API-12.
13. **Related UI Screens:** S11.
14. **Implementation Status:** overall **IMPLEMENTED**; BE: IMPLEMENTED; FE: IMPLEMENTED. Runtime/E2E: NEEDS_VERIFICATION.
15. **Source Code References:** [lib/views/locket/send_locket_screen.dart:61](../../lib/views/locket/send_locket_screen.dart#L61); [lib/views/locket/send_locket_screen.dart:43](../../lib/views/locket/send_locket_screen.dart#L43); [lib/services/api_service.dart](../../lib/services/api_service.dart); [src/main/java/fu/prm393/modules/media/service/impl/MediaStorageServiceImpl.java:22](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/media/service/impl/MediaStorageServiceImpl.java#L22).

## UC-17 — Gửi ảnh lên Locket

1. **Use Case ID:** UC-17.
2. **Use Case Name:** Gửi ảnh lên Locket.
3. **Description:** Lưu signal từ file đã upload, có caption tùy chọn.
4. **Primary Actor:** Người dùng.
5. **Preconditions:** authenticated; có file; UC-16 upload thành công.
6. **Trigger:** Bấm Gửi trong SendLocketScreen.
7. **Main Success Flow:**

   1. Actor chọn file và nhập lời nhắn ≤200; System disable thao tác khi đang gửi.
   2. System upload file lấy URL rồi POST /locket/send-signal với imageUrl, caption nếu không rỗng, placeId nếu có và is360Image:false mặc định.
   3. System BE lấy sender theo JWT; nếu có placeId thì kiểm tra tồn tại; lưu LocketSignal.
   4. System FE invalidate locketFeedProvider, hiện thông báo và pop(true).

8. **Alternative Flows:** Màn hiện được mở từ Feed không truyền placeId; service hỗ trợ cờ 360 nhưng UI Send không cho chọn.
9. **Exception Flows:** 404 user/place; 400 validation; lỗi gửi sau upload giữ file máy chủ chưa có signal; retry sẽ upload lại.
10. **Postconditions:** Signal tồn tại và feed được làm mới nếu thành công; không chọn người nhận.
11. **Business Rules:** Caption tối đa 200; không kiểm tra hidden place ở service này; không cộng điểm và không kiểm tra visit/review.
12. **Related APIs:** API-12, API-13.
13. **Related UI Screens:** S11, S10.
14. **Implementation Status:** overall **IMPLEMENTED**; BE: IMPLEMENTED; FE: IMPLEMENTED. Runtime/E2E: NEEDS_VERIFICATION.
15. **Source Code References:** [lib/views/locket/send_locket_screen.dart:61](../../lib/views/locket/send_locket_screen.dart#L61); [lib/services/locket_service.dart:35](../../lib/services/locket_service.dart#L35); [src/main/java/fu/prm393/modules/review_locket/service/impl/LocketServiceImpl.java:27](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/review_locket/service/impl/LocketServiceImpl.java#L27).

## UC-18 — Xem và làm mới Locket Feed

1. **Use Case ID:** UC-18.
2. **Use Case Name:** Xem và làm mới Locket Feed.
3. **Description:** Hiển thị tối đa 20 signal mới nhất toàn hệ thống.
4. **Primary Actor:** Người dùng.
5. **Preconditions:** authenticated; locketFeedProvider chỉ gọi khi userId khác null.
6. **Trigger:** Mở tab Locket; kéo refresh hoặc retry.
7. **Main Success Flow:**

   1. Actor mở tab; System watch locketFeedProvider.
   2. System GET /locket/feed; BE lấy findTop20ByOrderBySentAtDesc không filter receiver/sender.
   3. System FE parse LocketSignal, resolve imageUrl theo API origin và render grid, sender/caption/place.
   4. Actor refresh; System tải lại dữ liệu; ảnh 360 chỉ hiện badge.

8. **Alternative Flows:** Không có ảnh: trạng thái trống; nút Gửi ảnh mở S11.
9. **Exception Flows:** 401 được hiển thị ở feed nhưng ApiService không tự expire toàn cục cho endpoint này; lỗi ảnh dùng placeholder; lỗi API có retry.
10. **Postconditions:** Feed hiển thị hoặc thông báo lỗi; không có local widget/background subscription.
11. **Business Rules:** FE provider theo user giúp tách lifecycle, không biến response BE thành feed riêng tư.
12. **Related APIs:** API-14.
13. **Related UI Screens:** S10.
14. **Implementation Status:** overall **IMPLEMENTED**; BE: IMPLEMENTED; FE: IMPLEMENTED. Runtime/E2E: NEEDS_VERIFICATION.
15. **Source Code References:** [lib/views/locket/locket_feed_screen.dart:14](../../lib/views/locket/locket_feed_screen.dart#L14); [lib/services/locket_service.dart:12](../../lib/services/locket_service.dart#L12); [src/main/java/fu/prm393/modules/review_locket/service/impl/LocketServiceImpl.java:45](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/review_locket/service/impl/LocketServiceImpl.java#L45).

## UC-19 — Thiết kế và xuất Postcard nhiều lớp

1. **Use Case ID:** UC-19.
2. **Use Case Name:** Thiết kế và xuất Postcard nhiều lớp.
3. **Description:** Studio ghép ảnh nền, khung, sticker, chữ và tem GPS; xuất PNG, upload và trả URL.
4. **Primary Actor:** Người dùng.
5. **Preconditions:** authenticated; đang ở S09 (chọn visit VERIFIED để có tem GPS).
6. **Trigger:** Actor bấm "Tạo postcard trong Studio" ở S09.
7. **Main Success Flow:**

   1. Actor chọn/chụp ảnh nền, chọn khung, thêm sticker/chữ, kéo–phóng–xoay lớp.
   2. Tem GPS hiện nếu có visit VERIFIED của địa điểm.
   3. Actor bấm "Dùng postcard này": RepaintBoundary.toImage → PNG → upload (UC-16) → pop(url) về S09, ô ảnh được điền.

8. **Alternative Flows:** "Gửi lên Locket": mở S11 với initialFilePath là PNG vừa xuất.
9. **Exception Flows:** Upload lỗi: hiện thông báo, ở lại Studio. Không có visit VERIFIED: không có tem GPS.
10. **Postconditions:** Có URL ảnh postcard trong form review (hoặc file sẵn sàng gửi Locket).
11. **Business Rules:** Tem GPS là chữ vẽ lên ảnh, không do BE xác minh.
12. **Related APIs:** API-12 (upload).
13. **Related UI Screens:** S13, S09, S11.
14. **Implementation Status:** overall **IMPLEMENTED**; BE: N/A; FE: IMPLEMENTED. Runtime/E2E: NEEDS_VERIFICATION.
15. **Source Code References:** [lib/views/studio/studio_screen.dart](../../lib/views/studio/studio_screen.dart); [lib/views/reviews/create_review_screen.dart](../../lib/views/reviews/create_review_screen.dart).

## UC-20 — Chụp, ghép và xem panorama tương tác

1. **Use Case ID:** UC-20.
2. **Use Case Name:** Chụp, ghép và xem panorama tương tác.
3. **Description:** Xem ảnh 360° tương tác; không có chụp/ghép panorama.
4. **Primary Actor:** Người dùng.
5. **Preconditions:** authenticated; ảnh được gửi với công tắc 360° bật.
6. **Trigger:** Actor chạm ảnh trong feed S10.
7. **Main Success Flow:**

   1. S10 mở S12 với ảnh.
   2. Nếu is360Image: PanoramaViewer (kéo để xoay, nút bật/tắt cảm biến); nếu không: InteractiveViewer.

8. **Alternative Flows:** Không có.
9. **Exception Flows:** Ảnh không tải được: hiện lỗi ảnh. Chụp/ghép panorama: ngoài phạm vi, không triển khai.
10. **Postconditions:** Actor xem được ảnh 360°.
11. **Business Rules:** Cờ is360Image do người gửi tự khai, không kiểm định.
12. **Related APIs:** API-13 (cờ metadata), API-14.
13. **Related UI Screens:** S11, S12, S10.
14. **Implementation Status:** overall **PARTIAL**; BE: N/A; FE: PARTIAL (thiếu chụp/ghép). Runtime/E2E: NEEDS_VERIFICATION.
15. **Source Code References:** [lib/views/locket/locket_image_screen.dart](../../lib/views/locket/locket_image_screen.dart); [lib/views/locket/send_locket_screen.dart](../../lib/views/locket/send_locket_screen.dart).

## UC-21 — Nhận push và cập nhật Home Screen Widget

1. **Use Case ID:** UC-21.
2. **Use Case Name:** Nhận push và cập nhật Home Screen Widget.
3. **Description:** Widget Android hiển thị ảnh Locket mới nhất; không có push nền.
4. **Primary Actor:** Người dùng.
5. **Preconditions:** Android; đã thêm widget ra màn hình chính; app tải được feed.
6. **Trigger:** App tải feed (locketFeedProvider).
7. **Main Success Flow:**

   1. locketFeedProvider tải feed xong → LocketWidgetService.updateFromFeed.
   2. Tải ảnh mới nhất về file, lưu bằng HomeWidget.saveWidgetData, gọi updateWidget.
   3. LocketWidgetProvider (Kotlin) vẽ ảnh + người gửi/lời nhắn; chạm widget mở app.

8. **Alternative Flows:** Không có.
9. **Exception Flows:** Lỗi mạng/file: bỏ qua im lặng, widget giữ ảnh cũ. Push nền FCM: không có (BE chưa gửi FCM, chưa có google-services.json).
10. **Postconditions:** Widget hiển thị ảnh mới nhất tại lần tải feed gần nhất.
11. **Business Rules:** Widget chỉ cập nhật khi app mở và tải feed.
12. **Related APIs:** API-14.
13. **Related UI Screens:** S10.
14. **Implementation Status:** overall **PARTIAL**; BE: N/A; FE: PARTIAL (thiếu push nền). Runtime/E2E: NEEDS_VERIFICATION.
15. **Source Code References:** [lib/services/locket_widget_service.dart](../../lib/services/locket_widget_service.dart); [LocketWidgetProvider.kt](../../android/app/src/main/kotlin/com/example/travel_trust_network_mobile/LocketWidgetProvider.kt); [lib/services/locket_service.dart](../../lib/services/locket_service.dart).

## UC-22 — Lưu địa điểm và đọc ngoại tuyến

1. **Use Case ID:** UC-22.
2. **Use Case Name:** Lưu địa điểm và đọc ngoại tuyến.
3. **Description:** Hướng dẫn mô tả bookmark/SQLite; source hiện chỉ tải API và state trong bộ nhớ.
4. **Primary Actor:** Người dùng.
5. **Preconditions:** UNKNOWN — chưa có luồng thực thi.
6. **Trigger:** Chức năng được nhắc trong tài liệu hướng dẫn; chưa có trigger UI triển khai.
7. **Main Success Flow:**

   1. Actor chỉ có thể sử dụng các màn hiện có; không có điểm vào chức năng này.
   2. System không có handler/service để hoàn thành chức năng được mô tả. Không xác định Main Success Flow triển khai.

8. **Alternative Flows:** Không có alternative flow được tìm thấy.
9. **Exception Flows:** Không có local_database_service.dart, sqflite openDatabase/toMap/fromMap hay nút bookmark thực thi.
10. **Postconditions:** Không có postcondition triển khai để xác nhận.
11. **Business Rules:** API-06/API-07 đọc online; không có API offline riêng được tìm thấy.
12. **Related APIs:** N/A — không có API riêng chứng minh chức năng này.
13. **Related UI Screens:** NOT_FOUND — chỉ có tham chiếu hướng dẫn.
14. **Implementation Status:** overall **NOT_FOUND**; BE: NOT_FOUND; FE: NOT_FOUND. Runtime/E2E: NEEDS_VERIFICATION.
15. **Source Code References:** [lib/models/hd.md](../../lib/models/hd.md); [lib/services/hd.md](../../lib/services/hd.md); [lib/views/hd.md](../../lib/views/hd.md); [lib/views/locket/send_locket_screen.dart:17](../../lib/views/locket/send_locket_screen.dart#L17).


