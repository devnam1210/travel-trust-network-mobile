-- Coordinates supplied by the user: 21,02840° N, 105,53445° E.
-- Update only this place; preserve its check-in radius and other business data.
UPDATE places
SET latitude = 21.02840,
    longitude = 105.53445,
    address = CASE
        WHEN address = 'Tọa độ Google Maps: 21.0283938, 105.5344276'
        THEN 'Tọa độ: 21.02840, 105.53445'
        ELSE address
    END
WHERE id = '22222222-2222-2222-2222-222222222207'
RETURNING id, latitude, longitude, allowed_radius_m;
