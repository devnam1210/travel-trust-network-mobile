# Đặc tả API và mapping giao diện

## 1. Quy ước

Base URL backend mặc định: `http://localhost:8080/api/v1`. Android Emulator dùng `http://10.0.2.2:8080/api/v1`; điện thoại thật dùng IP LAN của máy backend. Đổi bằng `--dart-define=API_BASE_URL=...`.

JSON request dùng `Content-Type: application/json`, trừ upload. API bảo vệ dùng `Authorization: Bearer <accessToken>`. Token này là JWT do TTN cấp, khác Google `idToken` chỉ dùng để đổi phiên tại `/auth/google`.

Thành công thông thường HTTP **200**, kể cả POST tạo mới:

```json
{"success":true,"code":"SUCCESS","message":"...","data":{},"timestamp":"2026-11-02T09:00:00"}
```

Lỗi: `success=false`, `code` mã lỗi, `message` giải thích, `data=null`, có `timestamp`. UUID là string, số tọa độ là number. `LocalDateTime` hiện không kèm timezone/offset; FE cần thống nhất cách diễn giải thời gian trước khi dùng ở nhiều múi giờ.

`data` có thể là object **hoặc array**. `ApiService` FE hiện chỉ nhận object nên phải bổ sung parser danh sách trước khi gọi places/history/feed; đồng thời bổ sung PUT và multipart vì hiện helper chỉ có GET/POST JSON.

## 2. Danh sách đầy đủ 14 route

Đường dẫn bên dưới nối sau `/api/v1`. “Dự kiến” là màn chưa được triển khai.

| Method | Route | Quyền | Đầu vào | `data` trả về | Mapping FE |
|---|---|---|---|---|---|
| POST | `/auth/register` | Public | email, fullName, password | AuthResponse | `AuthScreen` chế độ đăng ký |
| POST | `/auth/login` | Public | email, password | AuthResponse | `AuthScreen` chế độ đăng nhập |
| POST | `/auth/google` | Public | email, fullName, idToken; avatarUrl?, fcmToken? | AuthResponse | Chưa có Google Sign-In |
| GET | `/users/me/profile` | JWT | Không | UserProfileResponse | ProfileScreen; restoreSession |
| PUT | `/users/me/profile` | JWT | fullName, bio?, avatarUrl? | UserProfileResponse | Dự kiến sửa hồ sơ |
| GET | `/places` | Public | Query keyword?, category? | PlaceSummaryResponse[] | Dự kiến danh sách |
| GET | `/places/{id}` | Public | Path UUID | PlaceDetailResponse | Dự kiến chi tiết |
| POST | `/visits/check-in` | JWT | placeId, userLat, userLng; gpsAccuracy?, isMocked? | VisitResponse | Dự kiến GPS |
| PUT | `/visits/{visitId}/check-out` | JWT | Path UUID; **không có body** | VisitResponse | Dự kiến GPS |
| GET | `/visits/my-history` | JWT | Không | VisitResponse[] | Dự kiến lịch sử |
| POST | `/media/upload` | JWT | multipart field `file` | MediaUploadResponse | Dự kiến studio |
| POST | `/reviews` | JWT | visitId, placeId, rating, comment; postcardImageUrl?, is360Media? | ReviewResponse | Dự kiến đăng review |
| POST | `/locket/send-signal` | JWT | imageUrl; placeId?, caption?, is360Image? | LocketSignalResponse | Dự kiến chia sẻ ảnh |
| GET | `/locket/feed` | JWT | Không | LocketSignalResponse[] | Dự kiến feed/widget |

## 3. Chi tiết đầu vào và business rules

### Xác thực và profile

- Register: email hợp lệ, không trắng, ≤150 ký tự; fullName không trắng, ≤150; password 8–128 ký tự. Email trim/lowercase, tìm trùng không phân biệt hoa/thường; password hash bằng PBKDF2. Thành công trả JWT + hồ sơ, tạo điểm khởi tạo mặc định 50 và log. Email trùng → 409 `DUPLICATE_EMAIL`. Chưa xác minh email sở hữu.
- Login: email hợp lệ ≤150; password không trắng, ≤128. Sai mật khẩu, không tồn tại user hoặc user Google/seed chưa có password đều trả 401 `UNAUTHORIZED` cùng thông báo. Không tự gán mật khẩu cho tài khoản cũ.
- Google: `email`, `fullName`, `idToken` bắt buộc; hai trường tên/email ≤150. BE kiểm tra `aud`, `iss`, email verified, email khớp và `exp` qua Google tokeninfo. Thiếu `GOOGLE_CLIENT_ID` hoặc token sai → 401. Backend cấp JWT riêng. Luồng này cần mạng đến Google; FE chưa tích hợp lấy ID token.
- GET profile dùng userId từ JWT, không nhận userId tùy ý. PUT yêu cầu fullName không trắng ≤150, bio ≤500; avatarUrl chưa có validate URL chuyên biệt. Không cho sửa trustScore qua DTO.
- Logout là xóa JWT trên thiết bị, chưa có endpoint logout, refresh token hoặc danh sách thu hồi JWT.

