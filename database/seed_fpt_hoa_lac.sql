-- PostgreSQL: run after the backend's doc/03_create_schema.sql.
-- Reuse the existing FPT seed UUID to preserve visits and reviews.
-- Campus information and photo: https://daihoc.fpt.edu.vn/HN/
-- GPS coordinates and 500 m radius retain the project's existing seed values.
BEGIN;
SET LOCAL client_encoding = 'UTF8';

INSERT INTO places (
    id, name, category, description, address, image_url, opening_hours,
    latitude, longitude, allowed_radius_m,
    average_rating, verified_review_count, is_hidden
)
VALUES (
    '22222222-2222-2222-2222-222222222201',
    'Trường Đại học FPT Hà Nội (Hòa Lạc)',
    'CAMPUS',
    'Cơ sở Hà Nội của Trường Đại học FPT tại Khu Công nghệ cao Hòa Lạc. Khuôn viên xanh với giảng đường, thư viện, ký túc xá và khu thể thao; phù hợp khám phá không gian học tập và lưu lại khoảnh khắc tại trường.',
    'Khu Giáo dục và Đào tạo, Khu Công nghệ cao Hòa Lạc, Km29 Đại lộ Thăng Long, xã Hòa Lạc, TP. Hà Nội',
    'https://daihoc.fpt.edu.vn/wp-content/uploads/2025/12/Gioi-thieu-Truong-Dai-hoc-FPT-Campus-Ha-Noi.jpg',
    'Liên hệ nhà trường trước khi tham quan',
    21.0124, 105.5253, 500.0,
    0.0, 0, FALSE
)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    category = EXCLUDED.category,
    description = EXCLUDED.description,
    address = EXCLUDED.address,
    image_url = EXCLUDED.image_url;

COMMIT;
