# Nadu Mobile

Flutter client for authorised Nadu typing staff. This project lives outside the Laravel repository; it does not change Laravel, Filament, or MySQL.

## Current integration status

The Laravel repository at `C:\Nadu_System\nadu_system` currently has web routes only (`routes/web.php` and `routes/console.php`). It does not currently expose `routes/api.php` or the mobile REST endpoints. The mobile UI and API client are ready for the versioned contract below, but sign-in, company loading, case submission, recent submissions, and attachment uploads require those server endpoints to exist. This app does not use browser login or connect directly to MySQL.

The existing typing form was inspected to build the case form. Fields and Sinhala labels follow `app/Filament/Typing/Resources/Nadus/Schemas/NaduForm.php`. The client sends `company_id`; it never sends a table name. The server must resolve the company and table through trusted authorization and existing Nadu business logic.

## Run

Install Flutter with Android and iOS toolchains, then from this folder:

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=https://your-host/api/v1/
```

`API_BASE_URL` must use HTTPS and end in `/api/v1/`. Without a real endpoint, the app opens in setup mode and requests will fail safely. Do not use production secrets in build arguments or logs.

## Mobile API contract expected by the client

All responses should use JSON and return protected data only after server authorization. Suggested response envelopes may be plain objects or `{ "data": ... }`.

| Method and path | Expected client behavior |
| --- | --- |
| `POST auth/login` | Body `{email, password}`; response includes `{token, user: {name, email}}` |
| `POST auth/logout` | Revoke the current Sanctum token |
| `GET me` | Return `{name, email}` for the token owner |
| `GET companies` | Return only companies the user may type for; each row includes `id`, `company_name` |
| `GET cases?per_page=5` | Return recent cases permitted to the user |
| `POST cases` | Accept `company_id` and the fields in the existing typing form; honor `Idempotency-Key`; return generated `id` and `nadu_ankaya` |
| `POST attachments` | Authenticated multipart upload with `case_id` and `file`; validate type, size, ownership and company access |

The server must enforce typing-role access, company isolation, validation, rate limits, audit logging, idempotency, and attachment storage. These controls cannot be provided by the Flutter client alone. No backend changes have been made as requested.

## App behavior

- Android and iOS project targets are generated.
- Riverpod manages the login session; Dio calls the API; Flutter Secure Storage holds the authentication token; Connectivity Plus, camera capture, and file selection support online entry.
- Authentication tokens are stored with `flutter_secure_storage` and removed at logout.
- Case fields and picked attachments remain in memory for the open form only; there is no local case database, offline queue, background sync, or offline submission.
- Case submission checks connectivity and requires a successful online response. A submit button lock prevents repeated taps; the server must enforce idempotency as well.
- The client uses HTTPS only and does not disable certificate validation.

## Remaining integration work

1. Add and review the mobile API in the existing Laravel application as a separate approved backend change, reusing existing authorization, company context, validation and case creation logic.
2. Agree on exact request/response envelopes and attachment association semantics, then align the client contract if needed.
3. Verify Sinhala rendering on the supported Android and iOS versions and add a bundled Sinhala font if device fallback is inconsistent.
4. Add API-backed widget/unit tests and run Android/iOS builds against a staging API before release signing.
