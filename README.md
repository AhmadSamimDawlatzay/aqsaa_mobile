# Aqsaa Mobile

Implemented: public institution bootstrap, email/password login, secure session restoration, guardian linked-child list, placement details, attendance history and summary, notification inbox, Android Firebase Messaging registration, and logout. Business records remain read-only; no refresh tokens or Firebase authentication are implemented.

## Languages

The current interface is available in پښتو, دری, العربية, and English. A first launch defaults to Pashto. The language selector is available before login and in Account; its value is stored independently from authentication, so it survives logout and app restarts.

| Display language | Flutter locale | Backend locale |
| --- | --- | --- |
| پښتو | `ps` | `ps` |
| دری | `fa` | `fa` |
| العربية | `ar` | `ar` |
| English | `en` | `en` |

The compatibility mapper also recognizes an incoming `dr` value as Dari, but the current Laravel API contract uses `fa`. Pashto, Dari, and Arabic use RTL; English uses LTR. Dates remain Gregorian and are formatted by Flutter's locale-aware Material localizations. API dates remain unchanged ISO/Gregorian values. Names, student numbers, email addresses, and institution-entered content are not translated.

The selected language currently remains an app preference. It is not sent to the API because the existing mobile workflow has no documented endpoint for updating a user's locale; no speculative header, query parameter, or profile mutation is added.

Interface translations are centralized in `lib/l10n/app_strings.dart`; locale codes and direction are centralized in `lib/l10n/app_language.dart`. To add a language, add one `AppLanguage` entry, supply every interface string, add it to the backend mapping only if the API supports it, and extend `test/localization_test.dart`. Flutter does not ship Pashto Cupertino strings, so the app includes a focused Pashto Cupertino delegate for built-in labels while using Flutter's official Pashto Material/date localization.

## Guardian child access

The home screen exposes **My Children** when `capabilities.data.linked_children` contains `students`. Roles and `has_linked_students` do not gate the entry: a guardian with zero links must be able to see a genuine empty state.

- `GET me/students?page=N` returns `data` (explicit child fields) and `meta.current_page/last_page`. Each item may include nullable `current_placement` with class, section, branch, and academic year. The app also accepts older responses that omit this field. The app never fetches the general student directory.
- Tap a child to request `GET me/students/{id}?tab=student-attendances&page=N`. Read `data.student`, nullable `data.placement`, `data.summary`, and the direct Laravel paginator in `data.records`. Placement supplies class, section, program, level, year, and branch names. No exam-score UI is added.
- Attendance history is paginated. The date picker filters summary totals through `GET students/{id}/attendance-summary?from=YYYY-MM-DD&to=YYYY-MM-DD`; the child-history endpoint currently does not accept date bounds. The date picker caps dates at today, and the server also rejects future `to` dates. Missing attendance records are never treated as absences.
- Loading, pagination, pull-to-refresh, Refresh, Retry, and empty/error states are distinct. A failed or malformed request is not an empty list. Home Refresh revalidates profile and capabilities. A child-request 401 clears the invalid session; 403/404 only clear that child detail and explain the access issue.
- Child data stays in widget memory. Logout removes the view; generation checks discard late responses. The server authorizes every request using active `mobile_user_students` links, independently of contact records.

The API selects placement from an active enrollment whose academic year is marked current, using latest enrollment date and id as tie-breakers, matching child details. Historical enrollments do not appear as current placement. Until the backend deployment is updated, the app safely omits these optional card details.

On 2026-11-21, the designated demo guardian's live login returned 201; profile, capabilities, linked list, child details, and attendance summary returned 200; logout returned 204. The list contained three children, including the expected `DEMO-ST-001` (the live account is linked to two more students than the local seeder expectation). Four attendance rows were returned for each checked child. No live links or records were changed. A linked child's placement and attendance were verified on the Android emulator after a full restart with the explicit demo API URL. Session restoration and logout returned to login with no child data displayed. Live authentication and child data were therefore verified; the automated emulator integration tests below use synthetic HTTP responses.

Regression coverage: `test/children_test.dart`; run the empty/error, pagination, detail, refresh, child-switch, and logout scenarios on Android with `flutter test integration_test/children_test.dart -d emulator-5554`. These emulator tests use synthetic HTTP responses and do not modify live accounts. Rebuild/run `lib/main.dart` with the explicit demo API URL afterwards to restore the normal app.

## Run

```powershell
cd C:\Projects\aqsaa_mobile
flutter pub get
flutter run -d emulator-5554 --flavor demo
```

The `demo` Android flavor is one fixed installation identity:

| Setting | Demo value |
| --- | --- |
| Android application ID | `app.aqsaa.demo` |
| Installed name | `Aqsaa Demo` |
| API base URL | `https://demo.aqsaa.app/api/v1` |
| Firebase project/configuration | `aqsaademo` / `android/app/src/demo/google-services.json` |

The API base **includes `/api/v1`**. `lib/config/installation_config.dart` derives this identity from Flutter's native `appFlavor`; release builds require a known flavor. The previous unrestricted `API_BASE_URL` define is no longer used. For local development only, a debug build may use a loopback endpoint ending in `/api/v1`:

```powershell
flutter run -d emulator-5554 --flavor demo --dart-define=DEBUG_API_BASE_URL=http://10.0.2.2:8000/api/v1
```

This override rejects non-local hosts and is rejected in release mode, preventing a demo release from being paired with another installation's API. Institution name/logo still come from the selected server's bootstrap response; optional bundled branding belongs to the same installation configuration.

The project previously installed as `app.aqsaa.aqsaa_mobile`. The demo flavor installs separately as `app.aqsaa.demo`; Android does not transfer the old app's secure session or device identifier. The old app is not uninstalled or cleared automatically.

## Notification inbox

Guardian-capable accounts (advertised by `linked_children` containing `students`) receive a Notifications destination beside My Children and Account. The inbox uses the authenticated Laravel contract:

| Request | Purpose |
| --- | --- |
| `GET notifications?page=N&per_page=25` | Newest-first Laravel `data`/`links`/`meta` page; `per_page` is bounded by the server to 1–100. |
| `GET notifications/unread-count` | Authoritative unread total, independent of loaded pages. |
| `PATCH notifications/{id}/read` | Revalidates visibility and marks one notification read. |
| `PATCH notifications/read-all` | Marks every currently visible notification read and returns 204. |

List items accept the allowlisted fields `id`, `event_type`, nullable `student`, `translation_key`, `translation_params`, nullable `deep_link`, nullable `title`/`body`, nullable `read_at`, and `created_at`. Known guardian events are `attendance_absent`, `attendance_corrected`, `released_result`, `promotion_committed`, and `transfer_approved`. Unknown types remain readable with a generic icon and server text.

Only a `v1` `guardian.student` descriptor whose student ID matches the returned student summary is actionable. Absence/correction opens the existing attendance screen after an authorized child re-fetch. Promotion and transfer open child details, which also re-fetches access. Released results remain detail-only because the Flutter app has no authorized results screen yet. Arbitrary URLs are never opened, and a descriptor is never treated as authorization.

The inbox refreshes after session validation, when opened, through pull-to-refresh, and on app resume with a 30-second throttle. It does not poll. Page merges deduplicate by notification ID; a first-page refresh replaces the visible collection so revoked-link notices disappear. Read state changes only after server success, and the unread count is fetched again after read actions. Items, counts, and detail state are memory-only and are discarded with the authenticated layout on logout or account/server change.

Known structured translation keys are rendered in the selected Pashto (`ps`), Dari (`fa`), Arabic (`ar`), or English (`en`) UI language. Unknown keys fall back to safe stored title/body text, never to a raw key. Laravel currently stores title/body in the user's locale when the event is created and exposes no per-request notification locale negotiation. The API controller also omits the stored `format: guardian.v1` field, so Flutter version-gates actions using the returned deep-link `version` and treats unsupported descriptors as display-only.

Manual verification:

1. Sign in with an authorized guardian test account and open Notifications.
2. Confirm the badge is absent for zero, shows the server total for unread items, and caps visually at `99+`.
3. Pull to refresh, open an unread item, return, and confirm its styling and server count update.
4. Test Attendance or Child details only when the descriptor offers it; confirm 403/404 leaves the session signed in and explains unavailable access.
5. Use Account to switch all four languages and confirm the inbox/detail remain open, with RTL for Pashto, Dari, and Arabic.
6. Log out and sign in as another account; confirm no previous items or count remain.

Automatic Laravel-to-FCM delivery and an authorized results screen remain separate milestones. The mobile app now registers Android messaging tokens, but it does not generate business events.

## Android Firebase Messaging

The demo flavor initializes the native Firebase project `aqsaademo` through `android/app/src/demo/google-services.json`. Gradle fails if that file is absent or does not contain `app.aqsaa.demo` and `aqsaademo`; Dart verifies the initialized project ID against the installation configuration. Firebase Authentication is not used.