Ví dụ đăng ký (dữ liệu minh họa, mật khẩu này không phải tài khoản seed):

```json
{"email":"demo-prm393@example.com","fullName":"Demo PRM393","password":"ExampleOnly123!"}
```

### Địa điểm

GET `/places?keyword=FPT&category=CAMPUS` tìm trên tên/địa chỉ bằng ILIKE, chuẩn hóa filter trong service, chỉ lấy `is_hidden=false`; sắp xếp tên rồi ID. Category là string, ví dụ CAMPUS/HERITAGE/NATURE, chưa có enum validation ở DTO. Danh sách hiện trả tất cả kết quả, không có page/size/total.

GET detail tìm UUID, chặn địa điểm ẩn (`HIDDEN_PLACE`), trả thông tin đầy đủ và review. Không có API CRUD địa điểm cho admin trong code hiện tại.

### GPS và visit

```json
{"placeId":"22222222-2222-2222-2222-222222222201","userLat":21.0124,"userLng":105.5253,"gpsAccuracy":8.5,"isMocked":false}
```

- Latitude [-90,90], longitude [-180,180]; không nhận NaN/Infinity. Accuracy tùy chọn, không âm; hiện chưa dùng accuracy làm ngưỡng chất lượng GPS.
- Khóa bản ghi user để tránh hai check-in đồng thời. Chặn địa điểm ẩn, mock flag true và user có visit OPEN.
- Tính Haversine từ tọa độ request đến place. Bán kính dùng `place.allowedRadiusM`; fallback cấu hình 200m khi null. **Không phải mọi địa điểm đều 200m**: seed FPT là 500m.
- Hợp lệ tạo visit OPEN bằng thời gian server, **chưa cộng điểm**. Lỗi bị ném trước khi lưu nên không tự tạo visit REJECTED.
- Check-out: user sở hữu visit, status OPEN, thời gian server phải sau check-in. Chuyển VERIFIED, +2 điểm mặc định, lưu log trong cùng transaction. Lock user trước visit. Không nhận thời gian hay `isVerified` từ client; chưa kiểm tra lại GPS/lưu trú tối thiểu ở check-out.
- Cờ mock là dữ liệu do client gửi, không chứng minh chống giả vị trí tuyệt đối. Không trình bày đây là xác thực có khả năng chống mọi giả mạo.

### Media

POST multipart `file`. File có dữ liệu, ≤20 × 1024 × 1024 byte; tổng request cấu hình 25MB. Kiểm tra chữ ký đầu JPEG/PNG/WebP, tạo filename UUID, lưu trong upload-dir. Không chỉ tin extension/tên file do client gửi; hiện chưa giải mã toàn ảnh để phát hiện mọi file hỏng.

`data.url` là đường dẫn **tương đối** `/uploads/<uuid>.<ext>`; ghép với origin backend `http://<host>:8080`, không ghép sau `/api/v1`. API này không tạo panorama hay ghép postcard.

### Review

```json
{"visitId":"<UUID visit đã VERIFIED>","placeId":"22222222-2222-2222-2222-222222222201","rating":5,"comment":"Trải nghiệm demo thực tế","postcardImageUrl":"/uploads/<filename>.png","is360Media":false}
```

Rating integer 1–5, comment không trắng, placeId/visitId bắt buộc. Visit phải thuộc user hiện tại, đúng place, đã VERIFIED. Mỗi user chỉ một review/place; visit_id cũng unique. Service khóa user, khóa place khi tính aggregate, lưu review và tính lại average/count, +5 điểm mặc định và log trong transaction. Có URL ảnh thì tự tạo Locket signal, caption cắt tối đa 200 ký tự. Không gọi thêm send-signal cho cùng ảnh trừ khi muốn tạo bài thứ hai.

