# UI–API Mapping

Ngày phân tích: 2026-11-05 (Asia/Saigon). Phạm vi: working tree FE `travel-trust-network-mobile` và BE `../travel-trust-network-be`. Chỉ tài liệu trong thư mục này được tạo; không sửa mã nguồn BE/FE.

FE HEAD: `67a1c6351a4d706cc963781b744798d6d2aba4c3`. BE HEAD: `ebc296ba167c1c12ddd027e0b53349499b9f2a49`; BE có thay đổi sẵn ở cấu hình/tài liệu, nên nhận định áp dụng cho working tree đã đọc, không chỉ commit. Không sao chép giá trị secret hoặc dữ liệu cá nhân từ cấu hình/seed.

`IMPLEMENTED` nghĩa là có chuỗi xử lý trong source phù hợp phạm vi use case; **không có nghĩa đã chạy thành công end-to-end**. `PARTIAL`: có xử lý nhưng còn thiếu/sai một phần. `NOT_INTEGRATED`: BE đã có nhưng FE chưa dùng. `NOT_FOUND`: chức năng được tham chiếu nhưng không tìm thấy thực thi trong phạm vi đã quét. `UNKNOWN/NEEDS_VERIFICATION` dùng cho dữ kiện không đủ bằng chứng; `N/A` dùng cho tác vụ local không cần BE.

API-ID tham chiếu [API_SPECIFICATION.md](API_SPECIFICATION.md); Screen-ID, trạng thái mapping và điều hướng ở [UI_API_MAPPING.md](UI_API_MAPPING.md); hạn chế và kiểm thử ở [ANALYSIS_GAPS.md](ANALYSIS_GAPS.md). Source references là file thật, có symbol/line khi hữu ích. Hướng dẫn `hd.md` chỉ chứng minh chức năng từng được đề cập, không chứng minh đã triển khai.

## Màn hình và điều hướng

App dùng MaterialApp(home: AuthGate()), Navigator.push(MaterialPageRoute) và IndexedStack. Không thấy bảng named routes, GoRouter hay deep-link routing thực thi dù có dependency go_router. Đếm 11 màn nghiệp vụ + 2 shells; AuthScreen là form dùng chung S01/S02; VisitSummary và các card là component.

| ID | Screen / shell | Source | Điểm vào và state truyền |
| --- | --- | --- | --- |
| S01 | LoginScreen | [lib/views/auth/login_screen.dart](../../lib/views/auth/login_screen.dart) | AuthGate khi signedOut; AuthScreen(isRegistration:false). |
| S02 | RegisterScreen | [lib/views/auth/register_screen.dart](../../lib/views/auth/register_screen.dart) | AuthGate đổi _register; back gọi onLogin nếu không busy. |
| S03 | ProfileScreen | [lib/views/profile_screen.dart](../../lib/views/profile_screen.dart) | Tab Cá nhân index3; currentUser từ auth state. |
| S04 | EditProfileScreen | [lib/views/profile/edit_profile_screen.dart](../../lib/views/profile/edit_profile_screen.dart) | Push từ ProfileScreen, truyền currentUser. |
| S05 | ExploreScreen | [lib/views/places/explore_screen.dart](../../lib/views/places/explore_screen.dart) | Tab Khám phá index0; mặc định sau đăng nhập. |
| S06 | PlaceDetailScreen | [lib/views/places/place_detail_screen.dart](../../lib/views/places/place_detail_screen.dart) | Push từ card Explore, truyền placeId rồi tải detail. |
| S07 | VisitScreen | [lib/views/visits/visit_screen.dart](../../lib/views/visits/visit_screen.dart) | Từ detail/review với placeId; từ history thêm visitId/initialVisit; lối debug ở profile với TEST_PLACE_ID. |
| S08 | VisitHistoryScreen | [lib/views/visits/visit_history_screen.dart](../../lib/views/visits/visit_history_screen.dart) | Tab Chuyến đi index1 hoặc push từ Profile/Visit; cùng một màn. |
| S09 | CreateReviewScreen | [lib/views/reviews/create_review_screen.dart](../../lib/views/reviews/create_review_screen.dart) | Từ detail với placeId/placeName; từ history VERIFIED thêm initialVisitId. |
| S10 | LocketFeedScreen | [lib/views/locket/locket_feed_screen.dart](../../lib/views/locket/locket_feed_screen.dart) | Tab Locket index2; FAB mở SendLocketScreen. |
| S11 | SendLocketScreen | [lib/views/locket/send_locket_screen.dart](../../lib/views/locket/send_locket_screen.dart) | Push từ feed; caller hiện tại không truyền placeId/initialFilePath. |
| C01 | AuthGate (shell) | [lib/views/auth/auth_gate.dart](../../lib/views/auth/auth_gate.dart) | MaterialApp.home; switch auth states; mất auth thì popUntil first. |
| C02 | MainNavigationScreen (shell) | [lib/views/main_navigation_screen.dart](../../lib/views/main_navigation_screen.dart) | AuthGate mở khi authenticated; IndexedStack giữ 4 tab. |