After Laravel session validation, the app explains the benefit and optionally requests Android notification permission. Denial does not block login, children, attendance, or the inbox. If allowed, it obtains the FCM token and calls authenticated `PUT /devices/{deviceId}` with `platform: android` and `push_token`. Token rotations re-register through the same session/device boundary. Recoverable failures use bounded 1/2/4-second retries; HTTP 409 is not retried or transferred. The user must first log out the prior account on that installation, or an authorized operator must verify/remove a stale registration.

Foreground messages show one generic in-app banner and refresh the inbox plus authoritative unread count. Background notification messages use Android channel `aqsaa_updates`; Android displays them without a second local alert. Background code initializes Firebase only and never navigates or accesses UI/session state. Taps and cold-start messages wait for the authenticated layout, then open and refresh the inbox. Push data does not grant access and does not mark anything read.

The current API has no safe `GET /notifications/{id}` lookup. It only has list, unread count, and read mutations. Consequently, notification IDs from push cannot directly resolve older notices outside the loaded page; taps open the authoritative inbox. The smallest backend addition for precise navigation is a current-user/guardian-visibility-filtered `GET /notifications/{id}` returning the existing notification Resource and 404 after link revocation.

### Push payload contract for Laravel

Use a generic visible notification and minimal data; do not include student names, marks, attendance details, or arbitrary URLs:

```json
{
  "notification": {
    "title": "Aqsaa",
    "body": "You have a new notification in Aqsaa."
  },
  "data": {
    "version": "aqsaa.push.v1",
    "notification_id": "<database-notification-id>",
    "installation": "demo"
  },
  "android": {
    "notification": {
      "channel_id": "aqsaa_updates"
    }
  }
}
```

Send only to the FCM token held by the intended `mobile_devices` row. `notification_id` identifies the existing database notification; `installation: demo` is the stable installation/flavor boundary. Unknown versions, malformed data, and another installation value never navigate to protected content. A Firebase Console test notification normally has no application notification ID and therefore safely opens the inbox.

### Manual FCM test

1. Run `flutter run --flavor demo` on an Android device/emulator with Google Play services, sign in with the designated test account, and enable notifications.
2. In this debug build only, open Account → Push notifications → **Copy test token (debug only)**. The token is copied to the clipboard and is never logged. Keep it private.
3. In Firebase Console, open project `aqsaademo` → Messaging, compose one test notification with the generic title/body above, choose **Send test message**, and paste the token.
4. Foreground: keep Aqsaa visible. Expect one localized in-app banner and an inbox/unread refresh.
5. Background: place Aqsaa in the background and send another test. Expect one Android notification on `aqsaa_updates`; tapping it opens and refreshes the inbox after session validation.
6. Cold start: terminate the app normally (do not Android-force-stop it), send another test, and tap it. Expect startup/session validation followed by the inbox. A force-stopped Android app must be opened manually before FCM resumes.

Console test messages prove Firebase transport only. Laravel-to-FCM sending is not implemented yet, and a console message without `notification_id` cannot prove database notification delivery.

### Notification verification status

Authenticated live verification on 2026-11-26 used the designated demo guardian without recording its password or token. Login returned 201, GET notifications returned 200 with a valid empty Laravel page (current page 1, last page 1), unread count returned 200 with zero, and logout returned 204. The live inbox contained no item, so opening an item, marking it read, count reduction, and related-child navigation could not be verified live without creating business data.

Populated-state verification is fixture-based, not live delivery proof. Automated tests cover all five documented guardian event types, unknown descriptors, read success/failure, authoritative unread totals, two-page deduplication, revocation after later pages were loaded, stale refresh races, logout/account isolation, and already-open detail revalidation. Emulator fixtures render inbox and detail screens in Pashto, Dari, Arabic, and English.

To create a real absence notification manually in the demo environment:

1. Sign in to the demo admin panel with an authorized demo teacher or super-admin account.
2. Open **Attendance → Attendance Sessions** and create a new manual session for an unused date.
3. Select the current demo branch, academic year, program, level, class, and section containing DEMO-ST-001 (Amina Safi), the child linked to the demo guardian.
4. Save the session, choose **Take Attendance**, and set that student to **Absent**. Set the other students accurately.
5. Choose **Complete Attendance**. Merely saving a draft does not create a notification.
6. Sign in to the mobile app as guardian@aqsaa.app, open Notifications, and pull to refresh. Opening the new notice should mark it read and allow navigation to the authorized attendance screen.

These steps change demo attendance records and therefore must be performed intentionally by an authorized operator; the Flutter verification process does not run them automatically.

