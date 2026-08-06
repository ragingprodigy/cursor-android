# Flutter Cursor Android App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship an Android Flutter app (`io.haxl.cursor`) that connects with a Cursor API key and remotely launches, monitors, follows up on, and cancels Cloud Agents via the public API.

**Architecture:** Feature-first Flutter client (`auth`, `agents`, `launch`, `thread`, `settings`) with thin domain models, Dio HTTP + SSE, Drift cache/drafts, secure API-key storage, `flutter_bloc` for feature state, and `flutter_hooks` / `HookWidget` for UI (no `StatefulWidget`).

**Tech Stack:** Flutter (stable), Dart 3, `flutter_bloc`, `flutter_hooks`, `dio`, `go_router`, `flutter_secure_storage`, Drift/SQLite, `url_launcher`, `bloc_test`, `mocktail`.

## Global Constraints

- Package / applicationId: `io.haxl.cursor`
- Platform v1: Android only
- Backend: public Cloud Agents API only — base URL default `https://api.cursor.com`
- Auth: API key Bearer (guided connect + paste); no OAuth in v1
- State: `flutter_bloc` + `flutter_hooks`; avoid `StatefulWidget`
- Secrets: never commit API keys; support runtime paste + optional `--dart-define=CURSOR_API_KEY`
- Offline: read cache + drafts; mutations require network
- Launch fields: prompt, repo, branch/ref, model
- Notifications: in-app poll/stream only
- UI: Cursor-like dark, dense product UI
- Tests: light unit + bloc tests; manual device checks
- Delivery: `flutter run` + sideloadable release APK
- Spec: `docs/superpowers/specs/2026-08-05-flutter-cursor-android-design.md`

---

## File map

```
README.md
pubspec.yaml
analysis_options.yaml
lib/
  main.dart
  app/
    app.dart
    router.dart
    theme.dart
    di.dart
  core/
    config/app_config.dart
    error/app_exception.dart
    network/cursor_api_client.dart
    network/sse_client.dart
    storage/secure_credentials_store.dart
    db/app_database.dart
    db/app_database.g.dart          # generated
  features/
    auth/
      data/auth_remote_source.dart
      data/auth_session_repository.dart
      domain/api_key_info.dart
      presentation/connect_bloc.dart
      presentation/connect_page.dart
    agents/
      data/agents_remote_source.dart
      data/agents_local_source.dart
      data/agents_repository.dart
      domain/agent_summary.dart
      presentation/agents_bloc.dart
      presentation/agents_page.dart
    launch/
      data/catalog_remote_source.dart
      data/launch_draft_store.dart
      data/launch_repository.dart
      domain/repository_ref.dart
      domain/model_option.dart
      presentation/launch_bloc.dart
      presentation/launch_page.dart
    thread/
      data/thread_remote_source.dart
      data/thread_local_source.dart
      data/thread_repository.dart
      domain/agent_detail.dart
      domain/agent_run.dart
      domain/thread_message.dart
      presentation/thread_bloc.dart
      presentation/thread_page.dart
      presentation/widgets/message_list.dart
      presentation/widgets/follow_up_composer.dart
    settings/
      presentation/settings_page.dart
test/
  core/network/cursor_api_client_test.dart
  features/auth/connect_bloc_test.dart
  features/auth/api_key_info_test.dart
  features/agents/agents_repository_test.dart
  features/agents/agents_bloc_test.dart
  features/launch/launch_bloc_test.dart
  features/thread/thread_bloc_test.dart
  features/thread/thread_message_mapper_test.dart
```

---

### Task 1: Scaffold Flutter Android project

**Files:**
- Create: Flutter project root files (`pubspec.yaml`, `android/`, `lib/main.dart`, …)
- Modify: `README.md`
- Create: `lib/app/`, `lib/core/`, `lib/features/` placeholder dirs
- Test: `flutter test` (default smoke) then replace later

**Interfaces:**
- Consumes: none
- Produces: runnable Android Flutter app with package `io.haxl.cursor`

- [ ] **Step 1: Ensure Flutter SDK is available**

If `flutter` is missing, install stable Flutter to `/opt/flutter` (or `$HOME/flutter`) and add it to `PATH`. Verify:

```bash
flutter --version
flutter doctor
```

Expected: Flutter stable reported; Android toolchain usable enough for APK builds (accept partial doctor warnings if emulator absent).

- [ ] **Step 2: Create the project with the correct package**

From repo root (`/workspace`):

