# Task 3 Report: Auth session + Connect flow

## Status

DONE

## Implementation

- Added `AuthRemoteSource.me()` for `GET /v1/me` and `ApiKeyInfo` parsing.
- Added `AuthSessionRepository` with `restore()`, `connect(String apiKey)`,
  `signOut()`, and `currentInfo`.
- Added `ConnectBloc` with `ConnectStarted`, `ConnectSubmitted`, and
  `ConnectOpenDashboard` events plus `initial`, `submitting`,
  `authenticated`, and `failure(message)` states.
- Added `ConnectPage` as a `HookWidget` with dashboard launch,
  API-key/advanced-token input, connect submission, failure copy, and connected
  account summary.
- Added `AppDi` wiring for `AppConfig`, `Dio`, `CursorApiClient`,
  `SecureCredentialsStore`, auth source/repository, and `ConnectBloc`.
- Extended `ApiKeyInfo` with value equality for bloc state comparisons.

## TDD / Verification

- Wrote `test/features/auth/connect_bloc_test.dart` for:
  - valid key submission -> authenticated
  - `UnauthorizedException` -> failure message
  - empty key -> failure without repository call
- Confirmed initial red test run failed due missing auth repository/bloc types.
- Final verification:
  - `flutter analyze` -> no issues found
  - `flutter test test/features/auth` -> all tests passed
  - `flutter test` -> all tests passed

## Commits

- `c3f5e85` feat: add API key connect and session restore
- `3aedab4` chore: satisfy auth repository analysis

## Self-review

- Scope matches Task 3 brief and reuses Task 2 primitives.
- Invalid restored keys clear secure storage and client state.
- Invalid submitted keys clear only the client session before rethrowing, so a
  failed replacement attempt does not overwrite stored credentials.
- No known concerns.