AuthGate mở Explore mặc định sau login. IndexedStack dựng và giữ cả 4 tab; provider được watch có thể tải ngay khi khung chính được dựng. Chuyển tab không mặc nhiên invalidate cache. Không có Drawer, màn cài đặt widget, Studio hoặc bookmark route trong code thực thi.

## Bảng mapping thao tác

Endpoint đầy đủ có prefix /api/v1; FE baseUrl chứa prefix và service gọi suffix. Mọi request dưới đây đi qua ApiService; FE service tests override ApiService nên chưa chứng minh transport tới BE.

| Screen | User Action | FE Component/Function | HTTP Method | Endpoint | BE Controller | Application Service/Use Case | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| S02 | Đăng ký | [lib/views/auth/widgets/auth_screen.dart](../../lib/views/auth/widgets/auth_screen.dart) :: _submit → AuthController.register → AuthService.register | POST | `/api/v1/auth/register` | [AuthController.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/auth/controller/AuthController.java) | AuthServiceImpl.register / UC-01 | IMPLEMENTED source |
| S01 | Login email | [lib/views/auth/widgets/auth_screen.dart](../../lib/views/auth/widgets/auth_screen.dart) :: _submit → AuthController.login → AuthService.login | POST | `/api/v1/auth/login` | [AuthController.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/auth/controller/AuthController.java) | AuthServiceImpl.login / UC-02 | IMPLEMENTED source |
| S01 | Chọn Google | [lib/services/auth_service.dart](../../lib/services/auth_service.dart) :: signInWithGoogle → loginWithGoogleToken | POST | `/api/v1/auth/google` | [AuthController.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/auth/controller/AuthController.java) | AuthServiceImpl.loginWithGoogle → GoogleTokenVerifierImpl.verify / UC-03 | IMPLEMENTED source; Google thật chưa xác minh |
| C01 | Mở app/retry restore | [lib/controllers/auth_controller.dart](../../lib/controllers/auth_controller.dart) :: restoreSession → AuthService.getProfile | GET | `/api/v1/users/me/profile` | [UserProfileController.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/auth/controller/UserProfileController.java) | AuthServiceImpl.getProfile / UC-04 | IMPLEMENTED source |
| S03 | Refresh hồ sơ/điểm | [lib/views/profile_screen.dart](../../lib/views/profile_screen.dart) :: refreshProfile → AuthService.getProfile | GET | `/api/v1/users/me/profile` | [UserProfileController.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/auth/controller/UserProfileController.java) | AuthServiceImpl.getProfile / UC-06 | IMPLEMENTED source |
| S03/C01 | Đăng xuất | [lib/controllers/auth_controller.dart](../../lib/controllers/auth_controller.dart) :: logout → TokenStorage.clear | — | — | N/A | Local / UC-05 | IMPLEMENTED local; không revoke JWT |
| S04 | Lưu hồ sơ | [lib/views/profile/edit_profile_screen.dart](../../lib/views/profile/edit_profile_screen.dart) :: _saveProfile → AuthController.updateProfile → AuthService.updateProfile | PUT | `/api/v1/users/me/profile` | [UserProfileController.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/auth/controller/UserProfileController.java) | AuthServiceImpl.updateProfile / UC-07 | PARTIAL — G03/G04 |
| S05 | Tải/tìm/lọc/retry/refresh | [lib/views/places/explore_screen.dart](../../lib/views/places/explore_screen.dart) :: _onSearchChanged/_onCategorySelected → placesListProvider → PlaceService.searchPlaces | GET | `/api/v1/places` | [PlaceController.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/place/controller/PlaceController.java) | PlaceServiceImpl.search / UC-08 | IMPLEMENTED source |
| S05 → S06 | Chạm card; tải/retry detail | [lib/views/places/place_detail_screen.dart](../../lib/views/places/place_detail_screen.dart) :: placeDetailProvider → PlaceService.getPlaceDetail | GET | `/api/v1/places/{id}` | [PlaceController.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/place/controller/PlaceController.java) | PlaceServiceImpl.getDetail / UC-09 | IMPLEMENTED source |
| S06 → S07/S09 | Chọn Check-in/Viết đánh giá | [lib/views/places/place_detail_screen.dart](../../lib/views/places/place_detail_screen.dart) :: Navigator.push VisitScreen/CreateReviewScreen | — | — | N/A | Local navigation / UC-09 | Request phát sinh tại màn đích |
| S07 | Check-in | [lib/views/visits/visit_screen.dart](../../lib/views/visits/visit_screen.dart) :: _checkIn → LocationService.getCurrentPosition → VisitService.checkIn | POST | `/api/v1/visits/check-in` | [VisitController.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/visit/controller/VisitController.java) | VisitServiceImpl.checkIn / UC-10 | IMPLEMENTED source |
| S07 | Check-out | [lib/views/visits/visit_screen.dart](../../lib/views/visits/visit_screen.dart) :: _checkOut → VisitService.checkOut | PUT | `/api/v1/visits/{visitId}/check-out` | [VisitController.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/visit/controller/VisitController.java) | VisitServiceImpl.checkOut / UC-11 | IMPLEMENTED source |
| S07 | Sau checkout/reload VERIFIED | [lib/views/visits/visit_screen.dart](../../lib/views/visits/visit_screen.dart) :: _checkOut/_reloadVisit → AuthController.refreshProfile | GET | `/api/v1/users/me/profile` | [UserProfileController.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/auth/controller/UserProfileController.java) | AuthServiceImpl.getProfile / UC-11/UC-13 | Mutation/profile request độc lập |
| S08 | Tải/refresh/retry history | [lib/views/visits/visit_history_screen.dart](../../lib/views/visits/visit_history_screen.dart) :: visitHistoryProvider → VisitService.getMyHistory | GET | `/api/v1/visits/my-history` | [VisitController.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/visit/controller/VisitController.java) | VisitServiceImpl.getMyHistory / UC-12 | IMPLEMENTED source |
| S08 → S07/S09 | Chọn OPEN/viết review VERIFIED | [lib/views/visits/visit_history_screen.dart](../../lib/views/visits/visit_history_screen.dart) :: Navigator.push với visitId/initialVisit hoặc initialVisitId | — | — | N/A | Local navigation / UC-12 | Eligibility vẫn kiểm tại BE |
| S07 | Reload sau conflict/timeout/resume | [lib/views/visits/visit_screen.dart](../../lib/views/visits/visit_screen.dart) :: _reloadVisit → VisitService.getMyHistory; tìm id hoặc OPEN | GET | `/api/v1/visits/my-history` | [VisitController.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/visit/controller/VisitController.java) | VisitServiceImpl.getMyHistory / UC-13 | Không có endpoint get-by-id |
| S09 | Tải chuyến đi đủ điều kiện | [lib/views/reviews/create_review_screen.dart](../../lib/views/reviews/create_review_screen.dart) :: visitHistoryProvider; lọc cùng place, VERIFIED | GET | `/api/v1/visits/my-history` | [VisitController.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/visit/controller/VisitController.java) | VisitServiceImpl.getMyHistory / UC-14 | Có thể dùng cache provider |
| S09 | Đăng review/có URL ảnh | [lib/views/reviews/create_review_screen.dart](../../lib/views/reviews/create_review_screen.dart) :: _submitReview → ReviewService.createReview | POST | `/api/v1/reviews` | [ReviewController.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/review_locket/controller/ReviewController.java) | ReviewServiceImpl.create / UC-14/UC-15 | PARTIAL — G01/G02/G05/G06 |
| S09 | Sau review refresh điểm | [lib/views/reviews/create_review_screen.dart](../../lib/views/reviews/create_review_screen.dart) :: _submitReview → AuthController.refreshProfile | GET | `/api/v1/users/me/profile` | [UserProfileController.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/auth/controller/UserProfileController.java) | AuthServiceImpl.getProfile / UC-14 | Không đối soát review nếu response mutation mất |
| S11 | Chụp/chọn ảnh | [lib/views/locket/send_locket_screen.dart](../../lib/views/locket/send_locket_screen.dart) :: _pick → ImagePicker.pickImage; preview Image.file | — | — | N/A | OS camera/gallery / UC-16 | Source có; thiết bị chưa thử |
| S11 | Gửi: upload | [lib/views/locket/send_locket_screen.dart](../../lib/views/locket/send_locket_screen.dart) :: _send → LocketService.uploadImage → ApiService.upload | POST | `/api/v1/media/upload` | [MediaController.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/media/controller/MediaController.java) | MediaStorageServiceImpl.upload / UC-16 | Multipart HTTP NEEDS_VERIFICATION |
| S11 | Gửi: tạo signal | [lib/views/locket/send_locket_screen.dart](../../lib/views/locket/send_locket_screen.dart) :: _send → LocketService.sendSignal | POST | `/api/v1/locket/send-signal` | [LocketController.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/review_locket/controller/LocketController.java) | LocketServiceImpl.sendSignal / UC-17 | IMPLEMENTED cho feed chung |
| S10 | Tải/pull refresh/retry | [lib/views/locket/locket_feed_screen.dart](../../lib/views/locket/locket_feed_screen.dart) :: locketFeedProvider → LocketService.getFeed | GET | `/api/v1/locket/feed` | [LocketController.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/review_locket/controller/LocketController.java) | LocketServiceImpl.getFeed / UC-18 | Pull top20 toàn hệ thống |

