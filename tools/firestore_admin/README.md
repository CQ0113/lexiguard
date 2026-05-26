# Firestore Admin & Demo Tools

Workspace-local CLIs for inspecting Firestore and provisioning demo accounts. These talk to the real Firebase project via a service-account key — they do **not** use the emulator.

## One-time setup

1. Download a service account key:
   Firebase Console → Project settings → Service accounts → Generate new private key.
2. Save it as `tools/firestore_admin/service-account.json` (gitignored), or set `FIREBASE_SERVICE_ACCOUNT_PATH` to its location.
3. Install deps:
   ```bash
   cd tools/firestore_admin
   npm install
   ```

## Demo accounts

Three demo accounts are defined in `demo_accounts.json`:

| Key                 | Email                                   | Role     | Outcome                              |
| ------------------- | --------------------------------------- | -------- | ------------------------------------ |
| `lawyer_peninsular` | `demo.lawyer.peninsular@lexiguard.dev`  | lawyer   | Pre-verified (`auto_verified`)       |
| `lawyer_sabah`      | `demo.lawyer.sabah@lexiguard.dev`       | lawyer   | Queued for manual review (Sabah)     |
| `reviewer`          | `demo.reviewer@lexiguard.dev`           | client   | `{reviewer: true}` custom claim      |

Default password for all three: `LexiDemo!2026` (override via env vars `LEXIGUARD_DEMO_PASSWORD_LAWYER_PENINSULAR`, `_LAWYER_SABAH`, `_REVIEWER`).

### Commands

```bash
npm run demo:setup       # idempotent — create or refresh the three accounts
npm run demo:teardown    # delete all three accounts (Auth + Firestore docs)
npm run demo:reviewer -- demo.reviewer@lexiguard.dev   # grant reviewer claim
```

After `demo:setup`, the reviewer account must sign out and back in inside the Flutter app before the `{reviewer: true}` claim is visible — custom claims propagate on the next ID-token refresh.

### Live auto-verify demo flow

The seed script writes a static `auto_verified` profile so the verified-state UI demo always works offline. To demonstrate the live Malaysian Bar API hit, register a fresh account during the demo with a Bar member's name you confirmed in advance scores ≥ 0.85 against the directory:

1. Open the app, choose Register → Lawyer.
2. Fill jurisdiction `peninsular`, plus the legal name + state of the researched Bar member.
3. Submit. The Cloud Function will hit `legaldirectory.malaysianbar.org.my` and resolve to `auto_verified` if the match passes.
4. After the demo, run `node seed_demo_users.js teardown --yes` to remove the throwaway account (or delete via the Firebase console).

Sabah / Sarawak jurisdictions always route to `manual_review_required` — no API call is made.

## General Firestore admin (`manage_firestore.js`)

Inspect or reset Firestore data outside the demo accounts:

```bash
npm run fetch:user -- <uid>
npm run fetch:doc -- <collection> <docId>
npm run backup
npm run seed
npm run flush-and-seed     # destructive — wipes users + lawyer_profiles, then seeds from seed_data.json
```

## LexiBot metadata setup

The LexiBot seed command uses the ignored source manifest and Gemini File
Search store receipt from `../lexibot_ingest/`. It creates:

- `lexibot_config/tenancy_mvp`
- `legal_sources/{sourceId}`
- `legal_sources/{sourceId}/versions/{versionId}`

It stores downloaded legal sources as `pending` / `inactive` only. It does not
approve documents and does not index them into Gemini File Search.

```bash
npm run lexibot:seed-pending
npm run lexibot:verify
```

The command is idempotent and skips an existing version record, so re-running
it cannot downgrade a later approved version back to pending.
