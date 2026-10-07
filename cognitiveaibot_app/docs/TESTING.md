# Testing the app

## Test account (development database only)

| | |
|---|---|
| Email | `mobile-test@example.test` |
| Password | in `docs/TESTING.local.md` (not committed) |

Created through the app's own sign-up screen against the mock backend. It
exists only in the local development Postgres database. Give it credits from
`cognitiveaibot_web/backend`:

```
node src/scripts/grant-credits.js mobile-test@example.test 50 "Mobile app testing"
```

## Backend for development

Use the mock-AI backend, never the real one on port 3000 (that calls OpenAI
and costs money). From `cognitiveaibot_web/backend`:

```
PORT=3100 node src/scripts/dev-mock-ai.js
```

OpenAI (GPT) models are answered by a local fake that echoes your message;
other providers' models show as unavailable unless their keys are set.

## Running the app

```
flutter run -d macos --dart-define=API_BASE_URL=http://localhost:3100
flutter run -d "iPhone 17 Pro" --dart-define=API_BASE_URL=http://localhost:3100
```

Build-time settings: `API_BASE_URL` (default `http://localhost:3000`),
`FRONTEND_URL` (web app, default `http://localhost:5173`; the desktop
Upgrade button opens `<FRONTEND_URL>/upgrade`), and the RevenueCat keys in
`lib/core/revenuecat/revenuecat_config.dart` (no key: in-app purchases off).

## Automated tests

- `flutter test`: unit and widget tests with mocked HTTP (API client, SSE
  parser, repositories, chat session, screens). No backend needed.
- End-to-end on a device against the mock backend (`integration_test/`):

```
# once, to create the account through the sign-up screen
flutter drive -d <device> --driver=test_driver/integration_test.dart \
  --target=integration_test/signup_test.dart \
  --dart-define=API_BASE_URL=http://localhost:3100 \
  --dart-define=E2E_EMAIL=mobile-test@example.test --dart-define=E2E_PASSWORD=<password from docs/TESTING.local.md>

# then grant credits (above), and run the main flow, then the relaunch check
flutter drive ... --target=integration_test/app_test.dart (same defines)
flutter drive ... --target=integration_test/relaunch_test.dart (same defines)
```

Screenshots taken by the tests are written to `build/e2e_screenshots/`.

## Notes

- Session token: Keychain on iOS. On macOS a team-signed build uses the
  data-protection Keychain; a local ad-hoc build (no team, as now) can't, so
  the token is kept in a file inside the app's sandbox container
  (`~/Library/Containers/com.cognitiveaibot.cognitiveaibot/Data/Library/Application Support/cognitiveaibot/session`).
- `flutter drive` end-to-end tests click into fields before typing; on macOS
  the test framework's `enterText` alone doesn't focus a field that lost focus.
