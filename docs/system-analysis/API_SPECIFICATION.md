# API Specification

Ngày phân tích: 2026-11-05 (Asia/Saigon). Phạm vi: working tree FE `travel-trust-network-mobile` và BE `../travel-trust-network-be`. Chỉ tài liệu trong thư mục này được tạo; không sửa mã nguồn BE/FE.

FE HEAD: `67a1c6351a4d706cc963781b744798d6d2aba4c3`. BE HEAD: `ebc296ba167c1c12ddd027e0b53349499b9f2a49`; BE có thay đổi sẵn ở cấu hình/tài liệu, nên nhận định áp dụng cho working tree đã đọc, không chỉ commit. Không sao chép giá trị secret hoặc dữ liệu cá nhân từ cấu hình/seed.

`IMPLEMENTED` nghĩa là có chuỗi xử lý trong source phù hợp phạm vi use case; **không có nghĩa đã chạy thành công end-to-end**. `PARTIAL`: có xử lý nhưng còn thiếu/sai một phần. `NOT_INTEGRATED`: BE đã có nhưng FE chưa dùng. `NOT_FOUND`: chức năng được tham chiếu nhưng không tìm thấy thực thi trong phạm vi đã quét. `UNKNOWN/NEEDS_VERIFICATION` dùng cho dữ kiện không đủ bằng chứng; `N/A` dùng cho tác vụ local không cần BE.

API-ID tham chiếu [API_SPECIFICATION.md](API_SPECIFICATION.md); Screen-ID, trạng thái mapping và điều hướng ở [UI_API_MAPPING.md](UI_API_MAPPING.md); hạn chế và kiểm thử ở [ANALYSIS_GAPS.md](ANALYSIS_GAPS.md). Source references là file thật, có symbol/line khi hữu ích. Hướng dẫn `hd.md` chỉ chứng minh chức năng từng được đề cập, không chứng minh đã triển khai.

## Phạm vi và chứng cứ kiểm thử

Có **14** REST endpoints nghiệp vụ trong 7 controllers. Danh sách được lấy từ annotation controller, kiểm tra tiếp DTO/service/security/repository; không lấy danh mục API trong README/AGENTS làm hợp đồng thực thi.

- Đã chạy: 34 BE unit tests (8 lớp) và 8 FE tests. Tất cả pass. BE dùng Mockito; upload ghi vào thư mục tạm; FE service tests override ApiService nên không chạy Dio/interceptor/envelope hay kết nối BE.
- Chưa chạy: `EmailPasswordAuthHttpTests`, `TravelTrustNetworkBeApplicationTests`, HTTP với PostgreSQL, emulator/thiết bị, Google thật, multipart qua servlet. Không có API nào được gắn nhãn HTTP/E2E đã xác minh.
- Riêng `VisitServiceImplTests.checkoutAwardsPointsAndRecordsAuditExactlyOnce` còn serialize DTO và assert JSON `isVerified`; đây là kiểm chứng một field serialization, không phải toàn bộ HTTP response.
- Chi tiết lệnh, kết quả và giới hạn ở [ANALYSIS_GAPS.md](ANALYSIS_GAPS.md).

## Hợp đồng chung

| Thuộc tính | Triển khai thực tế |
| --- | --- |
| URL | FE mặc định origin Android emulator, base path `/api/v1`; cấu hình bằng API_BASE_URL. Endpoint dưới đây ghi đầy đủ prefix; ApiService dùng path tương đối bắt đầu /auth, /places, ... |
| JSON headers | `Accept: application/json`; request JSON `Content-Type: application/json`. Không cần body/Content-Type cho GET theo hợp đồng BE; FE vẫn cấu hình mặc định JSON. |
| Authentication | `Authorization: Bearer &lt;JWT&gt;` cho protected endpoint; public auth/places không yêu cầu token. FE chủ động không thêm Bearer cho /auth/. |
| Roles | Không có role-based authorization: CustomUserDetails.getAuthorities trả list rỗng; SecurityConfig kiểm authenticated. Ownership được service visit/review kiểm riêng. |
| JWT | Access JWT kiểm signature, expiration, subject UUID và email; mặc định 15 phút. Refresh token xoay vòng lưu bản băm trong DB, tối đa 30 ngày. Có `POST /auth/refresh` và `/auth/logout`; xem `docs/AUTH_SESSIONS.md`. Logout thu hồi refresh, access JWT còn hiệu lực đến expiry. |
| Thành công | Tất cả controller trả trực tiếp ApiResponse, mặc định HTTP 200; không khai báo 201/204. Envelope `{success:true, code:"SUCCESS", message:string, data:T, timestamp:LocalDateTime}`. |
| Lỗi | `{success:false, code:string, message:string, data:null, timestamp:LocalDateTime}`. Message validation ghép field và message; không có errors[] riêng. |
| FE decode | ApiService bắt buộc envelope object và success==true, unwrap data; get/post/put/upload yêu cầu object, getList yêu cầu List. Request có timeout connect/send/receive 15s. |
| Time | DTO BE dùng LocalDateTime, không offset timezone; FE parse DateTime và một số màn gọi toLocal. Không khẳng định timestamp là UTC. |
| Multipart | Content-Type multipart/form-data với boundary; binary part `file`. FormData được Dio transform sang multipart kể cả BaseOptions JSON; cần test HTTP để xác nhận transport thực tế. |

Chứng cứ: [src/main/java/fu/prm393/common/dto/ApiResponse.java](../../../travel-trust-network-be/src/main/java/fu/prm393/common/dto/ApiResponse.java); [src/main/java/fu/prm393/common/security/SecurityConfig.java](../../../travel-trust-network-be/src/main/java/fu/prm393/common/security/SecurityConfig.java); [src/main/java/fu/prm393/common/security/CustomUserDetails.java](../../../travel-trust-network-be/src/main/java/fu/prm393/common/security/CustomUserDetails.java); [src/main/java/fu/prm393/common/security/JwtAuthenticationFilter.java](../../../travel-trust-network-be/src/main/java/fu/prm393/common/security/JwtAuthenticationFilter.java); [src/main/java/fu/prm393/common/security/JwtTokenProvider.java](../../../travel-trust-network-be/src/main/java/fu/prm393/common/security/JwtTokenProvider.java); [lib/services/api_service.dart](../../lib/services/api_service.dart); [lib/config/app_config.dart](../../lib/config/app_config.dart). Kiểm tra FormData còn đối chiếu mã dependency Dio 5.11.1 `lib/src/dio_mixin.dart:717–720` trong package cache được package_config trỏ tới; đây là dependency, không phải file repo.

