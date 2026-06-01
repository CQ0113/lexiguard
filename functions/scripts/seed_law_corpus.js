/**
 * seed_law_corpus.js — Populates the Firestore law_corpus collection with
 * pre-embedded Malaysian statute chunks for LexiBot RAG.
 *
 * Usage (from repo root):
 *   cd functions
 *   GEMINI_API_KEY=<your-key> node scripts/seed_law_corpus.js
 *
 * Firestore auth: uses `gcloud auth print-access-token` (the active gcloud
 * account) via the Firestore REST API — no Admin SDK credentials needed.
 * Make sure `gcloud` is logged in with an account that has project access.
 */

"use strict";

require("dotenv").config({ path: require("path").join(__dirname, "../.env") });

const { execSync } = require("child_process");
const { GoogleGenAI } = require("@google/genai");

// ---------------------------------------------------------------------------
// Env validation
// ---------------------------------------------------------------------------
const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
const GEMINI_EMBED_MODEL = process.env.GEMINI_EMBED_MODEL || "gemini-embedding-001";

if (!GEMINI_API_KEY) {
  console.error([
    "ERROR: GEMINI_API_KEY is not set.",
    "",
    "GEMINI_API_KEY is stored as a Firebase secret (not in .env).",
    "Run the seed script like this:",
    "",
    "  cd functions",
    "  GEMINI_API_KEY=$(firebase functions:secrets:access GEMINI_API_KEY) node scripts/seed_law_corpus.js",
    "",
    "Or export it first:",
    "  export GEMINI_API_KEY=$(firebase functions:secrets:access GEMINI_API_KEY)",
    "  node scripts/seed_law_corpus.js",
  ].join("\n"));
  process.exit(1);
}

// ---------------------------------------------------------------------------
// Firestore REST API helpers — use gcloud access token (service account)
// ---------------------------------------------------------------------------
const PROJECT = "lexiguard-32c63";
const FS_BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;

function getGcloudToken() {
  return execSync("gcloud auth print-access-token", { encoding: "utf8" }).trim();
}

