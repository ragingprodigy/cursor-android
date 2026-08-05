# Cursor Android

Flutter Android app for remotely controlling Cursor Cloud Agents from a phone.
The app supports API-key connection, cached agent and thread views, launching
agents, follow-ups, cancel, settings, and a sideloadable release APK.

## Requirements

- Flutter stable `3.44.8` or newer compatible with Dart `3.12.2`
- Android SDK configured for Flutter
- A Cursor Cloud Agents API key

The Android package/application ID is:

```text
io.haxl.cursor
```

Design reference: [`docs/superpowers/specs/2026-08-05-flutter-cursor-android-design.md`](docs/superpowers/specs/2026-08-05-flutter-cursor-android-design.md)

## Create a Cursor API key

1. Open Cursor Dashboard -> API Keys:
   <https://cursor.com/dashboard/api>
2. Create a new API key.
3. Copy the key and paste it into the app's Connect screen.

For local development, you can also bootstrap the key at launch with
`--dart-define=CURSOR_API_KEY=...`. The key is used to call `/v1/me`, then
stored with Flutter secure storage after a successful connection.

## Setup

```bash
flutter pub get
```

Run on an Android device or emulator:

```bash
flutter run
```

Optional API key bootstrap:

```bash
flutter run --dart-define=CURSOR_API_KEY=your_cursor_api_key
```

Optional API base override:

```bash
flutter run --dart-define=CURSOR_API_BASE_URL=https://api.cursor.com
```

## Build a release APK

```bash
flutter build apk --release
```

Expected local artifact:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Do not commit the APK; `/build/` is ignored by git.

## Verification

```bash
flutter analyze
flutter test
```

## Structure

- `lib/app/` - app shell, dependency wiring, routing, and theme
- `lib/core/` - shared config, network, storage, database, and error handling
- `lib/features/` - auth, agents, launch, thread, and settings feature modules