### HTTP status / error code chung

| HTTP | Code / trigger trong source |
| --- | --- |
| 400 | DTO/binding -> VALIDATION_ERROR; mặc định BusinessRuleException gồm HIDDEN_PLACE, INVALID_CHECKOUT_TIME, GPS_OUT_OF_RADIUS, MOCK_LOCATION_DETECTED, UNVERIFIED_VISIT, INVALID_RATING. |
| 401 | UNAUTHORIZED từ security entrypoint, authentication exception hoặc business rule. |
| 403 | FORBIDDEN từ security access denied hoặc check-out khác owner. Review khác owner trả 400 UNVERIFIED_VISIT. |
| 404 | RESOURCE_NOT_FOUND do service ném; không suy rộng mọi route không tồn tại thành JSON 404 vì catch-all advice/framework cần kiểm chứng. |
| 409 | DUPLICATE_EMAIL, SINGLE_OPEN_VISIT, ALREADY_CHECKED_OUT, DUPLICATE_REVIEW. |
| 500 | Unexpected Exception -> INTERNAL_SERVER_ERROR; lỗi IO upload, overflow số nguyên và lỗi DB không được map riêng cũng có thể vào nhánh này. |

Chứng cứ: [src/main/java/fu/prm393/common/exception/GlobalExceptionHandler.java](../../../travel-trust-network-be/src/main/java/fu/prm393/common/exception/GlobalExceptionHandler.java); [src/main/java/fu/prm393/common/enums/ErrorCode.java](../../../travel-trust-network-be/src/main/java/fu/prm393/common/enums/ErrorCode.java). Các bảng status là hành vi suy ra từ code, chưa phải kết quả HTTP đã chạy.

## Response DTO dictionary

Ký hiệu `?` thể hiện dữ liệu có thể null theo mapping/entity hoặc wrapper không có guarantee nonnull; DTO record Java không tự có validation response. UUID được truyền dạng chuỗi; LocalDateTime là chuỗi date-time khi serialize. Đây là field/type khai báo, không phải response mẫu thu từ server.

| DTO | Fields trong data | Source |
| --- | --- | --- |
| AuthResponse | accessToken:string; userProfile:UserProfileResponse | [src/main/java/fu/prm393/modules/auth/dto/response/AuthResponse.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/auth/dto/response/AuthResponse.java) |
| UserProfileResponse | id:UUID; email:string; fullName:string; avatarUrl:string?; bio:string?; trustScore:Integer; verifiedVisitCount:long; trustScoreLogs:List&lt;TrustScoreLogResponse&gt;; createdAt:LocalDateTime | [src/main/java/fu/prm393/modules/auth/dto/response/UserProfileResponse.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/auth/dto/response/UserProfileResponse.java) |
| TrustScoreLogResponse | id:UUID; previousScore:Integer; delta:Integer; newScore:Integer; reason:string; policyVersion:string; createdAt:LocalDateTime | [src/main/java/fu/prm393/modules/auth/dto/response/TrustScoreLogResponse.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/auth/dto/response/TrustScoreLogResponse.java) |
| PlaceSummaryResponse | id:UUID; name:string; category:string; address:string; imageUrl:string?; averageRating:Double; verifiedReviewCount:Integer | [src/main/java/fu/prm393/modules/place/dto/response/PlaceSummaryResponse.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/place/dto/response/PlaceSummaryResponse.java) |
| PlaceDetailResponse | id:UUID; name:string; category:string; description:string?; address:string; imageUrl:string?; openingHours:string?; latitude:Double; longitude:Double; allowedRadiusM:Double; averageRating:Double; verifiedReviewCount:Integer; reviews:List&lt;ReviewResponse&gt; | [src/main/java/fu/prm393/modules/place/dto/response/PlaceDetailResponse.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/place/dto/response/PlaceDetailResponse.java) |
| VisitResponse | id:UUID; userId:UUID; placeId:UUID; placeName:string; placeImageUrl:string?; checkInTime:LocalDateTime; checkOutTime:LocalDateTime?; userLat:Double; userLng:Double; gpsAccuracy:Double?; distanceMeters:Double; isMocked:boolean; status:OPEN\|VERIFIED\|REJECTED; rejectionReason:string?; isVerified:boolean (explicit @JsonProperty) | [src/main/java/fu/prm393/modules/visit/dto/response/VisitResponse.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/visit/dto/response/VisitResponse.java) |
| ReviewResponse | id:UUID; userId:UUID; fullName:string; avatarUrl:string?; placeId:UUID; visitId:UUID; rating:Integer; comment:string; postcardImageUrl:string?; is360Media:boolean; isVerifiedReview:boolean; createdAt:LocalDateTime | [src/main/java/fu/prm393/modules/review_locket/dto/response/ReviewResponse.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/review_locket/dto/response/ReviewResponse.java) |
| MediaUploadResponse | url:string (relative /uploads/...); filename:string; contentType:string; size:long bytes | [src/main/java/fu/prm393/modules/media/dto/response/MediaUploadResponse.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/media/dto/response/MediaUploadResponse.java) |
| LocketSignalResponse | id:UUID; senderId:UUID; senderName:string; senderAvatarUrl:string?; receiverId:UUID?; placeId:UUID?; placeName:string?; imageUrl:string; caption:string?; is360Image:boolean; sentAt:LocalDateTime | [src/main/java/fu/prm393/modules/review_locket/dto/response/LocketSignalResponse.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/review_locket/dto/response/LocketSignalResponse.java) |

## Endpoint index