async function firestoreGet(collection, docId, token) {
  const res = await fetch(`${FS_BASE}/${collection}/${docId}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (res.status === 404) return null;
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`Firestore GET ${collection}/${docId} failed ${res.status}: ${body}`);
  }
  return res.json();
}

async function firestoreSet(collection, docId, fields, token) {
  // Build Firestore document format
  const document = { fields: {} };
  for (const [k, v] of Object.entries(fields)) {
    if (typeof v === "string") document.fields[k] = { stringValue: v };
    else if (typeof v === "number") document.fields[k] = { doubleValue: v };
    else if (typeof v === "boolean") document.fields[k] = { booleanValue: v };
    else if (Array.isArray(v)) {
      document.fields[k] = {
        arrayValue: {
          values: v.map((x) =>
            typeof x === "number" ? { doubleValue: x } : { stringValue: String(x) }
          ),
        },
      };
    }
  }

  const url = `${FS_BASE}/${collection}/${docId}`;
  const res = await fetch(url, {
    method: "PATCH",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(document),
  });
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`Firestore PATCH ${collection}/${docId} failed ${res.status}: ${body}`);
  }
  return res.json();
}

// ---------------------------------------------------------------------------
// Statute chunks — ~20 sections covering property, contract, tenancy,
// employment, and family law relevant to the app's case categories.
// Source: lom.agc.gov.my (Federal Legislation Portal)
// ---------------------------------------------------------------------------
const STATUTE_CHUNKS = [
  // ── Contracts Act 1950 (Act 136) ─────────────────────────────────────────
  {
    actName: "Contracts Act 1950",
    actNo: "Act 136",
    sectionNo: "s. 2",
    sectionTitle: "Interpretation",
    chunkText:
      "In this Act — 'proposal' means when one person signifies to another his willingness to do or to abstain from doing anything, with a view to obtaining the assent of that other to such act or abstinence. 'promise' is when the person to whom the proposal is made signifies his assent thereto. 'promisor' and 'promisee' — the person making the proposal is called the promisor, and the person accepting the proposal is called the promisee. 'consideration' — when, at the desire of the promisor, the promisee or any other person has done or abstained from doing, or does or abstains from doing, or promises to do or to abstain from doing, something, such act or abstinence or promise is called a consideration for the promise.",
    sourceUrl:
      "https://lom.agc.gov.my/ilims/upload/portal/akta/outputp/act_136/Act%20136.pdf",
  },
  {
    actName: "Contracts Act 1950",
    actNo: "Act 136",
    sectionNo: "s. 10",
    sectionTitle: "What agreements are contracts",
    chunkText:
      "All agreements are contracts if they are made by the free consent of parties competent to contract, for a lawful consideration and with a lawful object, and are not hereby expressly declared to be void. Nothing herein contained shall affect any law in force in Malaysia and not hereby expressly repealed, by which any contract is required to be made in writing or in the presence of witnesses, or any law relating to the registration of documents.",
    sourceUrl:
      "https://lom.agc.gov.my/ilims/upload/portal/akta/outputp/act_136/Act%20136.pdf",
  },
  {
    actName: "Contracts Act 1950",
    actNo: "Act 136",
    sectionNo: "s. 14",
    sectionTitle: "Free consent defined",
    chunkText:
      "Consent is said to be free when it is not caused by coercion as defined in section 15, or undue influence as defined in section 16, or fraud as defined in section 17, or misrepresentation as defined in section 18, or mistake subject to sections 21, 22, and 23. Consent is said to be so caused when it would not have been given but for the existence of such coercion, undue influence, fraud, misrepresentation, or mistake.",
    sourceUrl:
      "https://lom.agc.gov.my/ilims/upload/portal/akta/outputp/act_136/Act%20136.pdf",
  },
  {
    actName: "Contracts Act 1950",
    actNo: "Act 136",
    sectionNo: "s. 40",
    sectionTitle: "Effect of refusal to accept offer of performance",
    chunkText:
      "If a party to a contract has refused to perform, or disabled himself from performing, his promise in its entirety, the promisee may put an end to the contract, unless he has signified, by words or conduct, his acquiescence in its continuance.",
    sourceUrl:
      "https://lom.agc.gov.my/ilims/upload/portal/akta/outputp/act_136/Act%20136.pdf",
  },
  {
    actName: "Contracts Act 1950",
    actNo: "Act 136",
    sectionNo: "s. 74",
    sectionTitle: "Compensation for loss or damage caused by breach",
    chunkText:
      "When a contract has been broken, the party who suffers by the breach is entitled to receive, from the party who has broken it, compensation for any loss or damage caused to him thereby, which naturally arose in the usual course of things from the breach, or which the parties knew, when they made the contract, to be likely to result from the breach of it. Such compensation is not to be given for any remote and indirect loss or damage sustained by reason of the breach.",
    sourceUrl:
      "https://lom.agc.gov.my/ilims/upload/portal/akta/outputp/act_136/Act%20136.pdf",
  },

  // ── Specific Relief Act 1950 (Act 137) ───────────────────────────────────
  {
    actName: "Specific Relief Act 1950",
    actNo: "Act 137",
    sectionNo: "s. 11",
    sectionTitle: "Cases in which specific performance enforceable",
    chunkText:
      "Specific performance of a contract may, in the discretion of the court, be enforced: (a) when the act agreed to be done is in the performance, wholly or partly, of a trust; (b) when there exists no standard for ascertaining the actual damage caused by the non-performance of the act agreed to be done; (c) when the act agreed to be done is such that pecuniary compensation for its non-performance would not afford adequate relief. Explanation — Unless and until the contrary is proved, it shall be presumed that the breach of a contract to transfer immovable property cannot be adequately relieved by compensation in money.",
    sourceUrl:
      "https://lom.agc.gov.my/ilims/upload/portal/akta/outputp/act_137/Act%20137.pdf",
  },
  {
    actName: "Specific Relief Act 1950",
    actNo: "Act 137",
    sectionNo: "s. 24",
    sectionTitle: "Injunctions to perform negative agreements",
    chunkText:
      "Notwithstanding that the court is unable to compel specific performance of the whole of a contract, where a party to a contract has done an act in breach of a negative term of the contract, the court may, in its discretion, by injunction restrain him from doing any further act in breach of that negative term.",
    sourceUrl:
      "https://lom.agc.gov.my/ilims/upload/portal/akta/outputp/act_137/Act%20137.pdf",
  },

  // ── National Land Code 1965 (Act 56) ─────────────────────────────────────
  {
    actName: "National Land Code 1965",
    actNo: "Act 56",
    sectionNo: "s. 5",
    sectionTitle: "Interpretation — dealings, interest",
    chunkText:
      "In this Act, unless the context otherwise requires — 'dealings' means any transaction with respect to alienated land effected under the powers conferred by this Act, and includes any such transaction effected under any previous land law; 'interest' means any interest in or over land, whether as proprietor, lessee, chargee, or otherwise, and includes any claim, or entitlement to claim, any right over land; 'lease' means a lease granted under Part Fifteen; 'charge' means a charge created under Chapter 1 of Part Sixteen.",
    sourceUrl:
      "https://lom.agc.gov.my/ilims/upload/portal/akta/outputp/act_56/Act%2056.pdf",
  },
  {
    actName: "National Land Code 1965",
    actNo: "Act 56",
    sectionNo: "s. 206",
    sectionTitle: "Effect of charge",
    chunkText:
      "A charge — (a) shall confer upon the chargee the right to apply to the court for an order for sale of the charged land, or the share or interest charged, as the case may be, whenever the chargor fails to meet his obligations thereunder; (b) shall not operate as a transfer of the charged land or any share or interest therein to the chargee; and (c) shall not entitle the chargee to the receipt of rent or profits from the charged land, save in so far as he may have been expressly empowered so to do by the instrument of charge.",
    sourceUrl:
      "https://lom.agc.gov.my/ilims/upload/portal/akta/outputp/act_56/Act%2056.pdf",
  },
  {
    actName: "National Land Code 1965",
    actNo: "Act 56",
    sectionNo: "s. 221",
    sectionTitle: "Order for sale by court",
    chunkText:
      "Where a chargor has failed to comply with the terms of a notice served on him under section 218, and the charge has not been set aside or discharged by order of the court, the chargee may apply to the court for an order for sale of the charged land, or of the share or interest charged, as the case may be. Upon any such application the court shall, unless it sees fit to make an order staying the proceedings or otherwise dealing with the matter, make an order for sale of the land or of the share or interest, as the case may be, in such manner as it thinks fit.",
    sourceUrl:
      "https://lom.agc.gov.my/ilims/upload/portal/akta/outputp/act_56/Act%2056.pdf",
  },
  {
    actName: "National Land Code 1965",
    actNo: "Act 56",
    sectionNo: "s. 241",
    sectionTitle: "Lessee's implied covenants",
    chunkText:
      "In every lease there shall be implied, on the part of the lessee, covenants — (a) to pay the rent thereby reserved at the time and in the manner specified in the lease; (b) to pay all rates, taxes, assessments, impositions and outgoings which may be charged on the lease or the land demised, or on the lessee in respect thereof; (c) not to use or permit the land demised to be used for any unlawful purpose; (d) to keep the land demised and all buildings and structures thereon in repair; and (e) to permit the lessor and his agents at reasonable times to enter and inspect the land demised and the buildings and structures thereon.",
    sourceUrl:
      "https://lom.agc.gov.my/ilims/upload/portal/akta/outputp/act_56/Act%2056.pdf",
  },

  // ── Landlord and Tenant (Shops) Act 1952 (Act 241) ───────────────────────
  {
    actName: "Landlord and Tenant (Shops) Act 1952",
    actNo: "Act 241",
    sectionNo: "s. 4",
    sectionTitle: "Security of tenure",
    chunkText:
      "Where a tenancy of a shop is subsisting at the date of commencement of this Act, or where a tenancy of a shop is created after the date of commencement of this Act, then, notwithstanding anything contained in any written law or in the agreement creating the tenancy, the tenancy shall not be determined or affected by any notice to quit, or by any ejectment, or by the effluxion of time, or by any other means, unless and until a Tribunal, upon an application made to it, has made an order directing the tenant to surrender the shop to the landlord. Provided that this section shall not apply in any case in which the landlord has obtained a possession order from the court for breach of covenant.",
    sourceUrl:
      "https://lom.agc.gov.my/ilims/upload/portal/akta/outputp/act_241/Act%20241.pdf",
  },

  // ── Employment Act 1955 (Act 265) ─────────────────────────────────────────
  {
    actName: "Employment Act 1955",
    actNo: "Act 265",
    sectionNo: "s. 12",
    sectionTitle: "Termination of contract",
    chunkText:
      "Either party to a contract of service may at any time give to the other party notice of his intention to terminate such contract of service. The length of such notice shall be the same for both employer and employee and shall be determined by any provision made for the notice in the terms of the contract of service, or, in the absence of any such provision, shall not be less than — (a) four weeks' notice if the employee has been employed for less than two years; (b) six weeks' notice if he has been employed for two years or more but less than five years on the date on which the notice is given; (c) eight weeks' notice if he has been employed for five years or more on such date.",
    sourceUrl:
      "https://lom.agc.gov.my/ilims/upload/portal/akta/outputp/act_265/Act%20265.pdf",
  },
  {
    actName: "Employment Act 1955",
    actNo: "Act 265",
    sectionNo: "s. 13",
    sectionTitle: "Termination without notice",
    chunkText:
      "Either party to a contract of service may terminate such contract of service without notice or, if notice has already been given in accordance with section 12, without waiting for the expiry of that notice, by paying to the other party an indemnity of a sum equal to the amount of wages which would have accrued to the employee during the term of such notice or during the unexpired term of such notice, as the case may be.",
    sourceUrl:
      "https://lom.agc.gov.my/ilims/upload/portal/akta/outputp/act_265/Act%20265.pdf",
  },
  {
    actName: "Employment Act 1955",
    actNo: "Act 265",
    sectionNo: "s. 60AA",
    sectionTitle: "Hours of work",
    chunkText:
      "An employee shall not be required under his contract of service to work more than five consecutive hours without a period of leisure of not less than thirty minutes duration; more than eight hours in one day; in excess of a spread over period of ten hours in one day; more than forty-eight hours in one week. Provided that where by agreement between an employee and his employer the number of hours of work on one or more days of the week is less than eight hours, the limit of eight hours may be exceeded on the remaining days of the week so, however, that the total number of hours worked in the week shall not exceed forty-eight.",
    sourceUrl:
      "https://lom.agc.gov.my/ilims/upload/portal/akta/outputp/act_265/Act%20265.pdf",
  },

  // ── Law Reform (Marriage and Divorce) Act 1976 (Act 164) ─────────────────
  {
    actName: "Law Reform (Marriage and Divorce) Act 1976",
    actNo: "Act 164",
    sectionNo: "s. 48",
    sectionTitle: "Divorce — facts establishing irretrievable breakdown",
    chunkText:
      "The court hearing a petition for divorce shall not hold the marriage to have broken down irretrievably unless the petitioner satisfies the court of one or more of the following facts: (a) that the respondent has committed adultery and the petitioner finds it intolerable to live with the respondent; (b) that the respondent has behaved in such a way that the petitioner cannot reasonably be expected to live with the respondent; (c) that the respondent has deserted the petitioner for a continuous period of at least two years immediately preceding the presentation of the petition; (d) that the parties to the marriage have lived apart for a continuous period of at least two years immediately preceding the presentation of the petition and the respondent consents to a decree being granted; (e) that the parties to the marriage have lived apart for a continuous period of at least five years immediately preceding the presentation of the petition.",
    sourceUrl:
      "https://lom.agc.gov.my/ilims/upload/portal/akta/outputp/act_164/Act%20164.pdf",
  },
  {
    actName: "Law Reform (Marriage and Divorce) Act 1976",
    actNo: "Act 164",
    sectionNo: "s. 76",
    sectionTitle: "Financial provision — maintenance of spouse",
    chunkText:
      "The court may order a man to pay maintenance to his former wife if it is satisfied that the wife has not committed adultery; and in so far as the wife is incapable of maintaining herself either by reason of physical or mental capacity, or because she is caring for a child of the marriage under the age of eighteen years. The court may order a woman to pay maintenance to her former husband if it is satisfied that the husband is incapable of maintaining himself by reason of mental or physical disability.",
    sourceUrl:
      "https://lom.agc.gov.my/ilims/upload/portal/akta/outputp/act_164/Act%20164.pdf",
  },

  // ── Personal Data Protection Act 2010 (Act 709) ───────────────────────────
  {
    actName: "Personal Data Protection Act 2010",
    actNo: "Act 709",
    sectionNo: "s. 5",
    sectionTitle: "General principle",
    chunkText:
      "A data user shall not process personal data about a data subject unless the data subject has given his consent to the processing of the personal data; or the processing of the personal data is necessary for the performance of a contract to which the data subject is a party; for the taking of steps at the request of the data subject with a view to entering into a contract; for compliance with any legal obligation to which the data user is the subject, other than an obligation imposed by a contract; in order to protect the vital interests of the data subject; for the administration of justice; for the exercise of any functions conferred on any person by or under any law; or for the purposes of legitimate interests pursued by the data user or by a third party or parties to whom the data is disclosed, except where such interests are overridden by the interests of the data subject.",
    sourceUrl:
      "https://lom.agc.gov.my/ilims/upload/portal/akta/outputp/act_709/Act%20709.pdf",
  },
  {
    actName: "Personal Data Protection Act 2010",
    actNo: "Act 709",
    sectionNo: "s. 6",
    sectionTitle: "Notice and choice principle",
    chunkText:
      "A data user shall, when collecting personal data of a data subject, inform the data subject in writing — (a) that the personal data of the data subject is being processed; (b) a description of the personal data being collected and processed; (c) the purpose for which the personal data is being collected and further processed; (d) any information available to the data user as to the source of that personal data; (e) the right of the data subject to request access to and correction of the personal data; (f) the right of the data subject to request the data user to cease processing the personal data that is causing or is likely to cause damage or distress to the data subject; (g) the class of third parties, if any, to whom the data user discloses or may disclose the personal data.",
    sourceUrl:
      "https://lom.agc.gov.my/ilims/upload/portal/akta/outputp/act_709/Act%20709.pdf",
  },
];

// ---------------------------------------------------------------------------
// slugify(str) — create a safe Firestore document ID
// ---------------------------------------------------------------------------
function slugify(str) {
  return str
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "");
}

// ---------------------------------------------------------------------------
// embedText — calls Gemini embedding API
// ---------------------------------------------------------------------------
async function embedText(ai, text) {
  const result = await ai.models.embedContent({
    model: GEMINI_EMBED_MODEL,
    contents: text,
  });

  const vec =
    result.embeddings?.[0]?.values ??
    result.embedding?.values ??
    result.values;

  if (!Array.isArray(vec) || vec.length === 0) {
    throw new Error(
      `Could not extract embedding vector. Response keys: ${Object.keys(result || {}).join(", ")}`
    );
  }
  return vec;
}

// ---------------------------------------------------------------------------
// main — seed all chunks
// ---------------------------------------------------------------------------
async function main() {
  console.log(`Seeding law_corpus with ${STATUTE_CHUNKS.length} chunks...`);
  console.log(`Embed model: ${GEMINI_EMBED_MODEL}`);

  const ai = new GoogleGenAI({ apiKey: GEMINI_API_KEY });
  const token = getGcloudToken();
  console.log(`gcloud token obtained (${token.length} chars)\n`);

  let added = 0;
  let skipped = 0;
  let failed = 0;

  for (const chunk of STATUTE_CHUNKS) {
    const docId = slugify(`${chunk.actNo}-${chunk.sectionNo}`);

    // Skip if already seeded (has a non-empty embedding array)
    const existing = await firestoreGet("law_corpus", docId, token);
    const existingEmbed = existing?.fields?.embedding?.arrayValue?.values;
    if (Array.isArray(existingEmbed) && existingEmbed.length > 0) {
      console.log(`  [skip] ${docId}`);
      skipped++;
      continue;
    }

    try {
      console.log(`  [embed] ${docId} ...`);
      const embedding = await embedText(ai, chunk.chunkText);

      await firestoreSet("law_corpus", docId, {
        actName: chunk.actName,
        actNo: chunk.actNo,
        sectionNo: chunk.sectionNo,
        sectionTitle: chunk.sectionTitle,
        chunkText: chunk.chunkText,
        sourceUrl: chunk.sourceUrl,
        embedding,
      }, token);

      console.log(`  [ok]   ${docId} (${embedding.length}d vector)`);
      added++;

      // Brief pause to stay within rate limits
      await new Promise((r) => setTimeout(r, 600));
    } catch (err) {
      console.error(`  [err]  ${docId}: ${err.message}`);
      failed++;
    }
  }

  console.log(`\nDone. added=${added} skipped=${skipped} failed=${failed}`);
  process.exit(failed > 0 ? 1 : 0);
}

main().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(1);
});