### Locket

Send-signal yêu cầu imageUrl không trắng; caption ≤200, placeId tùy chọn. is360Image thiếu/null được coi false. Request chưa có receiverId. Feed là **20 signal mới nhất toàn hệ thống**, chưa phải feed theo quan hệ bạn bè, chưa có cursor/load-more, chưa có gửi push FCM hoặc cập nhật widget nền.

## 4. Response DTO

Các trường dưới đây theo record response hiện tại. Với record boolean đặt tên `is...`, nên đối chiếu JSON thực từ Swagger khi tích hợp thay vì suy từ getter entity.

| DTO | Trường |
|---|---|
| AuthResponse | accessToken: string; userProfile: UserProfileResponse |
| UserProfileResponse | id: UUID; email/fullName: string; avatarUrl/bio: nullable string; trustScore: int; verifiedVisitCount: long; trustScoreLogs: TrustScoreLogResponse[]; createdAt: datetime |
| TrustScoreLogResponse | id: UUID; previousScore/delta/newScore: int; reason/policyVersion: string; createdAt: datetime |
| PlaceSummaryResponse | id: UUID; name/category/address: string; imageUrl: nullable string; averageRating: double; verifiedReviewCount: int |
| PlaceDetailResponse | Toàn bộ summary + description/openingHours; latitude/longitude/allowedRadiusM: double; reviews: ReviewResponse[] |
| VisitResponse | id/userId/placeId: UUID; placeName/placeImageUrl; checkInTime/checkOutTime; userLat/userLng/gpsAccuracy/distanceMeters; isMocked: boolean; status: OPEN/VERIFIED/REJECTED; rejectionReason; isVerified: boolean (đặt tên tường minh bằng JsonProperty) |
| MediaUploadResponse | url/filename/contentType: string; size: long (byte) |
| ReviewResponse | id/userId/placeId/visitId: UUID; fullName/avatarUrl; rating: int; comment/postcardImageUrl; is360Media/isVerifiedReview: boolean; createdAt |
| LocketSignalResponse | id/senderId: UUID; senderName/senderAvatarUrl; receiverId/placeId: nullable UUID; placeName; imageUrl/caption; is360Image: boolean; sentAt |

## 5. Mã lỗi

| HTTP | Mã và trường hợp |
|---|---|
| 400 | `VALIDATION_ERROR` (DTO/JSON/path không hợp lệ); `HIDDEN_PLACE`; `GPS_OUT_OF_RADIUS`; `MOCK_LOCATION_DETECTED`; `INVALID_CHECKOUT_TIME`; `UNVERIFIED_VISIT`; `INVALID_RATING` tại service |
| 401 | `UNAUTHORIZED`: thiếu JWT ở API bảo vệ, token sai/hết hạn, login sai, Google chưa cấu hình/sai token |
| 403 | `FORBIDDEN`: không sở hữu visit hoặc truy cập bị từ chối |
| 404 | `RESOURCE_NOT_FOUND`: user/place/visit không có |
| 409 | `DUPLICATE_EMAIL`; `SINGLE_OPEN_VISIT`; `ALREADY_CHECKED_OUT`; `DUPLICATE_REVIEW` |
| 500 | `INTERNAL_SERVER_ERROR`: lỗi không dự kiến, log server để tìm nguyên nhân |

Rating ngoài 1–5 khi gọi HTTP thường bị `@Valid` chặn thành `VALIDATION_ERROR` trước service. Multipart vượt giới hạn có thể bị tầng servlet chặn trước controller; không cam kết mọi lỗi upload đều có cùng mã 400 vì handler chưa xử lý riêng tất cả ngoại lệ multipart.

## 6. Truyền dữ liệu và refresh dự kiến

`placeId`: danh sách → detail → GPS/studio/review. `visitId`: kết quả check-in → check-out → form review. `mediaUrl`: kết quả upload → form review. Sau check-out refresh profile/history; sau review refresh detail/profile/feed. Không tính điểm cục bộ thay server.

Hiện FE mới có `AuthService` parse AuthSession/UserModel; tất cả mapping nghiệp vụ trên là hợp đồng tích hợp cần triển khai tiếp. Swagger gốc: `http://localhost:8080/swagger-ui/index.html`, OpenAPI JSON: `http://localhost:8080/v3/api-docs`.