| API ID | Module | Method | Endpoint | Auth required | Related use cases |
| --- | --- | --- | --- | --- | --- |
| API-01 | auth | POST | `/api/v1/auth/register` | Không | UC-01 |
| API-02 | auth | POST | `/api/v1/auth/login` | Không | UC-02 |
| API-03 | auth | POST | `/api/v1/auth/google` | Không | UC-03 |
| API-04 | auth | GET | `/api/v1/users/me/profile` | JWT | UC-04, UC-06, UC-11, UC-13, UC-14 |
| API-05 | auth | PUT | `/api/v1/users/me/profile` | JWT | UC-07 |
| API-06 | place | GET | `/api/v1/places` | Không | UC-08 |
| API-07 | place | GET | `/api/v1/places/{id}` | Không | UC-09 |
| API-08 | visit | POST | `/api/v1/visits/check-in` | JWT | UC-10 |
| API-09 | visit | PUT | `/api/v1/visits/{visitId}/check-out` | JWT | UC-11 |
| API-10 | visit | GET | `/api/v1/visits/my-history` | JWT | UC-12, UC-13, UC-14 |
| API-11 | review_locket | POST | `/api/v1/reviews` | JWT | UC-14, UC-15 |
| API-12 | media | POST | `/api/v1/media/upload` | JWT | UC-16, UC-17 |
| API-13 | review_locket | POST | `/api/v1/locket/send-signal` | JWT | UC-17 |
| API-14 | review_locket | GET | `/api/v1/locket/feed` | JWT | UC-18 |

## API-01 — POST /api/v1/auth/register

| Field | Specification |
| --- | --- |
| API ID | API-01 |
| Module | auth |
| HTTP Method | POST |
| Endpoint | `/api/v1/auth/register` |
| Description | Đăng ký và phát hành JWT. |
| Authentication Required | Không — SecurityConfig permitAll cho auth/places. |
| Authorization / Roles | Public, không role. Không có ownership bổ sung cho endpoint này ngoài userId hiện tại nếu service sử dụng. |
| Headers | Accept: application/json; Content-Type: application/json; Authorization không bắt buộc. |
| Path Parameters | Không có. |
| Query Parameters | Không có. |
| Request Body | EmailRegisterRequest: {email:string, fullName:string, password:string}. Không gửi confirmPassword. |
| Response Body | HTTP 200: envelope chung, data = `AuthResponse` theo DTO dictionary; lỗi: data=null, code/message theo bảng status. |
| HTTP Status Codes | 200 SUCCESS; 400 VALIDATION_ERROR; 409 DUPLICATE_EMAIL; 500 INTERNAL_SERVER_ERROR. |
| Validation Rules | @NotBlank/@Email/@Size(max=150) email; tên @NotBlank/max150; password @NotBlank/min8/max128. Email normalize trim/lowercase; tên trim; hash PBKDF2; kiểm tra duplicate trước save và map DataIntegrityViolationException thành DUPLICATE_EMAIL. |
| Related Use Cases | UC-01 |
| Frontend Usage | AuthScreen._submit → AuthController.register → AuthService.register → ApiService.post; AuthSession.fromJson; lưu secure token rồi cập nhật auth state. |
| Controller → Service | AuthController::register → register ở auth/service/impl/AuthServiceImpl.java. |
| Declared vs tested response | BE EmailPasswordAuthServiceTests: hash, normalize, token và duplicate (unit chạy). EmailPasswordAuthHttpTests có assert HTTP 200/409/400 nhưng CHƯA CHẠY. HTTP/E2E: NEEDS_VERIFICATION. |
| Source Code References | [src/main/java/fu/prm393/modules/auth/controller/AuthController.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/auth/controller/AuthController.java); [auth/service/impl/AuthServiceImpl.java :: register](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/auth/service/impl/AuthServiceImpl.java); [src/main/java/fu/prm393/modules/auth/dto/request/EmailRegisterRequest.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/auth/dto/request/EmailRegisterRequest.java); [src/main/java/fu/prm393/modules/auth/dto/response/AuthResponse.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/auth/dto/response/AuthResponse.java); security/envelope/exception mapping theo phần hợp đồng chung. |

## API-02 — POST /api/v1/auth/login

| Field | Specification |
| --- | --- |
| API ID | API-02 |
| Module | auth |
| HTTP Method | POST |
| Endpoint | `/api/v1/auth/login` |
| Description | Đăng nhập email/password. |
| Authentication Required | Không — SecurityConfig permitAll cho auth/places. |
| Authorization / Roles | Public, không role. Không có ownership bổ sung cho endpoint này ngoài userId hiện tại nếu service sử dụng. |
| Headers | Accept: application/json; Content-Type: application/json; Authorization không bắt buộc. |
| Path Parameters | Không có. |
| Query Parameters | Không có. |
| Request Body | EmailLoginRequest: {email:string, password:string}. |
| Response Body | HTTP 200: envelope chung, data = `AuthResponse` theo DTO dictionary; lỗi: data=null, code/message theo bảng status. |
| HTTP Status Codes | 200 SUCCESS; 400 VALIDATION_ERROR; 401 UNAUTHORIZED; 500 INTERNAL_SERVER_ERROR. |
| Validation Rules | Email nonblank/đúng email/max150; password nonblank/max128, không min8. Hash dummy được kiểm tra cả khi user không tồn tại/không có hash; cùng thông báo cho credential sai. |
| Related Use Cases | UC-02 |
| Frontend Usage | AuthScreen._submit → AuthController.login → AuthService.login; parse AuthSession và lưu JWT. |
| Controller → Service | AuthController::login → login ở auth/service/impl/AuthServiceImpl.java. |
| Declared vs tested response | BE EmailPasswordAuthServiceTests: đúng/sai mật khẩu, user không có, Google-only user (unit chạy). HTTP test có 200/401, chưa chạy. HTTP/E2E: NEEDS_VERIFICATION. |
| Source Code References | [src/main/java/fu/prm393/modules/auth/controller/AuthController.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/auth/controller/AuthController.java); [auth/service/impl/AuthServiceImpl.java :: login](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/auth/service/impl/AuthServiceImpl.java); [src/main/java/fu/prm393/modules/auth/dto/request/EmailLoginRequest.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/auth/dto/request/EmailLoginRequest.java); [src/main/java/fu/prm393/modules/auth/dto/response/AuthResponse.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/auth/dto/response/AuthResponse.java); security/envelope/exception mapping theo phần hợp đồng chung. |

## API-03 — POST /api/v1/auth/google