## Chuỗi thao tác → FE → BE → response → UI

### Email và session

Actor submit S01/S02 → AuthScreen._submit → AuthController.login/register → AuthService → ApiService.post → AuthController BE → AuthServiceImpl → UserRepository/PasswordEncoder, log khi register → ApiResponse<AuthResponse> → ApiService unwrap data → AuthSession.fromJson → secure storage write → authenticated → AuthGate → MainNavigationScreen.

Form lỗi dừng trước HTTP. Lỗi BE chuyển thành auth.error. Lỗi ghi secure storage không mở phiên UI dù BE có thể đã tạo user. Khôi phục phiên: Actor mở app → AuthController.restoreSession → TokenStorage.read → AuthService.getProfile → UserProfileController.profile → AuthServiceImpl.getProfile → UserProfileResponse → authenticated state. Profile 401/404 xóa phiên; network/5xx giữ token trên đĩa, vào restoreFailed. Logout chỉ TokenStorage.clear, không có REST logout.

### Google

Actor chọn Google → GoogleSignIn SDK authenticate → ID token → AuthService.loginWithGoogleToken → POST /auth/google → AuthController.googleLogin → AuthServiceImpl.loginWithGoogle → GoogleTokenVerifierImpl → HTTPS Google tokeninfo **đồng bộ** → kiểm aud/iss/email_verified/email/exp → lưu User/log → JWT/profile → FE persist và đổi auth state. Hủy SDK trả null. Không có Kafka/WebSocket hoặc callback OAuth REST trong repo.

