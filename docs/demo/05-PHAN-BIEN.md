# Câu hỏi phản biện và bài luyện live-code

Các câu dưới đây bám câu hỏi trong ảnh và code thực tế. Phần minh họa là bài luyện, **chưa áp dụng vào code hiện tại**. Khi bảo vệ, mở file và giải thích bằng luồng dữ liệu; không học thuộc câu trả lời nếu chưa chạy thử.

## 1. UI, layout và cấu trúc

**Màn login được dựng ở đâu?** `lib/views/auth/login_screen.dart` bọc `AuthScreen` trong `views/auth/widgets/auth_screen.dart`. Các widget chính: Scaffold → SafeArea → Center → SingleChildScrollView → ConstrainedBox(maxWidth:440) → Column → Form/TextFormField/Buttons. Profile ở `views/profile_screen.dart` dùng ListView, card điểm, ListTile log.

**Đổi màu/icon?** Theme tổng ở `lib/main.dart`: ColorScheme.fromSeed, ThemeData, app bar và button themes. Icon logo/field/button ở AuthScreen/ProfileScreen. Có dùng Theme.of(context), nhưng vẫn có các giá trị màu/kích thước đặt trực tiếp trong main/UI; không khẳng định tất cả đã lấy từ theme.

**Tại sao ListView.builder?** Builder dựng item theo nhu cầu khi danh sách lớn, tránh tạo toàn bộ children ngay. Code profile hiện dùng ListView với `for` tạo ListTile cho mọi trust log, **chưa dùng builder**. Có thể đổi sang builder/slivers khi log tăng; builder không thay thế pagination backend.

**Văn bản dài gấp ba, xoay ngang?** AuthScreen có scroll và maxWidth, Row logo có Expanded; ErrorNotice cũng có Expanded. Profile cuộn và giới hạn chiều rộng 560. Điều đó giúp thích ứng nhưng chưa chứng minh mọi trường hợp font lớn/độ dài đều không tràn. Hiện không có breakpoint đổi sang bố cục hai cột. Khi đổi textScale/orientation cần chạy kiểm tra thực, dùng Wrap/Flexible/maxLines đúng ngữ cảnh.

**Tách widget đem lại gì?** Login/register dùng chung AuthScreen tránh lặp form; ErrorNotice tách riêng; API/parser/controller tách khỏi UI. AuthScreen vẫn dài, có thể tách phần header, trường form và action bar nếu mở rộng, giữ validate và controller rõ trách nhiệm.

**Đổi hành động nút ở đâu?** Form submit: AuthScreen._submit → AuthController.login/register → AuthService → ApiService. Logout/refresh: ProfileScreen → controller. Đổi cách chuyển login/register: AuthGate._switchMode. Không sửa URL/API trực tiếp trong onPressed của UI.

## 2. Nguồn dữ liệu, state và lifecycle

**Profile từ đâu?** AuthService.getProfile → ApiService GET `/users/me/profile`; UserModel parse JSON; AuthController cập nhật AuthState; AuthGate watch provider rồi truyền user mới vào ProfileScreen. Không có SQLite profile cache.

**Lỗi mạng/500 hiện ở đâu?** ApiService đổi DioException thành ApiException; controller tạo error. Form/Profile dùng ErrorNotice; restoreSession lỗi tạm thời chuyển restoreFailed trong AuthGate. Chỉ phản hồi 401/profile 404 được coi là phiên không hợp lệ trong controller hiện tại. Không suy rằng mọi 500 đều logout.

**State truyền qua trang thế nào?** Riverpod `authControllerProvider` lưu auth/user/busy/error. AuthGate chọn UI theo status; `_register` chỉ chọn form. Các trang du lịch chưa có nên chưa thể chỉ ra code truyền placeId/visitId/mediaUrl; đó là phần cần triển khai theo file API.

**initState/dispose làm gì?** AuthGate không override initState; controller dùng build + scheduleMicrotask để restore sau khởi tạo state. AuthScreen tạo 4 TextEditingController và dispose cả 4, rồi super.dispose. Provider ApiService đăng ký ref.onDispose(api.close). Không khẳng định mọi màn có initState hoặc notifyListeners.

**Timer/Stream/AnimationController ở đâu?** Trong lib hiện tại chưa có Timer/StreamSubscription/AnimationController do app tự tạo. Controller dùng microtask, không phải Timer cần cancel. Listener `ref.listen` trong widget do Riverpod quản lý lifecycle. Nếu thêm camera/GPS/sensor/FCM/debounce thì phải quản lý subscription/controller tương ứng và dọn khi dispose/ref.onDispose.

