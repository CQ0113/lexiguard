# LexiGuard

LexiGuard is a Flutter app focused on legal marketplace flows and lawyer verification.
This README is written for teammates, reviewers, and anyone who wants to run or maintain this project.

## What this repository includes

- Flutter UI flows for authentication and role-based screens.
- Firebase integration points with safe startup behavior.
- Local Firestore admin tooling for backup, cleanup, and reseeding test data.

## Current behavior

- The app can run even if Firebase is not fully configured.
- If placeholder Firebase values are detected, startup falls back to demo-safe behavior.
- After real Firebase configuration, auth and Firestore flows can be tested end to end.

## Key project files

- `lib/main.dart`: app startup and root widget.
- `lib/core/firebase/firebase_initializer.dart`: Firebase initialization and placeholder guard.
- `lib/firebase_options.dart`: generated FlutterFire config.
- `lib/services/firebase_auth_sync_service.dart`: auth/profile sync scaffolding.
- `tools/firestore_admin/manage_firestore.js`: Firestore admin utility.
- `tools/firestore_admin/seed_data.json`: baseline test seed data.

## Prerequisites

- Dart SDK `^3.10.4` (see `pubspec.yaml`).
- Flutter SDK compatible with the Dart version above.
- Node.js and npm (only required for Firestore admin scripts).

## Quick start (UI/demo run)

From the project root:

```bash
flutter pub get
flutter run -d chrome
```

If Firebase is not configured yet, the app should still launch in demo-safe mode.

## Firebase setup

Follow these steps once per environment.

### 1. Create or choose a Firebase project

In Firebase Console, enable at minimum:

- Authentication (Email/Password)
- Cloud Firestore

Enable Cloud Functions only if you plan to deploy backend callable functions.

### 2. Install FlutterFire CLI (one-time)

```bash
dart pub global activate flutterfire_cli
```

If `flutterfire` is not found, add pub cache to your PATH:

```bash
export PATH="$PATH:$HOME/.pub-cache/bin"
```

### 3. Generate Firebase options

Run from repository root:

```bash
flutterfire configure --project=<YOUR_FIREBASE_PROJECT_ID> --platforms=android,ios,macos,web
```

This updates `lib/firebase_options.dart` with real project values.

### 4. Platform file checks

After configuration, confirm these files are available for your Firebase project:

- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `macos/Runner/GoogleService-Info.plist`

For iOS dependency sync:

```bash
cd ios && pod install && cd ..
```

### 5. Verify setup

```bash
flutter pub get
flutter run -d chrome
```

## Firestore admin tool (safe data operations)

This repository includes a local Node-based admin tool in `tools/firestore_admin`.
It uses a service account file, so it does not depend on browser login state.

### One-time setup

1. In Firebase Console, open Project settings -> Service accounts.
2. Generate a private key JSON.
3. Save it as `tools/firestore_admin/service-account.json`.
4. Install dependencies:

```bash
npm --prefix tools/firestore_admin install
```

### Common commands

Fetch a specific user document:

```bash
node tools/firestore_admin/manage_firestore.js fetch-doc users <USER_ID>
```

Fetch directly from a Firebase Console URL:

```bash
node tools/firestore_admin/manage_firestore.js fetch-url "<FIREBASE_CONSOLE_DOCUMENT_URL>"
```

Create backup snapshot:

```bash
node tools/firestore_admin/manage_firestore.js backup
```

Flush and reseed baseline data:

```bash
node tools/firestore_admin/manage_firestore.js flush-and-seed --seed-file tools/firestore_admin/seed_data.json --yes
```

Flush only:

```bash
node tools/firestore_admin/manage_firestore.js flush --yes
```

### Notes

- Backups are written to `tools/firestore_admin/backups/`.
- A `fetch-doc` command returns exit code `2` when a document does not exist.
  This is expected for "verify deletion" checks.

## Testing

Run project tests:

```bash
flutter test
```