### Khám phá và chi tiết

Actor nhập/chọn filter S05 → debounce/chip handler → placesListProvider → PlaceService.searchPlaces → ApiService.getList → PlaceController.search → PlaceServiceImpl.search → native repository query (loại hidden, ILIKE tên/địa chỉ, equality category) → ApiResponse<List<PlaceSummaryResponse>> → parse list → cards.

Actor chạm card → Navigator với placeId → placeDetailProvider → GET detail → PlaceController.detail → PlaceServiceImpl.getDetail → kiểm tồn tại/hidden và chỉ giữ review verified → PlaceDetailModel → nội dung/ảnh/reviews. Chọn nút tiếp theo chỉ push VisitScreen hoặc CreateReviewScreen, không gọi mutation ngay trên detail.

### Visit và đối soát

Actor check-in S07 → _checkIn → LocationService/Geolocator → VisitService.checkIn → ApiService.post → VisitController.checkIn → VisitServiceImpl.checkIn → User lock, rule checks/Haversine → Visit OPEN → VisitResponse → FE _visit và invalidate history.

Actor check-out → _checkOut → VisitService.checkOut → PUT không body → VisitController.checkOut → VisitServiceImpl.checkOut → User/Visit lock, kiểm owner/time/status → VERIFIED + User score + TrustScoreLog cùng transaction → FE summary/history → GET profile → state điểm mới. **Checkout không lấy GPS mới** và không tự chuyển sang Studio/form review.