The configured API base includes `/api/v1`; the client appends paths such as `bootstrap` and `auth/login` exactly once. HTTPS and normal certificate validation remain enabled for installation endpoints.

## Verified Laravel contract

Source reviewed in `C:\Projects\madrasa`: `AGENTS.md`, `docs/mobile-api-v1.md`, `docs/mobile-api-coverage.md`, routes, `LoginRequest`, `AuthController`, `BootstrapController`, `DeviceController`, guardian workflow services, models, and API tests. `php85.bat` selects the compatible PHP 8.5 runtime; do not use the default PHP 8.2 CLI for this backend.

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

Android additionally gives each application ID its own app-data and Keystore-backed storage sandbox. Therefore sessions and installation IDs do not cross between `app.aqsaa.demo` and a future customer package.

## Android installations, Firebase boundary, and signing

One Flutter codebase supplies all screens, API clients, session logic, localization, and capability handling. A native Android product flavor selects the installation identity. To add a real customer later:

1. Add one product flavor in `android/app/build.gradle.kts` with a unique, permanent application ID and `app_name`.
2. Add the matching allowlisted entry in `lib/config/installation_config.dart`: flavor, API base, display name, optional bundled branding, and future Firebase metadata. Do not make these independently selectable.
3. Create that customer's separate Firebase project and register the flavor's exact Android application ID. Put its downloaded file at `android/app/src/<flavor>/google-services.json` (these local files are ignored by Git).
4. Configure that flavor's Google Services Gradle input and extend the installation project-ID check. This Android implementation uses the native flavor file as its single initialization source; do not add a competing generic Dart options file.
5. Add customer branding only through that installation entry while continuing to prefer backend-provided institution branding.
6. Configure that customer's release key through an uncommitted `android/key.properties`. Keep keystores and passwords outside source control and never put Laravel service-account credentials, private keys, or signing secrets in Flutter assets or Dart defines.

The demo uses `firebase_core` and `firebase_messaging` only. For the demo Firebase project, the exact Android package is **`app.aqsaa.demo`**, and its native configuration belongs at **`android/app/src/demo/google-services.json`**. No Laravel service account or signing secret belongs in this repository.

The current verified APK is debug-signed and is not production-ready. A release task fails clearly when `android/key.properties` is absent. Android updates must retain both the installed application's application ID and a compatible signing identity; changing either creates a different app or prevents an update.

## Logout limitations and account switching

If logout fails or times out, the UI says **server logout was not confirmed**, keeps the session for retry, and blocks another login. There is deliberately no local-only sign-out button in this milestone. A 401 during logout clears the now-invalid local session but does **not** prove server device cleanup; the UI explains this.

If a token has expired, is lost, or app data is cleared, an existing server device registration may remain. An authorized operator must verify and remove stale registrations when necessary. This app does not claim they were removed, invent a new device ID to bypass conflicts, or register/transfer push tokens. A timed-out login may have issued a server token; retrying with the same persisted device ID revokes the previous token for that same account.

For normal switching, log out successfully first, then enter the other account's credentials. The installation ID stays the same; user profile, capability data, and bearer token do not carry across accounts.

## Files explained

- `lib/main.dart`: existing welcome, theme, bootstrap handling, branding, and connection retries. Starts the auth flow after bootstrap succeeds.
- `lib/config/installation_config.dart`: allowlisted flavor identity, fixed API endpoint, display name, optional branding, and future Firebase consistency boundary.
- `lib/api/api_client.dart`: the single networking client; JSON requests, bearer scoping, redirect prevention, status/validation handling, and typed responses.
- `lib/models/bootstrap_response.dart`: existing bootstrap DTOs, unchanged.
- `lib/models/auth_models.dart`: typed token, safe profile/branch, and capability objects (similar to PHP DTOs).
- `lib/auth/session_store.dart`: a small secure-storage interface and platform adapter. Tests can replace the platform boundary with memory storage.
- `lib/auth/session_controller.dart`: coordinates restore, login, validation, logout, persistence, and stale-response protection.
- `lib/auth/auth_flow.dart`: login form and minimal account home; uses the same branding/card/layout.
- `lib/auth/children_view.dart`: capability-gated child list, details, paginated attendance, summary date filter, pull-to-refresh, and child-specific errors.
- `lib/models/child_models.dart`: typed linked-child, placement, attendance-summary, and attendance-history data.
- `lib/l10n/app_strings.dart`: centralized Pashto (`ps`), Dari (`fa`), Arabic (`ar`), and English (`en`) interface translations.
- `lib/l10n/app_language.dart`: the explicit Flutter/backend locale mapping and text direction.
- `lib/l10n/locale_controller.dart`: Pashto default plus selection restoration and persistence independent of authentication.
- `lib/l10n/pashto_cupertino_localizations.dart`: focused Pashto labels for Cupertino widgets not covered by Flutter's SDK.
- `test/`: API/parser, storage, controller, child workflow, and widget tests. Synthetic credentials exist only in test fixtures and never reach the demo API.
- `integration_test/`: Android secure-storage and guardian workflow checks with mocked HTTP; these do not change live data.

