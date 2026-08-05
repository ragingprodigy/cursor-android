# Flutter Cursor Android App — Design Spec

**Date:** 2026-08-05  
**Package:** `io.haxl.cursor`  
**Platform (v1):** Android only  
**Status:** Draft for review

## 1. Purpose

Build a Flutter Android app that provides full remote control of Cursor Cloud Agents from a phone: launch agents, monitor a conversation thread, send follow-ups, and cancel active runs — similar in spirit to the Cursor iOS app, but scoped to the **public Cloud Agents API**.

## 2. Goals & non-goals

### Goals (v1)

- Authenticate with a Cursor Cloud Agents API key (guided connect + raw token entry)
- List agents with stale-while-revalidate local cache
- Launch an agent with **prompt + repo + branch/ref + model**
- View a readable conversation thread for an agent (runs → user/assistant messages)
- Stream active run updates in-app (SSE), with polling fallback
- Send follow-up prompts on an existing agent
- Cancel an active run
- Persist unsent launch/follow-up drafts locally
- Show cached agents/threads when offline (reads); require network for mutations
- Cursor-like dark, dense product UI
- Install via `flutter run` and a sideloadable release APK
- Light automated tests around auth/API/bloc logic

### Non-goals (v1)

- iOS support / Play Store listing
- Push notifications
- True OAuth/SSO (public API is API-key only today)
- Multi-account switching
- Image prompts / multimodal launch
- Full desktop parity for diffs, file browsers, or rich tool UIs
- Offline mutation queue / sync engine
- Private/undocumented Cursor client APIs

## 3. Constraints & decisions

| Topic | Decision |
| --- | --- |
| State management | `flutter_bloc` for feature/app state |
| Widget local state | `flutter_hooks` / `HookWidget`; avoid `StatefulWidget` |
| Backend | Public Cloud Agents API (`https://api.cursor.com/v1`) only |
| Auth | API key via Bearer (or Basic); stored in secure storage |
| Secrets | Local config / `--dart-define` / runtime paste — never commit keys |
| Notifications | In-app only (poll/stream while open) |
| Account model | Single account |
| Repo selection | From `GET /v1/repositories` (account-connected) |
| Launch fields | Prompt, repo, branch/ref, model |
| Thread richness | Conversation thread + compact tool-call step lines |
| Offline | Read cache + drafts; no offline launch/follow-up/cancel completion |
| Architecture style | Feature-first client (Approach 1) |

### Auth reality check

The public Cloud Agents API authenticates with user or service-account API keys (Basic or Bearer). There is no documented public OAuth flow for a third-party mobile client.

Therefore v1 “Sign in” means:

1. Guided connect: open Cursor Dashboard API Keys page in a browser, user pastes key into the app
2. Advanced path: paste token directly
3. Validate with `GET /v1/me` before entering the app

True SSO remains a future enhancement if/when Cursor exposes it for this API.

## 4. Architecture

```
lib/
  app/           # bootstrap, theme, router, DI
  core/          # http, secure storage, local db, errors, config
  features/
    auth/        # connect API key, session, /v1/me
    agents/      # list/get agents (cache)
    launch/      # compose prompt + repo + ref + model
    thread/      # runs, conversation, follow-up, cancel, stream/poll
    settings/    # sign out, clear cache, about
```

### Layers (per feature)

- **data:** DTOs, remote data source, local cache/draft DAOs
- **domain:** thin models + repository interfaces (no heavy ceremony)
- **presentation:** `Bloc`/`Cubit` for feature state; `HookWidget` UI

### Cross-cutting

- Single authenticated HTTP client (Dio) attaching Bearer token
- `flutter_secure_storage` for the API key
- Drift for agents, runs/message snapshots, and drafts
- `go_router` for navigation: Connect ↔ Agents ↔ Launch ↔ Thread ↔ Settings
- Config: default base URL `https://api.cursor.com`; overridable via dart-define for tests

## 5. Screens & flows

### Screens

1. **Connect** — guided API key connect + advanced paste; validate `/v1/me`
2. **Agents** (home) — cached agent list, pull-to-refresh, CTA “New agent”
3. **Launch** — prompt, repo picker, branch/ref, model picker; local draft
4. **Thread** — agent header, conversation, follow-up composer, cancel
5. **Settings** — identity from `/v1/me`, sign out, clear cache

### Primary flows

```
Cold start → has valid key? → Agents : Connect
Launch → POST /v1/agents → Thread(agentId)
Thread open → GET agent + runs → stream active run (else poll)
Follow-up → POST /v1/agents/{id}/runs (draft cleared on success)
Cancel → POST /v1/agents/{id}/runs/{runId}/cancel
Offline → show cache; disable mutations; keep drafts
```

## 6. API mapping

| Capability | Endpoint |
| --- | --- |
| Validate key / identity | `GET /v1/me` |
| List repos | `GET /v1/repositories` |
| List models | `GET /v1/models` |
| Create agent + first run | `POST /v1/agents` |
| List agents | `GET /v1/agents` |
| Get agent | `GET /v1/agents/{id}` |
| List runs | `GET /v1/agents/{id}/runs` |
| Get run | `GET /v1/agents/{id}/runs/{runId}` |
| Stream run | `GET /v1/agents/{id}/runs/{runId}/stream` (SSE) |
| Follow-up | `POST /v1/agents/{id}/runs` |
| Cancel run | `POST /v1/agents/{id}/runs/{runId}/cancel` |

