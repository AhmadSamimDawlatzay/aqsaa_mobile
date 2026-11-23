# Aqsaa Mobile

Implemented: public institution bootstrap, email/password login, secure session restoration, guardian linked-child list, placement details, attendance history and summary, and logout. Business records remain read-only; no refresh tokens, Firebase, or push registration are implemented.

## Guardian child access

The home screen exposes **My Children** when `capabilities.data.linked_children` contains `students`. Roles and `has_linked_students` do not gate the entry: a guardian with zero links must be able to see a genuine empty state.

- `GET me/students?page=N` returns `data` (explicit child fields) and `meta.current_page/last_page`. The app never fetches the general student directory.
- Tap a child to request `GET me/students/{id}?tab=student-attendances&page=N`. Read `data.student`, nullable `data.placement`, `data.summary`, and the direct Laravel paginator in `data.records`. Placement supplies class, section, program, level, year, and branch names. No exam-score UI is added.
- Attendance history is paginated. The date picker filters summary totals through `GET students/{id}/attendance-summary?from=YYYY-MM-DD&to=YYYY-MM-DD`; the child-history endpoint currently does not accept date bounds. The date picker caps dates at today, and the server also rejects future `to` dates. Missing attendance records are never treated as absences.
- Loading, pagination, pull-to-refresh, Refresh, Retry, and empty/error states are distinct. A failed or malformed request is not an empty list. Home Refresh revalidates profile and capabilities. A child-request 401 clears the invalid session; 403/404 only clear that child detail and explain the access issue.
- Child data stays in widget memory. Logout removes the view; generation checks discard late responses. The server authorizes every request using active `mobile_user_students` links, independently of contact records.

On 2026-11-21, the designated demo guardian's live login returned 201; profile, capabilities, linked list, child details, and attendance summary returned 200; logout returned 204. The list contained three children, including the expected `DEMO-ST-001` (the live account is linked to two more students than the local seeder expectation). Four attendance rows were returned for each checked child. No live links or records were changed. A linked child's placement and attendance were verified on the Android emulator after a full restart with the explicit demo API URL. Session restoration and logout returned to login with no child data displayed. Live authentication and child data were therefore verified; the automated emulator integration tests below use synthetic HTTP responses.

Regression coverage: `test/children_test.dart`; run the empty/error, pagination, detail, refresh, child-switch, and logout scenarios on Android with `flutter test integration_test/children_test.dart -d emulator-5554`. These emulator tests use synthetic HTTP responses and do not modify live accounts. Rebuild/run `lib/main.dart` with the explicit demo API URL afterwards to restore the normal app.

## Run

```powershell
cd C:\Projects\aqsaa_mobile
flutter pub get
flutter run -d emulator-5554 --dart-define=API_BASE_URL=https://demo.aqsaa.app/api/v1
```

`API_BASE_URL` **includes `/api/v1`**. The client appends paths such as `bootstrap` and `auth/login` exactly once. A trailing slash is accepted. HTTPS is required; certificate validation remains enabled. This demo URL is the default. Restart/rebuild after changing a dart-define.

## Verified Laravel contract

Source reviewed in `C:\Projects\madrasa`: `AGENTS.md`, `docs/mobile-api-v1.md`, `docs/mobile-api-coverage.md`, routes, `LoginRequest`, `AuthController`, `BootstrapController`, `DeviceController`, the mobile guard in `AppServiceProvider`, active-user middleware, locale request, mobile configuration, and existing API tests. No Laravel code was modified. `php85.bat` runs PHP 8.5.9 and successfully listed the auth routes; do not use the default PHP 8.2 CLI for this backend.

| Request | Actual contract |
| --- | --- |
| `GET bootstrap` | Public, 200: `api_version`, nullable `institution`, `supported_locales`; no `data` wrapper. |
| `POST auth/login` | JSON `email` (required email, max 255), `password` (required string, max 255), `device_name` (required string, max 120), `device_id` (required string, max 191). |
| Login success | 201: `token`, `token_type: Bearer`, ISO-8601 `expires_at`. Custom 80-character token, hashed server-side; not Sanctum. Configured expiry defaults to 30 days. Login revokes previous tokens for the same user/device ID. |
| Login failures | 422 with `message` for incorrect/unknown/inactive credentials; validation uses 422 `message` plus `errors`. Rate limiting is 429 (including route throttle); Retry-After is retained by the client. |
| `GET me` | Authenticated, 200 `data`: `id`, `name`, `email`, nullable `locale`, `roles`, `branches` (`id`, `name`, `code`), nullable `staff_id`, `teacher_id`. |
| `GET capabilities` | Authenticated, 200 `data`: `read_only`, `resources`, `resource_scopes`, `own_records`, `linked_children`, `assigned_teaching`, `technical_actions`. |
| `POST auth/logout` | Authenticated, 204. Deletes current user's device registration matching the bearer token's device ID, then deletes the current token. No body required. |
| Invalid authentication | 401 for missing, expired, revoked, or inactive-user authentication. 403 means access denied and is not treated as universal session invalidation. |