**Bỏ await thì sao?** Các lệnh phía sau không còn chờ Future hoàn tất; lỗi bất đồng bộ có thể không được catch đúng nơi. Ví dụ bỏ await `_storage.write` có thể đặt authenticated trước khi lưu token xong; bỏ await getProfile không có UserModel để cập nhật. `ref.mounted` sau await ngăn cập nhật provider đã bị dispose. Với context UI dùng `context.mounted` trước thao tác sau await. Nó không tự hủy request mạng.

## 3. Auth và bảo mật

**Token lưu và gắn request ở đâu?** SecureTokenStorage lưu key `ttn_access_token`. Sau login/register, AuthController đợi write thành công, gán `_api.accessToken`, đổi AuthState. Dio onRequest gắn `Authorization: Bearer ...` cho path không bắt đầu `/auth/`.

**401 tự về login thế nào?** ApiService chỉ chuyển lỗi thành ApiException; AuthController xử lý invalid session khi restore/refresh profile, xóa token và chuyển signedOut; AuthGate vẽ login. **Chưa có onError interceptor logout toàn cục cho mọi API nghiệp vụ.** Khi thêm nghiệp vụ cần cơ chế phiên chung, tránh mỗi feature xử lý khác nhau và tránh nhiều 401 gây logout chồng.

**Logout có vô hiệu JWT server không?** Chưa. App xóa local token; JWT đã copy ra ngoài vẫn có thể hợp lệ đến exp. Chưa có refresh token/revoke endpoint. Không nói đã bảo đảm logout mọi thiết bị.

**Gmail form có phải Google login?** Không. Form gửi email/password TTN. Google login cần lấy Google ID token và đổi tại `/auth/google`. Đăng ký email hiện chưa xác minh chủ sở hữu; đây là hạn chế phải nêu đúng khi hỏi.

## 4. Business rules và lỗi sâu

**Nghiệp vụ nào phức tạp hơn CRUD?** `VisitServiceImpl` kiểm tra location, mock flag, một OPEN/user, radius; checkout xác minh chủ sở hữu/thời gian, chuyển trạng thái và cộng điểm. `ReviewServiceImpl` chỉ nhận visit VERIFIED đúng user/place, chống trùng, cập nhật aggregate + điểm + signal trong transaction.

**Vì sao transaction/lock?** Tránh hai thao tác cùng đọc trạng thái cũ gây hai OPEN, cộng điểm mất cập nhật, review trùng hoặc average sai. Code lock user, checkout lock visit; review lock place để tuần tự hóa aggregate của cùng địa điểm. Unique review trong DB là lớp bảo vệ thêm. Test mock không đủ chứng minh hành vi lock thật, cần kiểm tra đồng thời trên PostgreSQL.

**GPS có thể bị giả không?** Server tính khoảng cách nhưng tin tọa độ và mock flag client gửi; hiện chưa có attestation hoặc bằng chứng hiện diện độc lập. Check-out không đo lại GPS và không bắt thời gian lưu trú tối thiểu. Nói “kiểm tra theo tọa độ và quy tắc hiện tại”, không cam kết chống gian lận tuyệt đối.

**Locket đã chạy nền chưa?** Chưa. `LocketServiceImpl` lưu DB và lấy 20 bài; có fcmToken trong model nhưng chưa có sender FCM, handler background hay native widget. Có dependency không đồng nghĩa đã tích hợp.

**360 đã chuyển đổi ảnh chưa?** Chưa. Boolean metadata/URL không biến ảnh thường thành panorama. Phải có capture/stitch/viewer hoặc định nghĩa rõ loại panorama đầu vào và giới hạn hỗ trợ.

**Nợ kỹ thuật và hướng refactor?** Ưu tiên API helper nhận list/PUT/multipart; auth failure chung; repository theo feature; phân trang log/places/feed; navigation nghiệp vụ; tách form dài khi cần. BE có thể tách TrustScoreService cho đoạn cộng điểm/log lặp, chuẩn hóa thời gian, migration có phiên bản, kiểm thử concurrency và kiểm soát upload sâu hơn. Refactor có mục tiêu và giữ contract, không đổi kiến trúc hàng loạt trước demo.

## 5. Live-code: xác nhận trước logout