```bash
flutter create --org io.haxl --project-name cursor --platforms=android .
```

If the directory is non-empty (docs already present), create in a temp dir and move app files into the repo, preserving `docs/` and `.git`.

Confirm Android applicationId:

```bash
rg "applicationId|namespace" android/app/build.gradle android/app/build.gradle.kts
```

Expected: `io.haxl.cursor`.

- [ ] **Step 3: Add dependencies**

Update `pubspec.yaml` dependencies (use resolvable current versions):

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_bloc: ^9.1.1
  flutter_hooks: ^0.21.2
  equatable: ^2.0.7
  dio: ^5.8.0+1
  go_router: ^15.1.2
  flutter_secure_storage: ^9.2.4
  drift: ^2.26.1
  drift_flutter: ^0.2.4
  sqlite3_flutter_libs: ^0.5.32
  path_provider: ^2.1.5
  path: ^1.9.1
  url_launcher: ^6.3.1
  connectivity_plus: ^6.1.4

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  build_runner: ^2.4.15
  drift_dev: ^2.26.1
  bloc_test: ^10.0.0
  mocktail: ^1.0.4
```

Run:

```bash
flutter pub get
```

Expected: success, lockfile updated.

- [ ] **Step 4: Replace default app with feature stubs**

`lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:cursor/app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CursorApp());
}
```

`lib/app/app.dart`:

```dart
import 'package:flutter/material.dart';

class CursorApp extends StatelessWidget {
  const CursorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Cursor',
      home: Scaffold(
        body: Center(child: Text('Cursor')),
      ),
    );
  }
}
```

- [ ] **Step 5: Verify analyze + tests**

```bash
flutter analyze
flutter test
```

Expected: no errors; default/smoke tests pass (or update/remove counter test if still present).

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "chore: scaffold Flutter Android app io.haxl.cursor"
```

---

### Task 2: Core config, errors, credentials, HTTP client

**Files:**
- Create: `lib/core/config/app_config.dart`
- Create: `lib/core/error/app_exception.dart`
- Create: `lib/core/storage/secure_credentials_store.dart`
- Create: `lib/core/network/cursor_api_client.dart`
- Test: `test/core/network/cursor_api_client_test.dart`
- Test: `test/features/auth/api_key_info_test.dart` (DTO living under auth; parse helpers may start here)

**Interfaces:**
- Consumes: none
- Produces:
  - `AppConfig({String apiBaseUrl, String? bootstrapApiKey})`
  - `AppConfig.fromEnvironment()` reading `CURSOR_API_BASE_URL`, `CURSOR_API_KEY`
  - `SecureCredentialsStore` with `Future<void> saveApiKey(String)`, `Future<String?> readApiKey()`, `Future<void> clear()`
  - `CursorApiClient` with `void setApiKey(String?)`, `Future<Response<T>> get/post/...`
  - `AppException` subtypes: `UnauthorizedException`, `RateLimitedException`, `NetworkException`, `ApiException`

- [ ] **Step 1: Write failing client tests**

`test/core/network/cursor_api_client_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cursor/core/network/cursor_api_client.dart';
import 'package:cursor/core/error/app_exception.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);
  final Future<ResponseBody> Function(RequestOptions) handler;
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future? cancelFuture) {
    return handler(options);
  }
}

void main() {
  test('attaches bearer token when api key set', () async {
    late RequestOptions seen;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.cursor.com'));
    dio.httpClientAdapter = _Adapter((options) async {
      seen = options;
      return ResponseBody.fromString('{"ok":true}', 200, headers: {
        Headers.contentTypeHeader: ['application/json'],
      });
    });
    final client = CursorApiClient(dio);
    client.setApiKey('test-key');
    await client.get<Map<String, dynamic>>('/v1/me');
    expect(seen.headers['Authorization'], 'Bearer test-key');
  });

  test('maps 401 to UnauthorizedException', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.cursor.com'));
    dio.httpClientAdapter = _Adapter((options) async {
      return ResponseBody.fromString('{"message":"Invalid API key"}', 401, headers: {
        Headers.contentTypeHeader: ['application/json'],
      });
    });
    final client = CursorApiClient(dio);
    expect(() => client.get('/v1/me'), throwsA(isA<UnauthorizedException>()));
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
flutter test test/core/network/cursor_api_client_test.dart
```

Expected: FAIL — `CursorApiClient` / `UnauthorizedException` missing.

- [ ] **Step 3: Implement core types**

`lib/core/config/app_config.dart`:

