# UX polish: navigation, markdown, prompts, grouping

**Date:** 2026-08-06  
**PR:** #2 (`cursor/flutter-cursor-android-plan-50fd`)  
**Status:** Approved for implementation

## Goals

1. Fix Settings back navigation (back returns to Agents, not exit app).
2. Silence Java 8 obsolete compile warnings by forcing Java/Kotlin 17 for Android subprojects.
3. Render assistant + live stream content with `gpt_markdown`.
4. Best-effort hydrate user prompts via legacy `GET /v0/agents/{id}/conversation`, fallback to local store.
5. Agents list menu: Flat / By repository / By status (persisted).

## Non-goals

- Mass dependency upgrades for pub “newer versions available” noise.
- Font bundling, full pagination (still deferred).

## Navigation

- Use `context.push` for Settings and New agent from Agents.
- Settings AppBar leading / system back: `pop` when possible, else `go('/agents')`.
- Opening a thread may keep `go` or use `push`; prefer `push` so back from thread returns to list.

## Markdown

- Package: `gpt_markdown`.
- Apply to `AssistantMessage` bubbles and live streaming assistant overlay.
- User bubbles and tool-step lines remain plain text.
- Theme styles for dark Cursor UI.

## Prompts

- On thread load, best-effort `GET /v0/agents/{id}/conversation`.
- Merge `user_message` texts into display / `RunPromptStore` when mappable.
- Preference order: conversation API → local store → “(Prompt unavailable on this device)”.
- Soft-fail on 404/4xx from v0; keep v1 runs/results path.

## Grouping

- App-bar menu: Flat | By repository | By status.
- Persist with `shared_preferences`.
- Enrich agent repo via cached `GET /v1/agents/{id}` (concurrent, non-blocking first paint).
- By repo: `owner/repo` sections; “No repository” last.
- By status: Active / Finished / Archived / Other.

## Testing

- Router/navigation: settings push/pop (widget or manual).
- Conversation merge unit test.
- Grouping helper unit tests.
- Existing suite must stay green.
