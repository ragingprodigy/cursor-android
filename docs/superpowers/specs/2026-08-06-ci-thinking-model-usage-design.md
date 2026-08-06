# CI, composer, thinking, model, usage — Design

**Date:** 2026-08-06  
**Branch:** `cursor/ci-thinking-model-usage-50fd`  
**Status:** Approved for implementation

## Goals

1. GitHub Actions CI: `flutter analyze`, `flutter test`, `flutter build apk --debug`.
2. Follow-up composer: Enter inserts newline; send only via Send button.
3. Show agent thinking (SSE `thinking`) as collapsed-by-default expandable rows.
4. Thread model picker for next follow-up; clear error if API rejects `model` on create-run.
5. Usage: per-agent token usage in thread + Settings → Usage screen with date range (Admin API when available).

## Non-goals

- Changing billing/spend limits via API.
- Push notifications.
- Full enterprise Admin dashboard parity.

## CI

- `.github/workflows/ci.yml` on `push`/`pull_request` to `main`.
- `ubuntu-latest`, Flutter stable, Android SDK as needed for debug APK.
- Steps: checkout → setup Flutter → `pub get` → analyze → test → `build apk --debug`.

## Composer

- `TextInputAction.newline`; no `onSubmitted` send.
- Send button only.

## Thinking

- Handle SSE `thinking` deltas; accumulate live buffer.
- UI: collapsed “Thinking” expansion tile; expand to read text.
- Include in `displayMessages` as a distinct message type or live overlay row.
- Persist finished thinking locally when feasible for the current run.

## Model (follow-up)

- Model dropdown near composer (catalog from `GET /v1/models` + Default).
- Persist selection per agent locally.
- On follow-up submit, send `model: { id }` when not Default.
- On 400 unsupported: surface error; user can clear override / resend without model.

## Usage

### Thread
- `GET /v1/agents/{id}/usage` → total + per-run token summary.

### Usage screen
- Entry from Settings.
- Date presets 7d / 30d / custom (≤30 days for Admin calls).
- Try Admin: `POST /teams/spend`, `POST /teams/filtered-usage-events`.
- On 401/403: explain Admin key required; fall back to best-effort agent token aggregates where possible.
- Soft-fail everywhere.

## Testing

- CI workflow validates analyze/test/apk.
- Unit/bloc tests for thinking message accumulation, model payload, usage parsing.
- Composer newline is manual/widget-light.