```dart
class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    this.bootstrapApiKey,
  });

  final String apiBaseUrl;
  final String? bootstrapApiKey;

  factory AppConfig.fromEnvironment() {
    const base = String.fromEnvironment(
      'CURSOR_API_BASE_URL',
      defaultValue: 'https://api.cursor.com',
    );
    const key = String.fromEnvironment('CURSOR_API_KEY');
    return AppConfig(
      apiBaseUrl: base,
      bootstrapApiKey: key.isEmpty ? null : key,
    );
  }
}
```

`lib/core/error/app_exception.dart`:

```dart
sealed class AppException implements Exception {
  const AppException(this.message);
  final String message;
}

class UnauthorizedException extends AppException {
  const UnauthorizedException([super.message = 'API key rejected']);
}

class RateLimitedException extends AppException {
  const RateLimitedException([super.message = 'Rate limited']);
}

class NetworkException extends AppException {
  const NetworkException([super.message = 'Network unavailable']);
}

class ApiException extends AppException {
  const ApiException(super.message, {this.statusCode});
  final int? statusCode;
}
```

Implement `SecureCredentialsStore` wrapping `FlutterSecureStorage` with keys `cursor_api_key`.

Implement `CursorApiClient`:
- wraps Dio
- interceptor adds `Authorization: Bearer <key>` when set
- maps Dio errors: 401 → `UnauthorizedException`, 429 → `RateLimitedException`, connection errors → `NetworkException`, other → `ApiException` with server `message` when JSON present

- [ ] **Step 4: Run tests to verify they pass**

```bash
flutter test test/core/network/cursor_api_client_test.dart
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core test/core
git commit -m "feat: add config, secure credentials, and Cursor API client"
```

---

### Task 3: Auth session + Connect flow

**Files:**
- Create: `lib/features/auth/domain/api_key_info.dart`
- Create: `lib/features/auth/data/auth_remote_source.dart`
- Create: `lib/features/auth/data/auth_session_repository.dart`
- Create: `lib/features/auth/presentation/connect_bloc.dart`
- Create: `lib/features/auth/presentation/connect_page.dart`
- Create: `lib/app/di.dart` (initial wiring)
- Test: `test/features/auth/api_key_info_test.dart`
- Test: `test/features/auth/connect_bloc_test.dart`

**Interfaces:**
- Consumes: `CursorApiClient`, `SecureCredentialsStore`, `AppConfig`
- Produces:
  - `ApiKeyInfo` (`apiKeyName`, `userEmail?`, `userId?`, `createdAt`)
  - `AuthSessionRepository.restore()`, `.connect(String apiKey)`, `.signOut()`, `.currentInfo`
  - `ConnectBloc` events: `ConnectStarted`, `ConnectSubmitted(String key)`, `ConnectOpenDashboard`
  - `ConnectState` statuses: `initial`, `submitting`, `authenticated`, `failure(message)`

- [ ] **Step 1: Write failing DTO + bloc tests**

`test/features/auth/api_key_info_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cursor/features/auth/domain/api_key_info.dart';

void main() {
  test('parses user-scoped /v1/me payload', () {
    final info = ApiKeyInfo.fromJson({
      'apiKeyName': 'Production API Key',
      'userId': 42,
      'createdAt': '2026-04-13T18:30:00.000Z',
      'userEmail': 'developer@example.com',
    });
    expect(info.apiKeyName, 'Production API Key');
    expect(info.userEmail, 'developer@example.com');
    expect(info.userId, 42);
  });
}
```

`test/features/auth/connect_bloc_test.dart` — use `mocktail` mocks for `AuthSessionRepository`:
- submit valid key → `authenticated`
- repository throws `UnauthorizedException` → `failure` with message
- empty key → failure without calling repository

- [ ] **Step 2: Run tests to verify they fail**

```bash
flutter test test/features/auth
```

Expected: FAIL — missing types.

- [ ] **Step 3: Implement auth feature**

- `AuthRemoteSource.me()` → `GET /v1/me`
- `AuthSessionRepository.connect`:
  1. trim key; reject empty
  2. `apiClient.setApiKey(key)`
  3. call `me()`
  4. on success `credentials.saveApiKey(key)` + keep info
  5. on `UnauthorizedException`, clear key from client and rethrow
