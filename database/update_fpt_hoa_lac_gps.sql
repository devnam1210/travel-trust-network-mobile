-- GPS supplied by the user in the phone screenshot on 2026-11-05.
-- Update only the FPT campus coordinates; preserve check-in radius and history.
BEGIN;

UPDATE places
SET latitude = 21.028400,
    longitude = 105.534450
WHERE id = '22222222-2222-2222-2222-222222222201';

COMMIT;