Capabilities retain `general` and `linked_children` resource scopes plus the separate own-record, linked-child, and assigned-teaching lists. Laravel's empty scope collection may serialize as `[]`; it is handled as an empty map. Unknown resource scope values grant no general access. Roles are display information, never permission checks. An account without supported scopes gets an explicit message and can still log out.

Bootstrap institution fields are `name`, nullable `short_name`/`logo`/`currency`, `timezone`, `default_locale`, and `default_calendar`. Currency contains `id`, `code`, `name`. The logo is a public-disk path resolved under `/storage/`, not under `/api/v1`. Missing/failed logos use a school icon. A custom backend `PUBLIC_STORAGE_URL` is not exposed in bootstrap and would require an agreed configuration change for CDN branding.

## Session lifecycle

1. Fetch public bootstrap. Once connected, read secure storage for this exact API base URL.
2. No token: show welcome and Log in. Login uses email and password; fields are not prefilled. The password is cleared from the field on submit and never logged or persisted. Submissions are disabled while pending.
3. Login succeeds: securely save the token, API base, and expiry as one record; request `me`, then `capabilities`. Only show home after both succeed. Profile and capabilities remain in memory, not on disk.
4. Restart with a saved token: validate using `me` and `capabilities`. Expiry metadata is retained, but the server decides validity (avoids relying on a device's clock). No token refresh exists.
5. Confirmed 401: clear local authentication and show login with a session-invalid notice. Timeout, network error, 403, 429, server error, redirect, or malformed response: retain the token and offer retry. Do not show unvalidated account data.
6. Logout: keep the token available for the POST. Only a 204 confirms remote logout. Clear local account data and return to login. A generation counter discards profile/capability results that arrive after logout or disposal.

A storage failure is visible and retryable, not silently interpreted as no session. If login succeeded but storage failed, home stays blocked; retry attempts persistence before validation. If remote logout succeeded but local deletion failed, retry completes local deletion without needing to revoke again.

## Secure storage and installation ID

Uses `flutter_secure_storage` 11.2.0, compatible with this Flutter/Dart SDK. See the [package documentation](https://pub.dev/packages/flutter_secure_storage) for platform storage details. Android uses the package's default encrypted storage backed by Android Keystore; `resetOnError: false` avoids silently deleting data on storage errors. Android backup is disabled and shared preferences are excluded from Android 12+ cloud/device transfer. iOS uses device-only unlocked Keychain accessibility with Runner entitlements; iOS compilation/signing is not verified on this Windows host.

A random 32-byte (64 hex characters) installation identifier is generated using `Random.secure()`, saved before the first login request, and reused across restarts and account switching. It is not a hardware ID. Logging out does not rotate it. OS secure storage lifecycle applies: Android app-data clearing/uninstall can remove it; iOS Keychain can survive reinstall. The identifier does not prove ownership or authorize transfer of another account's device registration.

Tokens are keyed by the normalized full HTTPS API base (including origin, port, and installation path) and also carry that scope inside the record. A token from another base is never selected or sent. Changing the configured server leaves the old server's record isolated; return to that configuration to log out there. All API requests disable redirects, and bearer tokens are attached only to explicit authenticated API methods. Logo/image requests receive no bearer headers.

## Logout limitations and account switching

If logout fails or times out, the UI says **server logout was not confirmed**, keeps the session for retry, and blocks another login. There is deliberately no local-only sign-out button in this milestone. A 401 during logout clears the now-invalid local session but does **not** prove server device cleanup; the UI explains this.

If a token has expired, is lost, or app data is cleared, an existing server device registration may remain. An authorized operator must verify and remove stale registrations when necessary. This app does not claim they were removed, invent a new device ID to bypass conflicts, or register/transfer push tokens. A timed-out login may have issued a server token; retrying with the same persisted device ID revokes the previous token for that same account.

For normal switching, log out successfully first, then enter the other account's credentials. The installation ID stays the same; user profile, capability data, and bearer token do not carry across accounts.

## Files explained

- `lib/main.dart`: existing welcome, theme, bootstrap handling, branding, and connection retries. Starts the auth flow after bootstrap succeeds.
- `lib/api/api_client.dart`: the single networking client; JSON requests, bearer scoping, redirect prevention, status/validation handling, and typed responses.
- `lib/models/bootstrap_response.dart`: existing bootstrap DTOs, unchanged.
- `lib/models/auth_models.dart`: typed token, safe profile/branch, and capability objects (similar to PHP DTOs).
- `lib/auth/session_store.dart`: a small secure-storage interface and platform adapter. Tests can replace the platform boundary with memory storage.
- `lib/auth/session_controller.dart`: coordinates restore, login, validation, logout, persistence, and stale-response protection.
- `lib/auth/auth_flow.dart`: login form and minimal account home; uses the same branding/card/layout.
- `lib/auth/children_view.dart`: capability-gated child list, details, paginated attendance, summary date filter, pull-to-refresh, and child-specific errors.
- `lib/models/child_models.dart`: typed linked-child, placement, attendance-summary, and attendance-history data.
- `lib/l10n/app_strings.dart`: all visible copy, ready for future Pashto (`ps`), Dari (`fa`), Arabic (`ar`), and English (`en`) translations. Current copy is English/LTR; RTL layouts are tested, not translated yet.
- `test/`: API/parser, storage, controller, child workflow, and widget tests. Synthetic credentials exist only in test fixtures and never reach the demo API.
- `integration_test/`: Android secure-storage and guardian workflow checks with mocked HTTP; these do not change live data.

## Automated verification

```powershell
dart format lib test integration_test
flutter analyze
flutter test
flutter build apk --debug --dart-define=API_BASE_URL=https://demo.aqsaa.app/api/v1
flutter test integration_test/session_storage_test.dart -d emulator-5554
flutter test integration_test/children_test.dart -d emulator-5554
```

Unit/widget coverage includes the login request/response, device requirement, credential/validation/rate/server failures, secure-storage adapter, bearer headers, server separation, restoration, invalid tokens, temporary failures, 403 preservation, logout success/failure, stale responses, capability scopes, linked-student parsing, empty/error states, child pagination, placement and attendance parsing, date filters, pull-to-refresh, revoked-child access, child switching, required fields, password visibility, duplicate-submit prevention, no-access home, logo fallback, and narrow RTL layout.

### Results on 2026-11-22

`dart format lib test integration_test` completed; `flutter analyze` reported no issues; all 42 unit/widget tests passed; all four guardian integration tests passed on `emulator-5554` using mocked HTTP; and the Android debug APK built successfully with the demo API URL. The normal app was then launched on the emulator and the public institution welcome screen showed **Connected**. The live authenticated guardian flow was verified separately as recorded above; the automated tests do not use the live account.

## Manual demo verification (designated account only)

The live designated-account flow has already been verified (login, restore, child list/details, attendance summary, and confirmed logout). To repeat it on the emulator, run the command above and sign in only with the authorized demo account using credentials supplied through the approved local channel; do not put them in source code or documentation.

1. The public institution name and Connected status appear; the current demo has no logo, so the school icon is expected.
2. Tap **Log in**. Blank fields show required errors without a request; use the eye control to check password visibility.
3. After login, open **My Children**. The live account currently shows three children. Tap a student to see placement, recorded attendance summary, and paginated attendance history.
4. Use **Filter summary by dates** to request date-bounded totals. History pages remain the complete API-provided history because that route does not accept date bounds.
5. Force-stop/reopen while signed in. The app verifies the saved session before showing the student list. A temporary network failure preserves the session and offers retry.
6. Tap **Log out**. After HTTP 204, the app returns to the login screen and no child data remains visible.

This milestone makes no backend changes and adds no attendance write actions or other business workflows.

### Earlier bootstrap/authentication milestone results (2026-11-17)

Formatting completed; flutter analyze reported no issues; all 35 unit/widget tests passed. The Android debug APK built successfully. The emulator integration test passed using real Android secure storage and mocked HTTP (synthetic session restore and logout). A read-only live bootstrap request returned HTTP 200 with application/json. No live authentication requests were made. iOS build/signing remains unverified on Windows.
The normal demo-configured app was then rebuilt, installed, and launched. Visual inspection confirmed the live institution welcome screen and empty branded email/password login form. The emulator is left on that login form; no credentials were entered.
