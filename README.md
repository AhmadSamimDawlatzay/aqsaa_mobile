# Aqsaa Mobile

First milestone: a public institution connection screen. No authentication or business writes are implemented.

## Run on Android

```powershell
cd C:\Projects\aqsaa_mobile
flutter pub get
flutter run -d emulator-5554 --dart-define=API_BASE_URL=https://demo.aqsaa.app/api/v1
```

`API_BASE_URL` **includes `/api/v1`**. The client appends only `/bootstrap` (a trailing slash is accepted). It requires HTTPS and rejects missing or duplicated API prefixes. The demo URL is also the default. Changing a dart-define requires a new run/build, not hot reload. Certificate validation stays enabled.

## How it works

- `lib/main.dart`: the welcome screen owns one API client. A FutureBuilder displays loading, connection success, or an error with Retry. Refresh fetches again. It closes the client when the screen is disposed.
- `lib/api/api_client.dart`: sends GET with `Accept: application/json`, checks status/content type, decodes UTF-8 JSON, and applies a 15-second timeout. It resolves public logo paths under `/storage/` at the installation root.
- `lib/models/bootstrap_response.dart`: typed Dart objects for the JSON, similar to a small read-only DTO in PHP. Invalid response shapes fail instead of pretending the connection succeeded.
- `lib/l10n/app_strings.dart`: English UI copy in one place for later Pashto (`ps`), Dari (`fa`), Arabic (`ar`), and English (`en`) translations. No translations are claimed in this milestone. Directional spacing and an injectable `textDirection` support RTL; the screen currently uses English/LTR, independently of the institution's default locale.
- Android's main manifest includes INTERNET permission for debug and release builds.

## Verified backend contract

Read from `C:\Projects\madrasa`: `AGENTS.md`, both mobile API documents, `routes/api.php`, `bootstrap/app.php`, `BootstrapController::institution`, the Institution model/schema, and public filesystem configuration. There is no nested AGENTS.md applicable to the inspected paths and no `.ai/rules` directory. Bootstrap returns a direct JsonResponse, not a Resource and not a `data` envelope. The public route is outside the authenticated route group.

`GET /api/v1/bootstrap` returns:

```json
{
  "api_version": "v1",
  "institution": {
    "name": "Aqsaa App Sample Academy",
    "short_name": "Sample Academy",
    "logo": null,
    "timezone": "Asia/Kabul",
    "default_locale": "ps",
    "default_calendar": "gregorian",
    "currency": {"id": 1, "code": "AFN", "name": "افغانۍ"}
  },
  "supported_locales": ["ps", "fa", "ar", "en"]
}
```

`institution` can be null; `short_name`, `logo`, and `currency` are nullable. A null institution displays an explicit connected-but-not-configured message. A missing or failed logo displays a school icon. The logo is a public disk path such as `institutions/logos/example.png`, resolved as `/storage/institutions/logos/example.png`. If the server overrides `PUBLIC_STORAGE_URL` to a CDN, the API currently does not expose that setting; logo URL configuration would need to be agreed in a later milestone.

On 2026-11-17, a read-only HTTPS request to `https://demo.aqsaa.app/api/v1/bootstrap` returned **200 OK**, `Content-Type: application/json`, with the contract above. No mismatch was observed. The demo has no logo, so no live logo download can be verified. No mock data is used by the app; fixtures exist only in tests. No Laravel files or remote data were changed.

The optional local Artisan route listing could not run: installed default CLI PHP is 8.2.35, while Composer requires >=8.4.1. Routing was verified from source and the live request instead.

## Checks

```powershell
dart format lib test
flutter analyze
flutter test
flutter build apk --debug --dart-define=API_BASE_URL=https://demo.aqsaa.app/api/v1
```

Tests cover response parsing, nullable institution, bad contracts, URL/header construction, logo resolution, HTTP/HTML/network/timeout failures, loading, success, retry, empty state, failed-logo fallback, and narrow RTL layout.

Verification result: dart format completed, flutter analyze reported no issues, and all 10 tests passed. The debug APK built and was installed/launched on emulator-5554. An emulator screenshot confirmed the live institution name and Connected state. The demo logo is null, so the school icon is expected.