| Field | Specification |
| --- | --- |
| API ID | API-03 |
| Module | auth |
| HTTP Method | POST |
| Endpoint | `/api/v1/auth/google` |
| Description | Đổi Google ID token thành phiên ứng dụng. |
| Authentication Required | Không — SecurityConfig permitAll cho auth/places. |
| Authorization / Roles | Public, không role. Không có ownership bổ sung cho endpoint này ngoài userId hiện tại nếu service sử dụng. |
| Headers | Accept: application/json; Content-Type: application/json; Authorization không bắt buộc. |
| Path Parameters | Không có. |
| Query Parameters | Không có. |
| Request Body | GoogleLoginRequest: {email:string, fullName:string, avatarUrl?:string hoặc null, idToken:string, fcmToken?:string hoặc null}. |
| Response Body | HTTP 200: envelope chung, data = `AuthResponse` theo DTO dictionary; lỗi: data=null, code/message theo bảng status. |
| HTTP Status Codes | 200 SUCCESS; 400 VALIDATION_ERROR; 401 UNAUTHORIZED (kể cả BE thiếu cấu hình Google); 500 INTERNAL_SERVER_ERROR. |
| Validation Rules | Email @NotBlank/@Email/max150; tên @NotBlank/max150; idToken @NotBlank. GoogleTokenVerifierImpl kiểm tra tokeninfo aud/iss/email_verified/email/exp; timeout connect/read 5s. fcmToken/avatar không có URL/token-length constraint tại DTO. |
| Related Use Cases | UC-03 |
| Frontend Usage | AuthController.signInWithGoogle → AuthService.signInWithGoogle dùng SDK; loginWithGoogleToken gửi fcmToken:null. Không có HTTP redirect/callback endpoint. |
| Controller → Service | AuthController::googleLogin → loginWithGoogle ở auth/service/impl/AuthServiceImpl.java. |
| Declared vs tested response | BE AuthServiceImplTests: new/returning user và reject verifier; GoogleTokenVerifier được mock. Không xác minh Google thật hoặc JSON qua HTTP. HTTP/E2E: NEEDS_VERIFICATION. |
| Source Code References | [src/main/java/fu/prm393/modules/auth/controller/AuthController.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/auth/controller/AuthController.java); [auth/service/impl/AuthServiceImpl.java :: loginWithGoogle](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/auth/service/impl/AuthServiceImpl.java); [src/main/java/fu/prm393/modules/auth/dto/request/GoogleLoginRequest.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/auth/dto/request/GoogleLoginRequest.java); [src/main/java/fu/prm393/modules/auth/dto/response/AuthResponse.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/auth/dto/response/AuthResponse.java); security/envelope/exception mapping theo phần hợp đồng chung. |

## API-04 — GET /api/v1/users/me/profile

| Field | Specification |
| --- | --- |
| API ID | API-04 |
| Module | auth |
| HTTP Method | GET |
| Endpoint | `/api/v1/users/me/profile` |
| Description | Lấy profile cá nhân, số visit VERIFIED và audit điểm. |
| Authentication Required | Có — Bearer JWT hợp lệ. |
| Authorization / Roles | authenticated, không role. Không có ownership bổ sung cho endpoint này ngoài userId hiện tại nếu service sử dụng. |
| Headers | Accept: application/json; Authorization: Bearer &lt;JWT&gt;. |
| Path Parameters | Không có. |
| Query Parameters | Không có. |
| Request Body | Không có. |
| Response Body | HTTP 200: envelope chung, data = `UserProfileResponse` theo DTO dictionary; lỗi: data=null, code/message theo bảng status. |
| HTTP Status Codes | 200 SUCCESS; 401 UNAUTHORIZED; 404 RESOURCE_NOT_FOUND; 500 INTERNAL_SERVER_ERROR. |
| Validation Rules | userId lấy từ SecurityContextUtil, không nhận query/userId của client; User phải tồn tại; log sort createdAt desc. |
| Related Use Cases | UC-04, UC-06, UC-11, UC-13, UC-14 |
| Frontend Usage | AuthService.getProfile từ restoreSession/refreshProfile, sau check-out/review; ProfileScreen render state. |
| Controller → Service | UserProfileController::profile → getProfile ở auth/service/impl/AuthServiceImpl.java. |
| Declared vs tested response | HTTP test nguồn assert data.email/trustScore và 200, chưa chạy. Auth service unit dùng profile mapping như một phần tạo session, không kiểm tra response HTTP. HTTP/E2E: NEEDS_VERIFICATION. |
| Source Code References | [src/main/java/fu/prm393/modules/auth/controller/UserProfileController.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/auth/controller/UserProfileController.java); [auth/service/impl/AuthServiceImpl.java :: getProfile](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/auth/service/impl/AuthServiceImpl.java); [src/main/java/fu/prm393/modules/auth/dto/response/UserProfileResponse.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/auth/dto/response/UserProfileResponse.java); security/envelope/exception mapping theo phần hợp đồng chung. |

## API-05 — PUT /api/v1/users/me/profile

| Field | Specification |
| --- | --- |
| API ID | API-05 |
| Module | auth |
| HTTP Method | PUT |
| Endpoint | `/api/v1/users/me/profile` |
| Description | Ghi đè tên/bio/avatar của tài khoản hiện tại. |
| Authentication Required | Có — Bearer JWT hợp lệ. |
| Authorization / Roles | authenticated, không role. Không có ownership bổ sung cho endpoint này ngoài userId hiện tại nếu service sử dụng. |
| Headers | Accept: application/json; Content-Type: application/json; Authorization: Bearer &lt;JWT&gt;. |
| Path Parameters | Không có. |
| Query Parameters | Không có. |
| Request Body | UpdateProfileRequest: {fullName:string, bio?:string hoặc null, avatarUrl?:string hoặc null}. |
| Response Body | HTTP 200: envelope chung, data = `UserProfileResponse` theo DTO dictionary; lỗi: data=null, code/message theo bảng status. |
| HTTP Status Codes | 200 SUCCESS; 400 VALIDATION_ERROR; 401 UNAUTHORIZED; 404 RESOURCE_NOT_FOUND; 500 INTERNAL_SERVER_ERROR. |
| Validation Rules | fullName @NotBlank/max150; bio max500; avatar không có constraint. BE set cả bio/avatar từ DTO, nên field bỏ qua/null có thể xóa giá trị. FullName trim trước lưu. |
| Related Use Cases | UC-07 |
| Frontend Usage | EditProfileScreen._saveProfile → AuthController.updateProfile → AuthService.updateProfile → ApiService.put. Có nhánh guard/expire return bình thường làm UI có thể báo thành công sai; avatar tương đối không được resolve. |
| Controller → Service | UserProfileController::update → updateProfile ở auth/service/impl/AuthServiceImpl.java. |
| Declared vs tested response | Không tìm thấy test trực tiếp update profile trong các test hiện có. HTTP/E2E: NEEDS_VERIFICATION. |
| Source Code References | [src/main/java/fu/prm393/modules/auth/controller/UserProfileController.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/auth/controller/UserProfileController.java); [auth/service/impl/AuthServiceImpl.java :: updateProfile](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/auth/service/impl/AuthServiceImpl.java); [src/main/java/fu/prm393/modules/auth/dto/request/UpdateProfileRequest.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/auth/dto/request/UpdateProfileRequest.java); [src/main/java/fu/prm393/modules/auth/dto/response/UserProfileResponse.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/auth/dto/response/UserProfileResponse.java); security/envelope/exception mapping theo phần hợp đồng chung. |