- `restore()`: read secure key (or bootstrap from `AppConfig.bootstrapApiKey`), validate via `/v1/me`, or clear on 401
- `ConnectPage` as `HookWidget`:
  - guided copy + button launching `https://cursor.com/dashboard/api` via `url_launcher`
  - API key `TextField`
  - Connect button dispatches `ConnectSubmitted`
  - advanced token path can be the same field (no separate oauth)

Wire `ConnectBloc` in `di.dart`.

- [ ] **Step 4: Run tests**

```bash
flutter test test/features/auth
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/auth lib/app/di.dart test/features/auth
git commit -m "feat: add API key connect and session restore"
```

---

### Task 4: Drift database for cache and drafts

**Files:**
- Create: `lib/core/db/app_database.dart`
- Create: generated `lib/core/db/app_database.g.dart`
- Modify: `lib/app/di.dart` to open DB
- Test: exercise DAO methods via in-memory Drift database in `test/core/db/app_database_test.dart`

**Interfaces:**
- Consumes: none
- Produces Drift tables/DAOs:
  - `Agents` (`id`, `name`, `status`, `url`, `latestRunId`, `createdAt`, `updatedAt`, `json`, `cachedAt`)
  - `ThreadSnapshots` (`agentId` PK, `json`, `cachedAt`)
  - `Drafts` (`id` PK — `launch` or `followup:<agentId>`, `text`, `repoUrl`, `startingRef`, `modelId`, `updatedAt`)

- [ ] **Step 1: Write failing DB test**

```dart
test('upserts agents and reads newest-first cache', () async {
  final db = AppDatabase.memory();
  await db.agentsDao.upsertAll([
    AgentCacheRow(...),
  ]);
  final rows = await db.agentsDao.getAll();
  expect(rows.first.id, 'bc-1');
  await db.close();
});
```

(Adapt field names to the concrete Drift row types you define.)

- [ ] **Step 2: Run test to verify fail**

```bash
flutter test test/core/db/app_database_test.dart
```

- [ ] **Step 3: Implement Drift schema + codegen**

```bash
dart run build_runner build --delete-conflicting-outputs
```

Provide `AppDatabase.memory()` constructor using `NativeDatabase.memory()` for tests, and `AppDatabase.defaults()` using `drift_flutter` / path_provider for device.

- [ ] **Step 4: Pass tests + commit**

```bash
flutter test test/core/db/app_database_test.dart
git add lib/core/db test/core/db
git commit -m "feat: add Drift cache and drafts database"
```

---

### Task 5: App router, theme, and session gate

**Files:**
- Create: `lib/app/theme.dart`
- Create: `lib/app/router.dart`
- Modify: `lib/app/app.dart`, `lib/main.dart`, `lib/app/di.dart`
- Create placeholder pages if needed: `agents_page.dart`, `settings_page.dart`

**Interfaces:**
- Consumes: `AuthSessionRepository`, `ConnectBloc`
- Produces:
  - `CursorTheme.dark()` — dark Cursor-like ThemeData (custom font via `google_fonts` **or** bundled font; do not use Inter/Roboto/system-only)
  - `GoRouter` routes: `/connect`, `/agents`, `/agents/new`, `/agents/:id`, `/settings`
  - Redirect: unauthenticated → `/connect`; authenticated visiting `/connect` → `/agents`

- [ ] **Step 1: Implement theme**

Dark background (~`#0G` IDE charcoal, e.g. `#0B0D12`), elevated surfaces, accent muted blue/teal (not purple glow), distinctive display + body fonts.

- [ ] **Step 2: Implement router with auth refresh Listenable**

Use a simple `AuthController extends ChangeNotifier` updated by session repository, or `GoRouterRefreshStream` from session state.