Vị trí luyện: ProfileScreen, callback `OutlinedButton.icon`. Minh họa:

```dart
onPressed: state.isBusy
    ? null
    : () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Đăng xuất?'),
            content: const Text('Bạn có chắc chắn muốn đăng xuất?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Đồng ý'),
              ),
            ],
          ),
        );
        if (!context.mounted || confirmed != true) return;
        await controller.logout();
      },
```

Kiểm tra: Hủy/chạm ngoài dialog không logout; Đồng ý mới logout; bấm nhanh không tạo request trùng; storage lỗi vẫn hiện lỗi như cũ.

## 6. Live-code: debounce tìm kiếm 500ms

Hiện chưa có search screen nên đây là mẫu luyện cho màn tương lai; không khai rằng đã gọi API search liên tục trong code hiện tại. Ngoài delay phải ngăn response cũ ghi đè response mới:

```dart
Timer? _debounce;
int _requestVersion = 0;

void onKeywordChanged(String keyword) {
  _debounce?.cancel();
  final version = ++_requestVersion;
  _debounce = Timer(const Duration(milliseconds: 500), () async {
    try {
      final result = await repository.search(keyword.trim());
      if (!mounted || version != _requestVersion) return;
      setState(() { items = result; error = null; });
    } catch (exception) {
      if (!mounted || version != _requestVersion) return;
      setState(() => error = 'Không thể tải địa điểm. Vui lòng thử lại.');
    }
  });
}

@override
void dispose() {
  ++_requestVersion;
  _debounce?.cancel();
  super.dispose();
}
```

Cần `dart:async`, repository và state thật; mẫu chưa phải file chạy độc lập. Nếu request hỗ trợ Dio CancelToken có thể hủy request trước. Kiểm tra: gõ nhanh chỉ gọi sau khi dừng 500ms; request cũ về muộn không ghi đè; rời màn không setState sau dispose; xóa keyword tải lại đúng danh sách.

## 7. Break the code: luyện trên nhánh thử nghiệm

Không xóa dòng trực tiếp trên branch demo đã chốt. Tạo nhánh thử từ mốc, đổi một lỗi, giải thích và khôi phục bằng chỉnh sửa có kiểm soát.

| Thử thay đổi | Hậu quả cần giải thích | Cách sửa |
|---|---|---|
| Bỏ `_formKey.currentState!.validate()` | Form gửi dữ liệu sai; BE vẫn cần validate | Giữ validate cả UI/BE |
| Bỏ guard isBusy ở controller | Bấm nhanh có thể gửi auth đồng thời | Guard + disable nút |
| Bỏ cập nhật AuthState sau login | Có token nhưng UI không chuyển profile | Đổi state sau lưu token thành công |
| Bỏ `handler.next(options)` | Request interceptor không hoàn tất luồng | Gọi next/resolve/reject đúng một lần |
| Bỏ dispose TextEditingController | Resource/listener có thể bị giữ không cần thiết | Dispose đầy đủ |
| Bỏ kiểm tra OPEN khi checkout | Có thể cộng điểm lặp | Giữ guard + transaction/lock |
| Bỏ kiểm tra visit thuộc user khi review | Dùng visit người khác để đăng review | Kiểm tra owner/place/status phía server |

Riverpod Notifier hiện **không dùng notifyListeners**; không áp dụng ví dụ ChangeNotifier máy móc. Không phải mọi lệnh return đều bỏ được: return kết thúc luồng lỗi/guard để tránh code sau tiếp tục chạy.

## 8. Nếu API chuyển sang pagination

Hiện places/history trả list toàn bộ, feed giới hạn 20 không load-more. Contract mới nên có `items`, `nextCursor`/`hasMore` (hoặc page/size/total). Giữ thứ tự ổn định, ví dụ createdAt + id, để tránh trùng/mất bài khi có dữ liệu mới.

State cần keyword/category, items, nextCursor, hasMore, initialLoading, loadingMore, error và generation của filter. Đổi filter → reset cursor/list và vô hiệu request cũ; load-more → append/dedupe theo ID; lỗi tải thêm giữ dữ liệu đã có và có nút retry. UI dùng ListView.builder + sentinel/scroll threshold, tránh bắn nhiều request khi đang loadingMore. Refresh từ đầu; dispose scroll controller/subscriptions. Backend cần Pageable/cursor query và index phù hợp, không chỉ đổi widget.