## API-06 — GET /api/v1/places

| Field | Specification |
| --- | --- |
| API ID | API-06 |
| Module | place |
| HTTP Method | GET |
| Endpoint | `/api/v1/places` |
| Description | Danh sách/tìm kiếm địa điểm không hidden. |
| Authentication Required | Không — SecurityConfig permitAll cho auth/places. |
| Authorization / Roles | Public, không role. Không có ownership bổ sung cho endpoint này ngoài userId hiện tại nếu service sử dụng. |
| Headers | Accept: application/json; Authorization không bắt buộc. |
| Path Parameters | Không có. |
| Query Parameters | keyword?:string; category?:string. Trim blank thành null; category uppercase; keyword so khớp ILIKE tên/địa chỉ; không page/limit. |
| Request Body | Không có. |
| Response Body | HTTP 200: envelope chung, data = `List<PlaceSummaryResponse>` theo DTO dictionary; lỗi: data=null, code/message theo bảng status. |
| HTTP Status Codes | 200 SUCCESS (kể cả []); 500 INTERNAL_SERVER_ERROR. |
| Validation Rules | Không có giới hạn độ dài query hay category enum validator; category không có kết quả trả [] thay vì lỗi. Native query sort name,id; SQL wildcard trong keyword không được escape riêng. |
| Related Use Cases | UC-08 |
| Frontend Usage | placesListProvider → PlaceService.searchPlaces xây Uri query → ApiService.getList; UI chip ALL/CAMPUS/HERITAGE/NATURE và debounce 500ms. |
| Controller → Service | PlaceController::search → search ở place/service/impl/PlaceServiceImpl.java. |
| Declared vs tested response | FE place_service_test kiểm query, ALL và model; fake override ApiService. BE PlaceServiceImplTests kiểm normalization bằng repository mock. Không test native SQL với PostgreSQL. HTTP/E2E: NEEDS_VERIFICATION. |
| Source Code References | [src/main/java/fu/prm393/modules/place/controller/PlaceController.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/place/controller/PlaceController.java); [place/service/impl/PlaceServiceImpl.java :: search](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/place/service/impl/PlaceServiceImpl.java); [src/main/java/fu/prm393/modules/place/dto/response/PlaceSummaryResponse.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/place/dto/response/PlaceSummaryResponse.java); security/envelope/exception mapping theo phần hợp đồng chung. |

## API-07 — GET /api/v1/places/{id}

| Field | Specification |
| --- | --- |
| API ID | API-07 |
| Module | place |
| HTTP Method | GET |
| Endpoint | `/api/v1/places/{id}` |
| Description | Chi tiết place và review có verified flag. |
| Authentication Required | Không — SecurityConfig permitAll cho auth/places. |
| Authorization / Roles | Public, không role. Không có ownership bổ sung cho endpoint này ngoài userId hiện tại nếu service sử dụng. |
| Headers | Accept: application/json; Authorization không bắt buộc. |
| Path Parameters | id: UUID bắt buộc. |
| Query Parameters | Không có. |
| Request Body | Không có. |
| Response Body | HTTP 200: envelope chung, data = `PlaceDetailResponse` theo DTO dictionary; lỗi: data=null, code/message theo bảng status. |
| HTTP Status Codes | 200 SUCCESS; 400 VALIDATION_ERROR/HIDDEN_PLACE; 404 RESOURCE_NOT_FOUND; 500 INTERNAL_SERVER_ERROR. |
| Validation Rules | UUID được Spring bind; place không tồn tại ->404; hidden ->400 HIDDEN_PLACE. reviews sort createdAt desc rồi filter isVerifiedReview; không filter lịch giờ mở cửa. |
| Related Use Cases | UC-09 |
| Frontend Usage | placeDetailProvider → PlaceService.getPlaceDetail encode id → ApiService.get; PlaceDetailModel.fromJson parse nested review. |
| Controller → Service | PlaceController::detail → getDetail ở place/service/impl/PlaceServiceImpl.java. |
| Declared vs tested response | BE PlaceServiceImplTests kiểm hidden/missing (unit). FE place_service_test/model_test kiểm đường dẫn/parsing dữ liệu giả; chưa HTTP/DB. HTTP/E2E: NEEDS_VERIFICATION. |
| Source Code References | [src/main/java/fu/prm393/modules/place/controller/PlaceController.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/place/controller/PlaceController.java); [place/service/impl/PlaceServiceImpl.java :: getDetail](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/place/service/impl/PlaceServiceImpl.java); [src/main/java/fu/prm393/modules/place/dto/response/PlaceDetailResponse.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/place/dto/response/PlaceDetailResponse.java); security/envelope/exception mapping theo phần hợp đồng chung. |

## API-08 — POST /api/v1/visits/check-in