- [ ] **Step 3: Bootstrap in main**

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  final dependencies = await AppDependencies.create(config);
  await dependencies.authSession.restore();
  runApp(CursorApp(dependencies: dependencies));
}
```

- [ ] **Step 4: Manual smoke**

```bash
flutter analyze
flutter run
```

Expected: Connect screen when no key; with `--dart-define=CURSOR_API_KEY=...` after restore, lands on Agents placeholder.

- [ ] **Step 5: Commit**

```bash
git add lib/app lib/main.dart lib/features
git commit -m "feat: add dark theme, router, and auth gate"
```

---

### Task 6: Agents list (remote + cache + UI)

**Files:**
- Create: agents feature files listed in file map
- Test: `test/features/agents/agents_repository_test.dart`
- Test: `test/features/agents/agents_bloc_test.dart`

**Interfaces:**
- Consumes: `CursorApiClient`, `AppDatabase`
- Produces:
  - `AgentSummary(id, name, status, url, latestRunId?, createdAt, updatedAt)`
  - `AgentsRepository.watchCached()`, `refresh()`
  - `AgentsBloc` events: `AgentsStarted`, `AgentsRefreshed`
  - States: loading/cached/ready/failure + `isOffline` / `isStale` flags

- [ ] **Step 1: Write failing repository test**

- When remote succeeds, cache upserted and returned
- When remote throws `NetworkException`, return cached list and mark stale/offline
- Parse list payload `items` from `/v1/agents`

- [ ] **Step 2: Implement remote/local/repository**

`GET /v1/agents?limit=50` → map DTOs → upsert Drift → emit.

- [ ] **Step 3: Implement AgentsBloc + AgentsPage (`HookWidget`)**

- Show brand mark “Cursor” as strong header signal
- List tiles: name, status, updated time
- Pull-to-refresh
- FAB / primary CTA → `/agents/new`
- Settings entry → `/settings`
- Subtle offline/stale banner when applicable

- [ ] **Step 4: Tests + commit**

```bash
flutter test test/features/agents
git add lib/features/agents test/features/agents
git commit -m "feat: list Cloud Agents with stale-while-revalidate cache"
```

---

### Task 7: Launch agent (repos, models, draft, create)

**Files:**
- Create: launch feature files
- Test: `test/features/launch/launch_bloc_test.dart`

**Interfaces:**
- Consumes: `CursorApiClient`, drafts DAO
- Produces:
  - `CatalogRemoteSource.listRepositories()`, `listModels()`
  - `LaunchDraftStore` load/save/clear for id `launch`
  - `LaunchRepository.createAgent(LaunchRequest)`
  - `LaunchRequest({required String prompt, String? repoUrl, String? startingRef, String? modelId})`
  - `LaunchBloc` → on success emits `created(agentId)` for navigation

**API notes to encode in code comments + behavior:**
- `GET /v1/repositories` is strictly rate limited (1/user/minute). Cache aggressively; on failure show last cache / graceful empty + message.
- Omit `model` field entirely when user picks “Default”.

- [ ] **Step 1: Write failing launch bloc tests**

- Autosave draft on field changes
- Submit empty prompt → validation failure
- Submit success → clear draft + `created`
- Network failure → keep draft + failure message

- [ ] **Step 2: Implement catalog + create**

Create body:

```json
{
  "prompt": { "text": "..." },
  "model": { "id": "..." },
  "repos": [{ "url": "...", "startingRef": "main" }]
}
```

Parse create response `agent.id`.

- [ ] **Step 3: LaunchPage UI (`HookWidget`)**

Fields: prompt (multiline), repo dropdown/search from cached repos, branch/ref text field, model dropdown (include Default). Submit CTA.

- [ ] **Step 4: Wire router navigate to `/agents/:id` on success**

- [ ] **Step 5: Tests + commit**

```bash
flutter test test/features/launch
git add lib/features/launch test/features/launch
git commit -m "feat: launch Cloud Agent with prompt, repo, ref, model"
```

---

### Task 8: Thread load + conversation mapping

**Files:**
- Create: thread domain/data/presentation (page can be read-only first)
- Test: `test/features/thread/thread_message_mapper_test.dart`
- Test: `test/features/thread/thread_bloc_test.dart` (load/refresh cases)

**Interfaces:**
- Consumes: `CursorApiClient`, Drift thread snapshots
- Produces:
  - `AgentDetail`, `AgentRun` (id, status, promptText?, resultText?, createdAt, …)
  - `ThreadMessage` sealed/equatable: `UserMessage`, `AssistantMessage`, `ToolStepMessage`
  - `ThreadRepository.load(agentId)`, `watchCache(agentId)`
  - Mapper: runs → ordered messages (user prompt then assistant result; tool steps if present in stored run payload)

- [ ] **Step 1: Write mapper tests**

Given two runs (one finished, one running without result), expect ordered user/assistant messages and no fabricated assistant text.

- [ ] **Step 2: Implement GET agent + list runs + cache snapshot**

- [ ] **Step 3: ThreadPage shows header + messages; composer disabled stub OK until Task 9**

- [ ] **Step 4: Tests + commit**

```bash
flutter test test/features/thread
git add lib/features/thread test/features/thread
git commit -m "feat: load agent thread conversation from runs"
```

---

### Task 9: Stream, follow-up, cancel

**Files:**
- Create: `lib/core/network/sse_client.dart`
- Modify: thread remote/repository/bloc/page/widgets
- Test: extend `test/features/thread/thread_bloc_test.dart`

**Interfaces:**
- Consumes: Dio/SSE, thread repository
- Produces:
  - `SseClient.stream(path, {lastEventId})` → `Stream<SseEvent>`
  - Thread events: `ThreadFollowUpSubmitted(text)`, `ThreadCancelRequested`, stream attachment on start when latest run non-terminal
  - Follow-up draft id `followup:<agentId>`
  - Disable send while latest run status is `CREATING` or `RUNNING`
  - Cancel calls `POST /v1/agents/{id}/runs/{runId}/cancel`
  - On `409 agent_busy` / `409 run_not_cancellable`: refresh, non-fatal messaging
  - On stream `410`: fall back to GET run polling every ~3s while active

- [ ] **Step 1: Write failing bloc tests for follow-up/cancel/disable rules**

- [ ] **Step 2: Implement SSE client**

Parse `event:` / `data:` / `id:` lines. Handle `assistant` deltas by appending to in-memory assistant buffer; `tool_call` → upsert compact tool step; `result`/`done` → refresh runs + stop stream.

Resume with `Last-Event-ID` header after disconnect.

- [ ] **Step 3: Implement follow-up + cancel in repository/bloc**

Follow-up body:

```json
{ "prompt": { "text": "..." } }
```

Clear follow-up draft only after success.

- [ ] **Step 4: Wire composer + cancel action in UI**

- [ ] **Step 5: Tests + commit**

```bash
flutter test test/features/thread
git add lib/core/network/sse_client.dart lib/features/thread test/features/thread
git commit -m "feat: stream runs, follow up, and cancel active agents"
```

---

### Task 10: Settings, polish, README, release APK

**Files:**
- Create/modify: `lib/features/settings/presentation/settings_page.dart`
- Modify: theme/motion polish on agents/thread/connect
- Modify: `README.md`
- Modify: `.gitignore` if needed for local secrets files

**Interfaces:**
- Consumes: `AuthSessionRepository`, DB
- Produces: Settings actions `signOut()`, `clearCache()`

- [ ] **Step 1: Settings page**

Show `apiKeyName`, `userEmail` if any. Buttons: Sign out; Clear local cache. Link to open agent on web uses agent `url` from detail/list.

- [ ] **Step 2: UI polish**

Add 2–3 intentional motions (e.g. agents list fade/slide, thread message insert animation, connect CTA press/loading). Ensure mobile layout works; no `StatefulWidget`.

- [ ] **Step 3: README**

Document:
- Flutter version expectation
- `flutter pub get`
- run with optional `--dart-define=CURSOR_API_KEY=...`
- how to create a key at Cursor Dashboard → API Keys
- `flutter build apk --release`
- package id `io.haxl.cursor`
- link to design spec

- [ ] **Step 4: Build release APK**

```bash
flutter build apk --release
```

Expected: `build/app/outputs/flutter-apk/app-release.apk` produced.

- [ ] **Step 5: Full light test suite**

```bash
flutter analyze
flutter test
```

Expected: clean analyze (or only pre-existing infos), all tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib README.md
git commit -m "feat: settings, UI polish, and release documentation"
```

---

## Spec coverage checklist

| Spec requirement | Task |
| --- | --- |
| Package `io.haxl.cursor`, Android only | 1 |
| flutter_bloc + flutter_hooks, no StatefulWidget | 1, 3, 5–10 |
| Public API only + base URL config | 2 |
| Guided connect + token paste + `/v1/me` | 3 |
| Secrets via secure storage / dart-define | 2, 3, 10 |
| Agents list cache SWR + offline reads | 4, 6 |
| Launch prompt/repo/ref/model + draft | 4, 7 |
| Thread conversation | 8 |
| SSE stream + poll fallback | 9 |
| Follow-up + cancel | 9 |
| Follow-up/launch drafts survive kill | 4, 7, 9 |
| Settings sign out / clear cache | 10 |
| Cursor-like dark UI + motion | 5, 10 |
| Light tests | 2–9 |
| Release APK + README | 10 |
| No push / no OAuth / no iOS / no images | honored by omission |

## Plan self-review notes

- No OAuth tasks (API-key guided connect only), matching the spec’s auth reality check.
- Repository endpoint rate limit called out in Task 7.
- Archive/delete agents intentionally omitted from v1 tasks.
- Image prompts omitted.