Mutation đã gửi nhưng response không chắc chắn → _showError bật _needsConfirmation → Actor reload → _reloadVisit → GET history → BE getMyHistory → tìm id hoặc OPEN → cập nhật UI trước khi cho lặp thao tác. Không có idempotency key hoặc GET visit-by-id; timeout không chứng minh server chưa xử lý.

### Review và signal tự động

Actor mở S09 → history provider (có thể có cache) → lọc VERIFIED cùng place → Actor chọn visit/rating/comment/URL tùy chọn → _submitReview → ReviewService.createReview → POST /reviews → ReviewController.create → ReviewServiceImpl.create → lock User/Place, kiểm eligibility/duplicate → ReviewRepository save, aggregate rating/count + User score + TrustScoreLog + **LocketSignalRepository.save nếu có ảnh trong cùng transaction** → ReviewResponse → FE invalidate detail/history, refresh profile → pop(true).

Handler không gọi POST /locket/send-signal; BE tự ghi signal. Không invalidate feed hoặc Explore list, nên tab đang được giữ có thể hiển thị dữ liệu cũ. Form review nhận URL nhập tay, không có upload/picker/Studio. Nội dung 360 chỉ có checkbox.

### Gửi ảnh Locket trực tiếp

Actor chọn camera/gallery S11 → _pick → ImagePicker → preview → Actor bấm Gửi → _send → LocketService.uploadImage → ApiService.upload/FormData → MediaController.upload → MediaStorageServiceImpl.upload → filesystem với tên UUID → MediaUploadResponse.url → LocketService.sendSignal → LocketController.sendSignal → LocketServiceImpl.sendSignal → LocketSignalRepository → LocketSignalResponse → invalidate feed → snackbar/pop.

Hai request độc lập: upload thành công rồi signal thất bại để lại file; retry upload lại. Không thấy cleanup API hoặc idempotency. Màn mở từ feed không có placeId/initialFilePath; không có recipient picker. API service hỗ trợ is360Image nhưng màn gửi dùng false mặc định.

### Đọc Locket

Actor mở/refresh S10 → locketFeedProvider → LocketService.getFeed → ApiService.getList → LocketController.feed → LocketServiceImpl.getFeed → top20 sentAt desc toàn hệ thống → LocketSignalResponse[] → model → grid. URL /uploads/... được resolve theo origin; cờ360 chỉ có badge. Đây là pull REST; không có background subscription/push/widget.

## Kiểm tra hợp đồng và độ phủ

| Hạng mục | Kết quả từ đối chiếu |
| --- | --- |
| BE endpoint chưa có FE caller | 0/14 trong source. Không áp NOT_INTEGRATED cho toàn endpoint. |
| FE method/path không có trong BE | 0 phát hiện, sau khi ghép baseUrl và suffix. |
| Body auth/profile/visit/review/signal | Field names khớp DTO; checkout không body khớp controller; upload dùng part file. Chưa xác nhận mọi payload qua HTTP. |
| Response envelope | ApiResponse.success/code/message/data/timestamp tương thích ApiService unwrap; list/object phân biệt; AuthSession đòi accessToken/userProfile. |
| Boolean | BE record có is360Media/isVerifiedReview/is360Image; Visit isVerified có @JsonProperty và unit test serialize. FE VisitModel dựa status, không parse isVerified. |
| Field chưa dùng | Profile log previousScore/policyVersion; Visit userId/lat/lng/accuracy/isMocked/isVerified; Locket senderId/avatar/receiverId/placeId có trong DTO nhưng FE model chỉ dùng subset. Đây không phải endpoint chưa tích hợp. |
| Public API và auth UI | BE places public; FE chỉ có điểm vào bên trong AuthGate authenticated. Không có role ADMIN/USER trong BE/UI. |
| 401 handling | Callback ApiService chỉ tự expire cho /visits/. AuthController còn xử lý profile 401/404. Review/upload/feed/signal 401 chỉ hiện lỗi, không có cùng cơ chế expire chung (G07). |
| UI chưa đồng bộ | Sau review, detail/history/profile được cập nhật; Explore aggregate và Locket feed có thể cũ (G01/G02). |
| Lưu hồ sơ | updateProfile có guard/nhánh expire không throw; form có thể hiểu Future hoàn tất là lưu thành công (G04). |