| Field | Specification |
| --- | --- |
| API ID | API-08 |
| Module | visit |
| HTTP Method | POST |
| Endpoint | `/api/v1/visits/check-in` |
| Description | Mở visit sau kiểm tra vị trí và single OPEN. |
| Authentication Required | Có — Bearer JWT hợp lệ. |
| Authorization / Roles | authenticated, không role. Không có ownership bổ sung cho endpoint này ngoài userId hiện tại nếu service sử dụng. |
| Headers | Accept: application/json; Content-Type: application/json; Authorization: Bearer &lt;JWT&gt;. |
| Path Parameters | Không có. |
| Query Parameters | Không có. |
| Request Body | CheckInRequest: {placeId:UUID, userLat:number, userLng:number, gpsAccuracy?:number hoặc null, isMocked?:boolean hoặc null}. |
| Response Body | HTTP 200: envelope chung, data = `VisitResponse` theo DTO dictionary; lỗi: data=null, code/message theo bảng status. |
| HTTP Status Codes | 200 SUCCESS; 400 VALIDATION_ERROR/HIDDEN_PLACE/MOCK_LOCATION_DETECTED/GPS_OUT_OF_RADIUS; 401 UNAUTHORIZED; 404 RESOURCE_NOT_FOUND; 409 SINGLE_OPEN_VISIT; 500 INTERNAL_SERVER_ERROR. |
| Validation Rules | placeId/lat/lng @NotNull; lat [-90,90], lng [-180,180]; accuracy @PositiveOrZero nếu có. Service kiểm finite cho lat/lng/accuracy; lock User; hidden/mock/open; Haversine ≤ allowedRadiusM (fallback cấu hình 200m); bán kính phải finite và >0. isMocked null được coi không true. Không kiểm chứng tọa độ ngoài dữ liệu client. |
| Related Use Cases | UC-10 |
| Frontend Usage | VisitScreen._checkIn → LocationService.getCurrentPosition → VisitService.checkIn → ApiService.post; lưu _visit và invalidate visitHistoryProvider. |
| Controller → Service | VisitController::checkIn → checkIn ở visit/service/impl/VisitServiceImpl.java. |
| Declared vs tested response | BE VisitServiceImplTests kiểm hidden/mock/open/radius/NaN/success và chưa cộng điểm; mocked repositories. Chưa test GPS thiết bị/HTTP/database lock. HTTP/E2E: NEEDS_VERIFICATION. |
| Source Code References | [src/main/java/fu/prm393/modules/visit/controller/VisitController.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/visit/controller/VisitController.java); [visit/service/impl/VisitServiceImpl.java :: checkIn](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/visit/service/impl/VisitServiceImpl.java); [src/main/java/fu/prm393/modules/visit/dto/request/CheckInRequest.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/visit/dto/request/CheckInRequest.java); [src/main/java/fu/prm393/modules/visit/dto/response/VisitResponse.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/visit/dto/response/VisitResponse.java); security/envelope/exception mapping theo phần hợp đồng chung. |

## API-09 — PUT /api/v1/visits/{visitId}/check-out

| Field | Specification |
| --- | --- |
| API ID | API-09 |
| Module | visit |
| HTTP Method | PUT |
| Endpoint | `/api/v1/visits/{visitId}/check-out` |
| Description | Chuyển OPEN thành VERIFIED, cộng trust score/log. |
| Authentication Required | Có — Bearer JWT hợp lệ. |
| Authorization / Roles | authenticated, không role. Ownership trong service như validation bên dưới. |
| Headers | Accept: application/json; Authorization: Bearer &lt;JWT&gt;. |
| Path Parameters | visitId: UUID bắt buộc. |
| Query Parameters | Không có. |
| Request Body | Không có body được controller bind. CheckOutRequest record tồn tại nhưng không dùng. |
| Response Body | HTTP 200: envelope chung, data = `VisitResponse` theo DTO dictionary; lỗi: data=null, code/message theo bảng status. |
| HTTP Status Codes | 200 SUCCESS; 400 VALIDATION_ERROR/INVALID_CHECKOUT_TIME; 401 UNAUTHORIZED; 403 FORBIDDEN; 404 RESOURCE_NOT_FOUND; 409 ALREADY_CHECKED_OUT; 500 INTERNAL_SERVER_ERROR. |
| Validation Rules | User lock rồi visit lock; ownership; status OPEN; checkout server clock phải isAfter(checkInTime). Không nhận timestamp, coordinate hay isVerified từ client. Math.addExact điểm; cấu hình hiện +2; toàn bộ transaction. |
| Related Use Cases | UC-11 |
| Frontend Usage | VisitScreen._checkOut → VisitService.checkOut → ApiService.put không data; cập nhật visit, invalidate history, refresh profile. |
| Controller → Service | VisitController::checkOut → checkOut ở visit/service/impl/VisitServiceImpl.java. |
| Declared vs tested response | BE VisitServiceImplTests kiểm owner, chronology, trạng thái và cộng điểm/log đúng một lần theo lần gọi mô phỏng. Không chứng minh tranh chấp transaction DB thật. HTTP/E2E: NEEDS_VERIFICATION. |
| Source Code References | [src/main/java/fu/prm393/modules/visit/controller/VisitController.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/visit/controller/VisitController.java); [visit/service/impl/VisitServiceImpl.java :: checkOut](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/visit/service/impl/VisitServiceImpl.java); [src/main/java/fu/prm393/modules/visit/dto/response/VisitResponse.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/visit/dto/response/VisitResponse.java); security/envelope/exception mapping theo phần hợp đồng chung. |

## API-10 — GET /api/v1/visits/my-history

| Field | Specification |
| --- | --- |
| API ID | API-10 |
| Module | visit |
| HTTP Method | GET |
| Endpoint | `/api/v1/visits/my-history` |
| Description | Lấy toàn bộ lịch sử của user hiện tại. |
| Authentication Required | Có — Bearer JWT hợp lệ. |
| Authorization / Roles | authenticated, không role. Không có ownership bổ sung cho endpoint này ngoài userId hiện tại nếu service sử dụng. |
| Headers | Accept: application/json; Authorization: Bearer &lt;JWT&gt;. |
| Path Parameters | Không có. |
| Query Parameters | Không có. |
| Request Body | Không có. |
| Response Body | HTTP 200: envelope chung, data = `List<VisitResponse>` theo DTO dictionary; lỗi: data=null, code/message theo bảng status. |
| HTTP Status Codes | 200 SUCCESS (kể cả []); 401 UNAUTHORIZED; 500 INTERNAL_SERVER_ERROR. |
| Validation Rules | userId từ JWT; repository findByUserIdOrderByCheckInTimeDesc; không phân trang; không bắt buộc user lookup trước query. |
| Related Use Cases | UC-12, UC-13, UC-14 |
| Frontend Usage | visitHistoryProvider/VisitScreen._reloadVisit gọi VisitService.getMyHistory → ApiService.getList. CreateReviewScreen dùng chung provider lọc eligibility. |
| Controller → Service | VisitController::history → getMyHistory ở visit/service/impl/VisitServiceImpl.java. |
| Declared vs tested response | BE VisitServiceImplTests kiểm repository chỉ nhận authenticated userId. Chưa test HTTP contract hay Flutter visit UI. HTTP/E2E: NEEDS_VERIFICATION. |
| Source Code References | [src/main/java/fu/prm393/modules/visit/controller/VisitController.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/visit/controller/VisitController.java); [visit/service/impl/VisitServiceImpl.java :: getMyHistory](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/visit/service/impl/VisitServiceImpl.java); [src/main/java/fu/prm393/modules/visit/dto/response/VisitResponse.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/visit/dto/response/VisitResponse.java); security/envelope/exception mapping theo phần hợp đồng chung. |

