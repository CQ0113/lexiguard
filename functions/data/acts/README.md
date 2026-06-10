# Law Corpus Act Files

Each `.txt` file in this directory is a structured excerpt from a Malaysian statute that gets embedded and stored in the `law_corpus` Firestore collection by `seedLawCorpus`.

## File format

```
SOURCE: <PDF/page URL from lom.agc.gov.my>
ACT: <Full act name>
ACT_NO: <Act number, e.g. Act 136>
LANGUAGE: English
RETRIEVED: YYYY-MM

## sXX — Section Title
<Section text — 2-4 sentences describing what the provision does.>

## sYY — Another Section Title
<Text...>

## sZZ — [TODO: Title]
[TODO: paste from https://lom.agc.gov.my/]
```

- Section delimiters must start with `## ` followed by the section identifier (e.g. `s10`, `s415`), an em-dash or hyphen surrounded by spaces, and the section title.
- Any section whose text contains `[TODO:` is skipped during seeding.
- Keep each section description to 2-4 sentences. The seed tool chunks at 800 chars with 100-char overlap, so very long sections will produce multiple chunks.

## Populating TODOs

1. Visit https://lom.agc.gov.my/ and locate the relevant Act PDF.
2. Copy the section text verbatim, or write a brief accurate description (2-4 sentences).
3. Replace the `## sXX — [TODO: Title]` line and `[TODO: paste ...]` body with real content.
4. Save the file, then call `seedLawCorpus` to embed and store the new chunks.

## Calling seedLawCorpus

The `seedLawCorpus` callable function requires the caller to have the `reviewer: true` custom claim (or be running against the local emulator).

### From the Functions emulator

```bash
# Start the emulator
npm --prefix functions run serve

# In another terminal, call via curl (emulator bypasses reviewer check):
curl -X POST http://127.0.0.1:5001/<project-id>/us-central1/seedLawCorpus \
  -H "Content-Type: application/json" \
  -d '{"data":{}}'
```

### From production (requires reviewer claim)

Use the Firebase Admin SDK or a trusted server environment to set the `reviewer: true` custom claim on your UID, then call `seedLawCorpus` from a Flutter client or a script using the Firebase Client SDK.

Re-running is always safe — chunks already present in `law_corpus` with a matching `contentHash` are skipped. The function returns `{ seeded, skipped, total, errors }`.