### Launch payload (v1)

```json
{
  "prompt": { "text": "..." },
  "model": { "id": "<from /v1/models>" },
  "repos": [
    {
      "url": "https://github.com/org/repo",
      "startingRef": "main"
    }
  ]
}
```

`model` may be omitted to use account defaults. Branch/ref maps to `repos[0].startingRef`.

### Thread model

- Each **run** contributes: user prompt text + assistant output (final `result.text` and/or streamed `assistant` deltas)
- Active run: prefer SSE events `status`, `assistant`, `tool_call`, `result`, `done`
- Tool calls render as compact step lines (`name` + `status`), not full args/result dumps
- Thinking deltas are omitted or collapsed by default in v1 (assistant text + tool steps are primary)
- On SSE failure: resume with `Last-Event-ID` when available; on `410 stream_expired`, fall back to `GET` run

## 7. Local persistence

| Store | Contents |
| --- | --- |
| Secure storage | API key |
| Drift | Agents list, per-agent run/message snapshots, launch draft, follow-up drafts |
| Optional dart-define | `CURSOR_API_KEY` for local/dev convenience (not a substitute for secure storage in normal use) |

### Draft rules

- Autosave launch and follow-up composer text
- Clear a draft only after the corresponding API create succeeds
- Drafts survive process death

### Cache rules

- Stale-while-revalidate on Agents (and Thread when revisiting)
- Offline reads show last-good data with a stale/offline indicator
- Cache miss + offline → empty state with offline messaging (do not fabricate data)
- Sign out clears the key; user can also clear local cache

## 8. Error handling

| Case | Behavior |
| --- | --- |
| `401` | Clear session; return to Connect with “key rejected” |
| Invalid key format | Client-side validation before network |
| Offline mutation | Keep draft; show retryable error; do not pretend success |
| `429` | Exponential backoff; show “rate limited, retrying…” |
| API `4xx` with message | Surface server message when present |
| `5xx` / timeout | Retryable generic error; preserve cache |
| SSE disconnect | Resume via `Last-Event-ID` or clean reconnect |
| `410 stream_expired` | Stop streaming; `GET` run for terminal state |
| Cancel `409 run_not_cancellable` | Refresh; non-fatal |
| Follow-up while run active | Disable send while latest run is non-terminal; refresh if status unclear |

## 9. UI direction

- Dark, dense, Cursor-inspired product UI (not a pixel clone of Cursor; not default Material look-and-feel)
- Expressive typography via a deliberate font choice (not Inter/Roboto/system default stacks)
- Atmosphere via subtle gradients/texture consistent with a dark IDE-adjacent feel — avoid purple-glow AI clichés
- First home viewport: brand/product signal + agent list as the primary job (not a marketing landing page)
- Motion: restrained transitions for list → thread → stream updates (2–3 intentional motions)

## 10. Intended packages

- `flutter_bloc`, `equatable`
- `flutter_hooks`
- `dio` (+ SSE helper as needed)
- `go_router`
- `flutter_secure_storage`
- `drift`, `drift_flutter`, `sqlite3_flutter_libs`
- `url_launcher`
- `bloc_test`, `mocktail` (dev)

Exact versions pinned at project creation from current stable-compatible resolvable set.

## 11. Testing strategy (light)

- Unit: DTO parsing, session/auth rules, draft persistence rules
- Bloc: connect success/failure; launch submit; thread follow-up/cancel transitions
- Manual on emulator/device: connect → list → launch → stream → follow-up → cancel → offline cache/draft
- No integration-test suite in v1

## 12. Delivery

- Flutter project with Android applicationId / package `io.haxl.cursor`
- Debug via `flutter run`
- Release APK for sideload
- README: setup, dart-define/secrets, run/build instructions

## 13. Open questions (resolved for v1)

| Question | Resolution |
| --- | --- |
| Job of v1 | Full remote control (launch, monitor, follow-up, cancel) |
| Auth | Guided key connect + token entry (OAuth later) |
| Backend | Public Cloud Agents API only |
| Platform | Android only |
| Launch fields | Prompt, repo, branch/ref, model |
| Notifications | In-app only |
| Thread richness | Conversation thread |
| Repo source | Account-connected repositories API |
| Accounts | Single |
| Offline | Cache + drafts |
| Visual | Cursor-like dark |
| Distribution | flutter run + release APK |
| Tests | Light |
| Credentials | Local config/env; never commit |

## 14. Success criteria

v1 is done when a developer can:

1. Connect a Cursor API key on Android
2. See their Cloud Agents list (including from cache offline)
3. Launch an agent with prompt/repo/ref/model
4. Watch the thread update while a run is active
5. Send a follow-up and cancel a run
6. Recover unsent drafts after killing the app
7. Build a release APK and install it on a device