## Automated verification

```powershell
dart format lib test integration_test
flutter analyze
flutter test
flutter build apk --debug --flavor demo
flutter test integration_test/session_storage_test.dart -d emulator-5554
flutter test integration_test/children_test.dart -d emulator-5554
```

Unit/widget coverage includes the login request/response, device requirement, credential/validation/rate/server failures, secure-storage adapter, bearer headers, server separation, restoration, invalid tokens, temporary failures, 403 preservation, logout success/failure, stale responses, capability scopes, linked-student parsing, empty/error states, child pagination, placement and attendance parsing, date filters, pull-to-refresh, revoked-child access, child switching, required fields, password visibility, duplicate-submit prevention, no-access home, logo fallback, and narrow RTL layout.

### Results on 2026-11-22

`dart format lib test integration_test` completed; `flutter analyze` reported no issues; all 42 unit/widget tests passed; all four guardian integration tests passed on `emulator-5554` using mocked HTTP; and the Android debug APK built successfully with the demo API URL. The normal app was then launched on the emulator and the public institution welcome screen showed **Connected**. The live authenticated guardian flow was verified separately as recorded above; the automated tests do not use the live account.

### Current placement rollout check (2026-11-23)

The designated demo guardian logged in successfully through the Android app; linked children, a child's academic details, attendance history, back navigation, Account, and logout were exercised. Logout returned to the signed-out screen. A separate live login/list/logout check returned HTTP 201/200/204 and three linked children. The live `GET me/students` response does not include `current_placement` on any item yet. The Flutter app accepts this older response, so the placement details remain absent from cards until the Laravel changes are deployed. No student or enrollment data was modified.

Deploy `app/Services/People/GuardianPortalService.php` and `app/Http/Controllers/Api/V1/MobileWorkflowController.php` to enable current placement summaries. Related regression coverage and contract documentation are in `tests/Feature/GuardianWorkflowTest.php`, `docs/mobile-api-v1.md`, and `docs/mobile-api-coverage.md`. No migration is required. Rebuild/release the Flutter app separately if distributing a newer client.

On 2026-11-23, `dart format`, `flutter analyze`, all 44 Flutter tests, the mocked Android guardian navigation test, the Android debug build, PHP syntax checks, and all 12 `GuardianWorkflowTest` cases passed. Laravel Pint was attempted with the PHP 8.5 launcher but could not write its formatted output in the Laravel workspace; this tooling issue does not affect the passing tests or PHP syntax checks.

## Manual demo verification (designated account only)

The live designated-account flow has already been verified (login, restore, child list/details, attendance summary, and confirmed logout). To repeat it on the emulator, run the command above and sign in only with the authorized demo account using credentials supplied through the approved local channel; do not put them in source code or documentation.

1. The public institution name and Connected status appear; the current demo has no logo, so the school icon is expected.
2. Tap **Log in**. Blank fields show required errors without a request; use the eye control to check password visibility.
3. After login, open **My Children**. The live account currently shows three children. Tap a student to see placement, recorded attendance summary, and paginated attendance history.
4. Use **Filter summary by dates** to request date-bounded totals. History pages remain the complete API-provided history because that route does not accept date bounds.
5. Force-stop/reopen while signed in. The app verifies the saved session before showing the student list. A temporary network failure preserves the session and offers retry.
6. Tap **Log out**. After HTTP 204, the app returns to the login screen and no child data remains visible.

This app remains read-only and adds no attendance write actions or other business workflows.

### Earlier bootstrap/authentication milestone results (2026-11-17)

Formatting completed; flutter analyze reported no issues; all 35 unit/widget tests passed. The Android debug APK built successfully. The emulator integration test passed using real Android secure storage and mocked HTTP (synthetic session restore and logout). A read-only live bootstrap request returned HTTP 200 with application/json. No live authentication requests were made. iOS build/signing remains unverified on Windows.
The normal demo-configured app was then rebuilt, installed, and launched. Visual inspection confirmed the live institution welcome screen and empty branded email/password login form. The emulator is left on that login form; no credentials were entered.
