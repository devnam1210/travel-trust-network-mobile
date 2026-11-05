-- Trọ T&H Hostel: coordinates updated from the user's supplied location.
-- Source: https://maps.app.goo.gl/rTxHuGreHjz3x1iD6
-- Street address, photo and opening hours have not been verified.
-- Uses the backend's default 200 m check-in radius.
INSERT INTO places (
    id, name, category, description, address, image_url, opening_hours,
    latitude, longitude, allowed_radius_m,
    average_rating, verified_review_count, is_hidden
)
VALUES (
    '22222222-2222-2222-2222-222222222207',
    'Trọ T&H Hostel',
    'HOSTEL',
    'Trọ T&H Hostel. Vị trí theo ghim địa điểm trên Google Maps.',
    'Tọa độ: 21.02840, 105.53445',
    NULL,
    NULL,
    21.02840, 105.53445, 200.0,
    0.0, 0, FALSE
)
ON CONFLICT (id) DO NOTHING;
