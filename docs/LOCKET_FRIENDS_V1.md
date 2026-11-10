# Locket Friends V1 — Flutter

Backend implementation, exact APIs, migration, privacy/rollback policy and disposable PostgreSQL test runner are documented in the adjacent backend repository: `../travel-trust-network-be/doc/LOCKET_FRIENDS_V1.md`. For Docker, run `docker compose up -d --wait` from the backend root: startup now applies migrations to existing and new volumes automatically and preserves their data. PostgreSQL outside Docker still uses the one-time manual `doc/06_locket_friends_v1.sql`. The agent has only tested migration on disposable databases.

## Files

- `lib/features/friends/`: compact user model, API service and Friends screen (search, incoming/outgoing requests, accepted friends and username).
- `lib/features/locket/`: Locket screen with **Bảng tin / Bạn bè**, card/reactions, private byte image widget, send form and recipient selector; model/service stay separate.
- `lib/core/api_service.dart`: DELETE, authenticated binary downloads and shared session expiry for Friends/Locket.
- `lib/features/auth/user_model.dart`: optional username, exposed by the existing profile response.

UI/event state is local `setState`; account-scoped lists/images use existing Riverpod. No new dependencies or architecture layers.

## User flow

1. Open Locket → **Bạn bè**. The name search field is at the top of the page. Enter any part of the other account's full name; results load automatically after a short typing pause. Vietnamese names and spaces are accepted, without case sensitivity. Username search remains supported by the API.
2. Send a request from the search result. Clear the search to manage **Bạn bè / Lời mời nhận / Lời mời gửi**. The recipient accepts under **Lời mời nhận**; **Lời mời gửi** allows canceling. Accepted friends can be removed. A username is optional.
3. Open **Gửi ảnh**, choose camera/gallery, preview, enter an optional caption (200 characters).
4. Send to all accepted friends or turn off **Gửi tất cả bạn bè** and check recipients. Sending is disabled while the friend list is loading/failed, with no friends, without an image or without selected recipients.
5. Upload goes to `/media/private`; sending uses the returned `mediaId`. The feed refreshes on success. If a send times out, **Gửi** retries the same upload without sending another copy.
6. The recipient refreshes **Bảng tin**, views authenticated image bytes and opens **Reaction** to add/change/remove an emoji. Locket has only **Bảng tin / Bạn bè**; there are no sent/received photo-history tabs in the UI. The feed remains paginated. Unfriending preserves received images while blocking new sends.

Legacy signals are archived from the new feed. Their old public files/URLs are preserved, not converted to private automatically. Accounts without a username can be found directly by full name. Search excludes the current account, returns at most 30 matches and treats `%`/`_` literally. This search change needs a Spring Boot restart and Flutter hot restart; no database migration is needed.

## Verification

Verified on 2026-11-10:

- Baseline: **75/75** Flutter tests passed.
- Final: **122/122** Flutter tests passed (`flutter test --no-pub`), including friend profiles/photo dates, the two-tab Locket layout, full-name search/request, private photo replies/chat, polling, pagination and retries at 393px width.
- `flutter analyze --no-pub`: **No issues found**.
- Backend: **60/60** tests passed, zero skipped, on a fresh disposable PostgreSQL 18 cluster through `scripts/test-locket-friends.ps1`; the cluster stopped after the run. Includes authorized profile photo timelines, full-name search and private chat through Spring Security/MockMvc, PostgreSQL transactions and concurrent requests, and the existing auth/places/visits/review tests. The full Maven suite has not been run against PostgreSQL 16; the Docker migration scenarios below have passed on PostgreSQL 16.

Added tests exercise friend actions, username, errors and async disposal; recipient validation and retry; JWT binary requests and 401 session handling; private feed/reaction/history. Actual camera permissions and two-device network behavior still need a device/emulator smoke test after the backend database is migrated. Docker startup regression tests now pass on PostgreSQL 16 for existing/new volumes, restart, prior manual migration and partial-schema failure. No commit/push was made and the agent has not migrated the application/production database.

## Private photo replies and chat

Received photos now have **Trả lời**: open a private one-to-one chat with the sender, quote the photo and send text. The **Tin nhắn** icon in Locket opens saved conversations. The main tabs stay **Bảng tin / Bạn bè**. Only current friends can send new messages; old chat remains readable after unfriend. Photo quotes never grant new recipients access.

The bottom navigation also has a dedicated **Tin nhắn** destination between **Locket** and **Cá nhân**. It aggregates the signed-in user's conversations from all peers, newest first, with avatar, latest-message preview and time. **Nhắn tin mới** opens the current-friend selector. The inbox loads on first visit, keeps its state across tabs, stops foreground polling while hidden, and refreshes when reopened; incoming realtime events also refresh the shared inbox provider.

Chat/inbox sources are in `lib/features/messages/`. Foreground chat polls new messages every 4 seconds and the inbox every 5 seconds; history/inbox support pagination. Uncertain retries reuse the same message UUID and preserve the draft. Notification setup and Firebase requirements are documented in `NOTIFICATIONS.md`.

Unread incoming messages have red numeric badges on the bottom navigation and each inbox row (display capped at `99+`), with bold peer names. The backend persists a separate read cursor for each conversation participant; own messages are excluded, and the total includes conversations beyond the first inbox page. Realtime events refresh badges immediately; foreground polling every 5 seconds recovers missed updates and reads on another device. Viewing loaded messages at the latest end of the active chat acknowledges only the server cursor actually fetched. Background/covered chats and users browsing older history do not clear new arrivals. Failed acknowledgements preserve unread counts and retry on later syncs; logout clears the displayed total.

Run `docker compose up -d --wait` in the backend root to apply migrations through `doc/09_message_read_state.sql`, then restart Spring Boot and hot restart Flutter. These migrations preserve existing messages and read cursors. Detailed backend APIs, rules and tests are in `../travel-trust-network-be/doc/PRIVATE_MESSAGES.md`.

## Friend profile timeline

Tap a friend's name/avatar from the list/search, or the sender name/avatar on a Locket photo, to open their profile. It shows shared photos, captions and full date/time, newest first, with refresh and older-photo pagination. Only photos already sent to you are visible; being friends does not expose posts addressed only to other people. Old received photos remain visible after unfriend.

Implementation: `lib/features/friends/friend_profile_screen.dart`, existing FriendService/LocketService and LocketCard. The API returns only the compact identity from friend search and an authorized sender timeline, without private account fields. No database migration is needed. Restart Spring Boot and hot restart Flutter. Backend details: `../travel-trust-network-be/doc/FRIEND_PROFILES.md`.