## API-11 — POST /api/v1/reviews

| Field | Specification |
| --- | --- |
| API ID | API-11 |
| Module | review_locket |
| HTTP Method | POST |
| Endpoint | `/api/v1/reviews` |
| Description | Xuất bản verified review, aggregate/rating, điểm và signal nếu có ảnh. |
| Authentication Required | Có — Bearer JWT hợp lệ. |
| Authorization / Roles | authenticated, không role. Ownership trong service như validation bên dưới. |
| Headers | Accept: application/json; Content-Type: application/json; Authorization: Bearer &lt;JWT&gt;. |
| Path Parameters | Không có. |
| Query Parameters | Không có. |
| Request Body | CreateReviewRequest: {visitId:UUID, placeId:UUID, rating:integer, comment:string, postcardImageUrl?:string hoặc null, is360Media?:boolean hoặc null}. |
| Response Body | HTTP 200: envelope chung, data = `ReviewResponse` theo DTO dictionary; lỗi: data=null, code/message theo bảng status. |
| HTTP Status Codes | 200 SUCCESS; 400 VALIDATION_ERROR/UNVERIFIED_VISIT (INVALID_RATING có ở service trực tiếp, DTO thường chặn trước); 401 UNAUTHORIZED; 404 RESOURCE_NOT_FOUND; 409 DUPLICATE_REVIEW; 500 INTERNAL_SERVER_ERROR. |
| Validation Rules | DTO visitId/placeId/rating @NotNull; rating @Min(1)/@Max(5); comment @NotBlank. Service lặp kiểm rating và field bắt buộc, lock User, kiểm owner/place/status VERIFIED, duplicate user/place, lock Place, saveAndFlush review, tính avg/count verified và cộng điểm (hiện +5)/log. Ảnh trim blank thành null; cờ null thành false. Không URL validation; không giới hạn comment ở DTO. Có ảnh thì tạo signal cùng transaction, caption cắt 200. |
| Related Use Cases | UC-14, UC-15 |
| Frontend Usage | CreateReviewScreen._submitReview → ReviewService.createReview → ApiService.post; FE comment min5; invalidate detail/history, refreshProfile, không invalidate placesListProvider/locketFeedProvider. |
| Controller → Service | ReviewController::create → create ở review_locket/service/impl/ReviewServiceImpl.java. |
| Declared vs tested response | BE ReviewServiceImplTests kiểm rating/eligibility/duplicate và side effects qua mocks, gồm signal có/không ảnh. FE review_service_test kiểm payload/parsing bằng FakeReviewApiService; không HTTP thật. HTTP/E2E: NEEDS_VERIFICATION. |
| Source Code References | [src/main/java/fu/prm393/modules/review_locket/controller/ReviewController.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/review_locket/controller/ReviewController.java); [review_locket/service/impl/ReviewServiceImpl.java :: create](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/review_locket/service/impl/ReviewServiceImpl.java); [src/main/java/fu/prm393/modules/review_locket/dto/request/CreateReviewRequest.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/review_locket/dto/request/CreateReviewRequest.java); [src/main/java/fu/prm393/modules/review_locket/dto/response/ReviewResponse.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/review_locket/dto/response/ReviewResponse.java); security/envelope/exception mapping theo phần hợp đồng chung. |

## API-12 — POST /api/v1/media/upload

| Field | Specification |
| --- | --- |
| API ID | API-12 |
| Module | media |
| HTTP Method | POST |
| Endpoint | `/api/v1/media/upload` |
| Description | Lưu file ảnh xuống filesystem và trả metadata. |
| Authentication Required | Có — Bearer JWT hợp lệ. |
| Authorization / Roles | authenticated, không role. Không có ownership bổ sung cho endpoint này ngoài userId hiện tại nếu service sử dụng. |
| Headers | Accept: application/json; Content-Type: multipart/form-data; boundary=...; Authorization: Bearer &lt;JWT&gt;. |
| Path Parameters | Không có. |
| Query Parameters | Không có. |
| Request Body | multipart/form-data; part bắt buộc tên file kiểu MultipartFile (binary); không phải JSON filename/path. |
| Response Body | HTTP 200: envelope chung, data = `MediaUploadResponse` theo DTO dictionary; lỗi: data=null, code/message theo bảng status. |
| HTTP Status Codes | 200 SUCCESS; 401 UNAUTHORIZED; 400 VALIDATION_ERROR nếu service nhận file không hợp lệ; 500 INTERNAL_SERVER_ERROR cho IO/unexpected. Status thiếu multipart part, vượt giới hạn servlet hoặc sai Content-Type NEEDS_VERIFICATION; không gán mặc định 413/415 khi advice có catch-all. |
| Validation Rules | Service file nonnull/nonempty, tối đa 20*1024*1024 bytes; đọc bounded, signature JPEG/PNG/WebP; tên UUID + extension suy từ bytes; CREATE_NEW trong upload-dir. Đây là kiểm magic bytes, không giải mã ảnh đầy đủ. Servlet config max-file-size20MB/max-request-size25MB. |
| Related Use Cases | UC-16, UC-17 |
| Frontend Usage | LocketService.uploadImage → ApiService.upload tạo FormData. Dio 5.11.1 thực tế set multipart boundary trong bước transform FormData; base JSON header không đủ để kết luận upload hỏng. FE chỉ lấy data.url. |
| Controller → Service | MediaController::upload → upload ở media/service/impl/MediaStorageServiceImpl.java. |
| Declared vs tested response | BE MediaStorageServiceImplTests upload PNG fixture vào @TempDir và reject rỗng/nonimage; không kiểm servlet multipart/HTTP, size boundary hay file cleanup sau lỗi gửi signal. HTTP/E2E: NEEDS_VERIFICATION. |
| Source Code References | [src/main/java/fu/prm393/modules/media/controller/MediaController.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/media/controller/MediaController.java); [media/service/impl/MediaStorageServiceImpl.java :: upload](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/media/service/impl/MediaStorageServiceImpl.java); [src/main/java/fu/prm393/modules/media/dto/response/MediaUploadResponse.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/media/dto/response/MediaUploadResponse.java); security/envelope/exception mapping theo phần hợp đồng chung. |