### Form validation FE và BE

| Field / thao tác | FE | BE | Nhận định |
| --- | --- | --- | --- |
| Email login/register | trim, max150, regex bắt buộc dấu chấm trong domain | @Email/@NotBlank/max150; service normalize | Không cùng validator; trường hợp biên NEEDS_VERIFICATION. Không giới hạn Gmail dù label UI ghi Gmail. |
| Tên đăng ký | trim nonempty/max150 | DTO nonblank/max150, service trim | Payload FE đã trim; tương thích đường UI thường. |
| Password đăng ký | rỗng/ngoài8–128 bị chặn; confirm equality | @NotBlank và size8–128 | Chuỗi toàn whitespace đủ dài có thể qua FE nhưng BE từ chối; confirm chỉ FE. |
| Password login | rỗng/max128, không min8 | @NotBlank/max128 | Whitespace mismatch như trên; tài khoản không có hash bị401. |
| Sửa tên/bio/avatar | tên trim nonempty/maxLength150; bio maxLength500; URL tự do | tên nonblank/max150; bio max500; avatar tự do | Giới hạn tương thích; URL tương đối ở profile chưa resolve (G03). |
| GPS | tọa độ Geolocator; không có form nhập tay | range/positive, service finite/radius/mock/open | BE enforce rule; accuracy không có ngưỡng tối đa. |
| Rating | 5 star controls; default5 | required integer1–5, DTO/service | Tương thích đường UI; sai DTO thường trả VALIDATION_ERROR trước INVALID_RATING. |
| Comment review | trim nonempty/min5 | @NotBlank; không min5/max trong DTO | FE chặt hơn (G05). |
| URL review/cờ360 | URL tùy chọn và checkbox | không validate URL/ảnh360; null flag→false | Không chứng minh đã upload hoặc là panorama thật. |
| Caption Locket | maxLength200, trim; bỏ field nếu rỗng | @Size200 và service check | Giới hạn tương thích. |
| File upload | ImagePicker resize/quality; không prevalidate size/signature | max20MiB/signature JPEG/PNG/WebP; servlet limits | Validation bổ sung ở BE; lỗi multipart trước service chưa kiểm HTTP. |

Chứng cứ FE: [lib/views/auth/widgets/auth_screen.dart:38](../../lib/views/auth/widgets/auth_screen.dart#L38); [lib/views/profile/edit_profile_screen.dart:44](../../lib/views/profile/edit_profile_screen.dart#L44); [lib/views/reviews/create_review_screen.dart:60](../../lib/views/reviews/create_review_screen.dart#L60); [lib/views/locket/send_locket_screen.dart:61](../../lib/views/locket/send_locket_screen.dart#L61). DTO và service source đầy đủ ở [API_SPECIFICATION.md](API_SPECIFICATION.md).

## Luồng chưa có thực thi

UC-19 Studio, UC-20 panorama tương tác, UC-21 FCM/HomeWidget và UC-22 offline được tham chiếu trong hướng dẫn/dependencies; không có handler hoàn chỉnh. Locket receiver có ở entity/response nhưng DTO request không nhận và service không gán receiver. Không thể kết luận feed này dành riêng cho bạn bè hay signal là push thời gian thực.

State thực tế: AuthController là Riverpod Notifier; các dịch vụ có Provider và list/history/feed/detail dùng FutureProvider/autoDispose; màn Visit/Review/Send/Edit có local state. Phần lớn màn gọi service qua provider trực tiếp, không có place_controller/visit_controller riêng như hướng dẫn hd.md. Chưa có SQLite persistence cho nghiệp vụ; secure storage chỉ giữ JWT.

