# Địa điểm Đại học FPT Hà Nội (Hòa Lạc)

Ứng dụng lấy địa điểm từ PostgreSQL của backend `../travel-trust-network-be`
qua `/api/v1/places`. Không cần tạo thêm database SQLite cho địa điểm này.

Chạy [seed_fpt_hoa_lac.sql](seed_fpt_hoa_lac.sql) trong database của backend bằng
pgAdmin Query Tool hoặc `psql`. Với database mới, tạo bảng bằng
`../travel-trust-network-be/doc/03_create_schema.sql` và nạp seed backend trước,
sau đó chạy file này.

Ví dụ với PostgreSQL của Docker Compose (lệnh sẽ hỏi mật khẩu):

```powershell
& 'C:/Program Files/PostgreSQL/18/bin/psql.exe' -X -h localhost -p 5433 -U ttn_user -d ttn_db -v ON_ERROR_STOP=1 -f database/seed_fpt_hoa_lac.sql
```

Thay host, port, user và database nếu backend dùng cấu hình khác.

Script dùng lại UUID `22222222-2222-2222-2222-222222222201` của địa điểm FPT
đã có trong seed backend. Chạy lại chỉ cập nhật tên, danh mục, mô tả, địa chỉ
và ảnh; giữ nguyên đánh giá, lịch sử, tọa độ, bán kính và trạng thái ẩn hiện có.
Nếu chưa có địa điểm, script tạo bản ghi với điểm và số đánh giá bằng 0.
Tọa độ `21.0124, 105.5253` và bán kính 500 m lấy từ seed hiện có của dự án,
chưa đo kiểm tại hiện trường. Không gán giờ mở cửa chưa được xác minh cho bản ghi mới.

Ảnh thật và địa chỉ lấy từ [website chính thức của trường](https://daihoc.fpt.edu.vn/HN/).
Bản ảnh lưu tại [assets/images/fpt_hoa_lac.jpg](../assets/images/fpt_hoa_lac.jpg).
API sử dụng ảnh gốc qua HTTPS; việc tải ảnh trong app cần kết nối mạng tới website FPT.

Kiểm tra sau khi chạy:

```powershell
Invoke-RestMethod 'http://localhost:8080/api/v1/places?keyword=FPT&category=CAMPUS'
Invoke-RestMethod 'http://localhost:8080/api/v1/places/22222222-2222-2222-2222-222222222201'
```

Trong app, mở **Khám phá điểm đến**, kéo xuống để tải lại và tìm `FPT` hoặc
chọn danh mục **Khuôn viên (Campus)**. Không cần khởi động lại backend.
