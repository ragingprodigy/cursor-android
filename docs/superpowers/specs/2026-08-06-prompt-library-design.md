# Prompt library — Design

**Date:** 2026-08-06  
**Branch:** `cursor/prompt-library-50fd`  
**Status:** Approved for implementation

## Goals

1. Local reusable prompts with title, body, optional notes and tags.
2. Manage in Settings → Prompt library (list, search/filter, add, edit, delete).
3. Use from Launch and thread follow-up composers; selection **replaces** the draft.
4. Survive Clear local cache (and remain after sign-out cache wipe).

## Non-goals

- Cloud sync / team sharing.
- Templating placeholders (`{{vars}}`).
- “Save current draft” from composers (follow-up).

## Data

- Drift table `SavedPrompts`: `id`, `title`, `body`, `notes` (nullable), `tags` (comma-separated text), `createdAt`, `updatedAt`.
- Dedicated Dao + `PromptLibraryRepository`.
- Excluded from `clearLocalCache()`.

## UI

- Settings ListTile → `/settings/prompts`.
- Library page: search (title/tags/notes), list, FAB add, tap edit, delete with confirm.
- Edit page/sheet: title, body, notes, tags.
- Composers: library icon → modal bottom sheet picker → replace draft via existing change events.

## Testing

- Repository CRUD + query filter.
- Cache clear leaves prompts.
- Picker replace behavior covered at repository/bloc level where practical.
