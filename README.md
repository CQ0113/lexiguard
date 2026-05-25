# LexiGuard

LexiGuard is a Flutter app focused on legal marketplace flows and lawyer verification.
This README is written for teammates, reviewers, and anyone who wants to run or maintain this project.

## What this repository includes

- Flutter UI flows for authentication and role-based screens.
- Firebase integration points with safe startup behavior.
- Gemini 2.5 Flash REST client groundwork for upcoming AI flows.
- Local Firestore admin tooling for backup, cleanup, and reseeding test data.

## Current behavior

- The app can run even if Firebase is not fully configured.
- If placeholder Firebase values are detected, startup falls back to demo-safe behavior.
- After real Firebase configuration, auth and Firestore flows can be tested end to end.

## Key project files

- `lib/main.dart`: app startup and root widget.
- `lib/core/firebase/firebase_initializer.dart`: Firebase initialization and placeholder guard.
- `lib/core/ai/gemini_config.dart`: Gemini configuration loaded from `.env`.
- `lib/services/gemini_service.dart`: Gemini 2.5 Flash text generation client.
- `lib/firebase_options.dart`: generated FlutterFire config.
- `lib/services/firebase_auth_sync_service.dart`: auth/profile sync scaffolding.
- `lib/repositories/verification_review_repository.dart`: manual review queue writes.
- `functions/src/index.js`: callable verification scaffold entry points.
- `functions/src/verification/malaysian_bar_adapter.js`: live Malaysian Bar lookup adapter.
- `functions/src/verification/verification_decision.js`: scoring and decision rules.
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

## Gemini 2.5 Flash setup

The connection layer is ready for future AI screens through
`lib/services/gemini_service.dart`. It uses the Gemini REST
`generateContent` endpoint and defaults to `gemini-2.5-flash`.

1. Create a Gemini API key in Google AI Studio.
2. Add the key to the ignored local `.env` file:

```dotenv
GEMINI_API_KEY=YOUR_REAL_GEMINI_API_KEY
GEMINI_MODEL=gemini-2.5-flash
GEMINI_API_BASE_URL=https://generativelanguage.googleapis.com/v1beta
```

3. Call the connection check from the feature being developed:

```dart
import 'package:lei_guard/services/gemini_service.dart';

final gemini = GeminiService();
final reply = await gemini.testConnection();
gemini.close();
```

`testConnection()` makes a real billable/API-quota request only when it is
called; app startup does not call Gemini.

Important: this direct setup is for local development only. Flutter includes
`.env` in the built app assets, so a Gemini API key placed there can be
extracted from a web or mobile build. Before release, route Gemini requests
through a trusted backend such as Firebase Cloud Functions and store the key
with backend secret management.

Reference: [Gemini text generation documentation](https://ai.google.dev/gemini-api/docs/text-generation).

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

### 6. Cloud Functions scaffold (verification adapters)

This repository includes a starter backend scaffold in `functions/`:

- `startVerification` callable function
- `reviewVerificationRequest` callable function
- adapter/decision modules under `functions/src/verification/`

Current adapter behavior:

- Peninsular requests call Malaysian Bar live lookup endpoint.
- East Malaysia requests route to manual review by design.
- Decision logic applies weighted matching (name/firm/state) and status checks.

Install dependencies:

```bash
npm --prefix functions install
```

Run local emulator:

```bash
npm --prefix functions run serve
```

Deploy functions:

```bash
npm --prefix functions install
firebase deploy --only functions
```

### 7. Firestore rules and indexes for verification queue

This repository includes:

- `firestore.rules`
- `firestore.indexes.json`

Deploy them with:

```bash
firebase deploy --only firestore:rules,firestore:indexes
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

## Verification queue collections

Current verification flow writes to these Firestore collections:

- `users`
- `lawyer_profiles`
- `verification_requests`

## Reviewer console (demo)

- In the lawyer Verification Center tab, use `Open Reviewer Console (Demo)`.
- The screen streams queued documents from `verification_requests`.
- Approve/Reject actions call `reviewVerificationRequest` Cloud Function.
- In production, review actions require a Firebase Auth custom claim: `reviewer: true`.
- In local emulator mode, claim enforcement is relaxed for faster testing.

## Testing

Run project tests:

```bash
flutter test
```
