# Nadu Mobile

Flutter client for authorised Nadu typing staff. The client lives outside the Laravel repository. Its companion API is implemented under `C:\Nadu_System\nadu_system` without changing Filament workflows or company case tables.

## Current integration status

The Laravel repository at `C:\Nadu_System\nadu_system` now contains `/api/v1/` endpoints for Sanctum mobile login, logout, identity, permitted typing companies, reference data, case listing/detail/creation, and private attachment upload. Apply the reviewed central-database Sanctum migration before connecting a staging build. This app does not use browser login or connect directly to MySQL.

The existing typing form was inspected to build the case form. Fields and Sinhala labels follow `app/Filament/Typing/Resources/Nadus/Schemas/NaduForm.php`. The client sends `company_id`; it never sends a table name. The server must resolve the company and table through trusted authorization and existing Nadu business logic.

## Run

Install Flutter with Android and iOS toolchains, then from this folder:

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=https://10.100.0.1/api/v1/
```

For a release APK:

```powershell
flutter build apk --release --dart-define=API_BASE_URL=https://10.100.0.1/api/v1/
```

Connect the device to WireGuard before opening the app. The VM must serve HTTPS with a certificate trusted by the device and valid for `10.100.0.1`. If the certificate is issued to a DNS name, use that name in `API_BASE_URL` and configure it to resolve to the VM's WireGuard address while connected. The app does not allow cleartext HTTP or bypass certificate checks. Do not use production secrets in build arguments or logs.

## Mobile API contract expected by the client

All successful responses use a `{ "data": ... }` JSON envelope. Protected requests use `Authorization: Bearer <token>`.

| Method and path | Expected client behavior |
| --- | --- |
| `POST auth/login` | Body `{email, password}`; response `data` includes `{token, user: {name, email}}` |
| `POST auth/logout` | Revoke the current Sanctum token |
| `GET me` | Return `{name, email}` for the token owner |
| `GET companies` | Return only companies the user may type for; each row includes `id`, `company_name` |
| `GET cases?company_id=…&per_page=5` | Return recent cases for the selected permitted company |
| `POST cases` | Accept `company_id` and the fields in the existing typing form; honor `Idempotency-Key`; return generated `id` and `nadu_ankaya` |
| `PUT cases/{id}` | Update a case in the selected permitted company using the same validated typing form fields |
| `POST attachments` | Authenticated multipart upload with `company_id`, `case_id`, and `file`; validate type, size, ownership and company access |

The server enforces typing-role access, active-company checks, validation, rate limits, audit logging, idempotency, and private attachment storage. These controls cannot be provided by the Flutter client alone.

## App behavior

- Android and iOS project targets are generated.
- Riverpod manages the login session; Dio calls the API; Flutter Secure Storage holds the authentication token; Connectivity Plus, camera capture, and file selection support online entry.
- Authentication tokens are stored with `flutter_secure_storage` and removed at logout.
- Case fields and picked attachments remain in memory for the open form only; there is no local case database, offline queue, background sync, or offline submission.
- Case submission checks connectivity and requires a successful online response. A submit button lock prevents repeated taps; the server must enforce idempotency as well.
- Recent cases and the full paginated case list can be opened in the existing entry form and updated online.
- The client uses HTTPS only and does not disable certificate validation.

## Remaining integration work

1. Apply the Sanctum token migration to the central application database; it does not migrate or modify the company case databases.
2. Configure a shared persistent cache store with atomic locks and the production HTTPS API URL, then run end-to-end staging checks.
3. Verify Sinhala rendering on supported Android and iOS versions and add a bundled Sinhala font if device fallback is inconsistent.
4. Build and sign the iOS app on macOS/Xcode, then run Android and iOS device tests against staging before release.
