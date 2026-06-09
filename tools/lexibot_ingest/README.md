# LexiBot Source Ingestion Tool

This admin-only tool creates the persistent Gemini File Search store and
indexes reviewed Malaysian residential tenancy source PDFs once. It is not
used by the Flutter client.

## Setup

The root ignored `.env` must contain:

```dotenv
GEMINI_API_KEY=YOUR_REAL_GEMINI_API_KEY
LEXIBOT_FILE_SEARCH_STORE_DISPLAY_NAME=lexiguard-tenancy-law-store
LEXIBOT_RAG_MODEL=gemini-3.5-flash
```

Install dependencies:

```bash
npm --prefix tools/lexibot_ingest install
```

## Create Or Reuse The Store

```bash
npm --prefix tools/lexibot_ingest run store:create
```

The returned resource name is recorded in ignored
`tools/lexibot_ingest/.lexibot.local.json`. Copy that resource name into the
Firestore document `lexibot_config/tenancy_mvp` when backend configuration is
created.

## Prepare Approved PDFs

1. Copy `manifest.example.json` to ignored `manifest.json`.
2. Put reviewed PDFs in ignored `source_pdfs/`.
3. Complete the source URL, version ID, and SHA-256 hash for each source.
4. Change only reviewed source entries to:

```json
{
  "reviewStatus": "approved",
  "status": "active"
}
```

Calculate a PDF hash in PowerShell:

```powershell
(Get-FileHash -Algorithm SHA256 tools/lexibot_ingest/source_pdfs/your_file.pdf).Hash.ToLower()
```

## Index Approved Sources

```bash
npm --prefix tools/lexibot_ingest run source:ingest
```

The script uploads each approved PDF directly into the persistent File Search
store and refuses unapproved sources or PDF hash mismatches. Indexed documents
include source metadata for later citation mapping.

## Verify Retrieval

After indexing at least one approved source:

```bash
npm --prefix tools/lexibot_ingest run store:verify -- "What does the approved source say about unpaid rent?"
```

The command prints a response only when grounding chunks were supplied. If the
model generates text without retrieved evidence, the tool discards it and
fails its retrieval check. The future `askLexiBot` callable must enforce the
same rule.