## API-13 — POST /api/v1/locket/send-signal

| Field | Specification |
| --- | --- |
| API ID | API-13 |
| Module | review_locket |
| HTTP Method | POST |
| Endpoint | `/api/v1/locket/send-signal` |
| Description | Lưu signal với sender hiện tại và place tùy chọn. |
| Authentication Required | Có — Bearer JWT hợp lệ. |
| Authorization / Roles | authenticated, không role. Không có ownership bổ sung cho endpoint này ngoài userId hiện tại nếu service sử dụng. |
| Headers | Accept: application/json; Content-Type: application/json; Authorization: Bearer &lt;JWT&gt;. |
| Path Parameters | Không có. |
| Query Parameters | Không có. |
| Request Body | SendLocketSignalRequest: {placeId?:UUID hoặc null, imageUrl:string, caption?:string hoặc null, is360Image?:boolean hoặc null}. Không có receiverId. |
| Response Body | HTTP 200: envelope chung, data = `LocketSignalResponse` theo DTO dictionary; lỗi: data=null, code/message theo bảng status. |
| HTTP Status Codes | 200 SUCCESS; 400 VALIDATION_ERROR; 401 UNAUTHORIZED; 404 RESOURCE_NOT_FOUND; 500 INTERNAL_SERVER_ERROR. |
| Validation Rules | imageUrl @NotBlank; caption @Size(max200); service lặp image/caption checks, tìm sender và place nếu có, trim imageUrl, null flag -> false. Không kiểm ảnh thuộc upload của user, không validate URL, visit hay hidden place. |
| Related Use Cases | UC-17 |
| Frontend Usage | SendLocketScreen._send gọi sau upload. Lối vào từ feed không truyền placeId, từ Studio có truyền; công tắc "Đây là ảnh 360°" đặt is360Image (mặc định false). Invalidate feed sau thành công. |
| Controller → Service | LocketController::sendSignal → sendSignal ở review_locket/service/impl/LocketServiceImpl.java. |
| Declared vs tested response | Không tìm thấy Locket service/controller test trong repository. HTTP/E2E: NEEDS_VERIFICATION. |
| Source Code References | [src/main/java/fu/prm393/modules/review_locket/controller/LocketController.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/review_locket/controller/LocketController.java); [review_locket/service/impl/LocketServiceImpl.java :: sendSignal](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/review_locket/service/impl/LocketServiceImpl.java); [src/main/java/fu/prm393/modules/review_locket/dto/request/SendLocketSignalRequest.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/review_locket/dto/request/SendLocketSignalRequest.java); [src/main/java/fu/prm393/modules/review_locket/dto/response/LocketSignalResponse.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/review_locket/dto/response/LocketSignalResponse.java); security/envelope/exception mapping theo phần hợp đồng chung. |

## API-14 — GET /api/v1/locket/feed

| Field | Specification |
| --- | --- |
| API ID | API-14 |
| Module | review_locket |
| HTTP Method | GET |
| Endpoint | `/api/v1/locket/feed` |
| Description | Lấy 20 signal mới nhất, phạm vi toàn hệ thống. |
| Authentication Required | Có — Bearer JWT hợp lệ. |
| Authorization / Roles | authenticated, không role. Không có ownership bổ sung cho endpoint này ngoài userId hiện tại nếu service sử dụng. |
| Headers | Accept: application/json; Authorization: Bearer &lt;JWT&gt;. |
| Path Parameters | Không có. |
| Query Parameters | Không có; không page/cursor/receiver. |
| Request Body | Không có. |
| Response Body | HTTP 200: envelope chung, data = `List<LocketSignalResponse>` theo DTO dictionary; lỗi: data=null, code/message theo bảng status. |
| HTTP Status Codes | 200 SUCCESS (kể cả []); 401 UNAUTHORIZED; 500 INTERNAL_SERVER_ERROR. |
| Validation Rules | Security yêu cầu JWT; service không nhận userId và repository không filter receiver/sender; chỉ top20 sentAt desc. |
| Related Use Cases | UC-18 |
| Frontend Usage | locketFeedProvider → LocketService.getFeed → ApiService.getList → LocketSignal.fromJson → grid. Refresh/retry là pull, không stream/push. |
| Controller → Service | LocketController::feed → getFeed ở review_locket/service/impl/LocketServiceImpl.java. |
| Declared vs tested response | Không tìm thấy test Locket; chưa kiểm tra serialization/runtime feed. HTTP/E2E: NEEDS_VERIFICATION. |
| Source Code References | [src/main/java/fu/prm393/modules/review_locket/controller/LocketController.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/review_locket/controller/LocketController.java); [review_locket/service/impl/LocketServiceImpl.java :: getFeed](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/review_locket/service/impl/LocketServiceImpl.java); [src/main/java/fu/prm393/modules/review_locket/dto/response/LocketSignalResponse.java](../../../travel-trust-network-be/src/main/java/fu/prm393/modules/review_locket/dto/response/LocketSignalResponse.java); security/envelope/exception mapping theo phần hợp đồng chung. |

## Ngoài danh mục REST nghiệp vụ

- `/uploads/**`: static resource handler trỏ đến upload-dir, public theo SecurityConfig; URL trả bởi API-12 bắt đầu từ origin, không dưới /api/v1. [src/main/java/fu/prm393/common/config/WebStaticResourceConfig.java](../../../travel-trust-network-be/src/main/java/fu/prm393/common/config/WebStaticResourceConfig.java).
- `/v3/api-docs/**`, Swagger UI: tài liệu framework, không tính thêm endpoint nghiệp vụ.
- HTTPS Google tokeninfo: outbound synchronous verification trong GoogleTokenVerifierImpl, không phải controller/API riêng của ứng dụng.
- Không phát hiện Kafka, WebSocket, FCM producer/consumer hay REST callback OAuth trong mã thực thi đã quét.
- API có BE nhưng FE chưa gọi: 0 trong 14 endpoint. FE gọi method/path không có BE: 0 phát hiện. Các field/chức năng chưa được UI sử dụng được liệt kê riêng trong UI_API_MAPPING và ANALYSIS_GAPS.

