# Aqsaa Mobile

Implemented: public institution bootstrap, email/password login, secure session restoration, a minimal authenticated home, and logout. No business modules, refresh tokens, Firebase, or push registration are implemented.

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
- `lib/l10n/app_strings.dart`: all visible copy, ready for future Pashto (`ps`), Dari (`fa`), Arabic (`ar`), and English (`en`) translations. Current copy is English/LTR; RTL layouts are tested, not translated yet.
- `test/`: parser, API, storage, controller, and widget tests. Synthetic credentials exist only in test fixtures and never reach the demo API.
- `integration_test/session_storage_test.dart`: real native secure-storage test on Android, with mocked HTTP and an isolated `.invalid` API scope.

## Automated verification

```powershell
dart format lib test integration_test
flutter analyze
flutter test
flutter build apk --debug --dart-define=API_BASE_URL=https://demo.aqsaa.app/api/v1
flutter test integration_test/session_storage_test.dart -d emulator-5554
```

Unit/widget coverage includes the login request/response, device requirement, credential/validation/rate/server failures, secure-storage adapter, bearer headers, server separation, restoration, invalid tokens, temporary failures, 403 preservation, logout success/failure, stale responses, capability scopes, required fields, password visibility, duplicate-submit prevention, no-access home, logo fallback, and narrow RTL layout.

## Manual demo verification (designated account only)

No demo/test credentials were supplied, so **live authenticated login, restoration, and logout have not been verified**. No credentials were discovered, guessed, or sent to the demo server.

1. Run the command above. Expect the public institution name and Connected, then tap **Log in**. The current demo has no logo, so the school icon is expected.
2. Tap Log in with blank fields: required errors appear without a request. Use the eye button to check password visibility.
3. Enter only your designated test account's email and password. Tap Log in once. Expect the institution, safe user name/email, roles, and either access-ready or no-supported-access text. There are no unfinished module buttons.
4. Force-stop/reopen the app without logging out. Expect session verification and then home without re-entering a password.
5. Disable emulator internet and restart. Expect a connection error and Retry, not automatic token deletion. Restore internet and retry; home should return after validation. If bootstrap itself cannot load, its existing connection-error screen appears first.
6. While on home, disable internet and tap Log out. Expect a clear unconfirmed-logout message and Retry. Restore internet and retry; expect an empty login form. Restart to confirm no previous user is restored.
7. Log in again, then have an authorized operator revoke/expire the designated test token. Restart online: expect login and the invalid-session/device-cleanup notice. Do not edit backend data merely to test this without authorization.
8. For account switching, complete confirmed logout before using a second explicitly designated test account. Check that only the new user's profile and capabilities appear.
9. If testing wrong credentials or rate limiting manually, use only the designated test account and coordinate limits with the operator; do not guess other accounts.

This milestone makes no backend changes. It adds no attendance or other business workflows.

### Results on 2026-11-17

Formatting completed; flutter analyze reported no issues; all 35 unit/widget tests passed. The Android debug APK built successfully. The emulator integration test passed using real Android secure storage and mocked HTTP (synthetic session restore and logout). A read-only live bootstrap request returned HTTP 200 with application/json. No live authentication requests were made. iOS build/signing remains unverified on Windows.
The normal demo-configured app was then rebuilt, installed, and launched. Visual inspection confirmed the live institution welcome screen and empty branded email/password login form. The emulator is left on that login form; no credentials were entered.
