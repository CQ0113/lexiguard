const BASE_URL = 'https://legaldirectory.malaysianbar.org.my';
const LOOKUP_ENDPOINT = `${BASE_URL}/a/Lawyer/getLawyerResult`;
const MAX_PAGES = 3;
const REQUEST_TIMEOUT_MS = 12000;

const STATE_CODE_BY_NAME = {
  johor: 'JH',
  johore: 'JH',
  kedah: 'KD',
  kelantan: 'KT',
  melaka: 'MK',
  malacca: 'MK',
  'negeri sembilan': 'NS',
  pahang: 'PH',
  penang: 'PG',
  'pulau pinang': 'PG',
  perak: 'PK',
  perlis: 'PR',
  selangor: 'SG',
  terengganu: 'TG',
  'kuala lumpur': 'WPKL',
  kl: 'WPKL',
  labuan: 'WL',
  putrajaya: 'WPP',
};

function normalizeWhitespace(value) {
  return String(value || '').replace(/\s+/g, ' ').trim();
}

function stripHtml(value) {
  return String(value || '').replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim();
}

function normalizeKey(value) {
  return normalizeWhitespace(value).toLowerCase();
}

function resolveStateCode(practiceState) {
  const normalized = normalizeKey(practiceState);
  if (!normalized) {
    return '';
  }

  const mapped = STATE_CODE_BY_NAME[normalized];
  if (mapped) {
    return mapped;
  }

  const compact = normalized.replace(/[^a-z]/g, '').toUpperCase();
  if (compact === 'WPKL' || compact === 'WL' || compact === 'WPP') {
    return compact;
  }

  if (compact.length === 2) {
    return compact;
  }

  return '';
}

function parseJsonPayload(body) {
  const trimmed = String(body || '').trim();
  if (!trimmed) {
    return null;
  }

  try {
    return JSON.parse(trimmed);
  } catch (_) {
    const firstBrace = trimmed.indexOf('{');
    const lastBrace = trimmed.lastIndexOf('}');

    if (firstBrace >= 0 && lastBrace > firstBrace) {
      try {
        return JSON.parse(trimmed.slice(firstBrace, lastBrace + 1));
      } catch (_) {
        return null;
      }
    }

    return null;
  }
}

function extractCookieHeader(response) {
  const getSetCookie = response?.headers?.getSetCookie;
  if (typeof getSetCookie === 'function') {
    const cookies = getSetCookie.call(response.headers) || [];
    return cookies.map((cookie) => cookie.split(';')[0]).filter(Boolean).join('; ');
  }

  const setCookie = response?.headers?.get('set-cookie');
  if (!setCookie) {
    return '';
  }

  return setCookie.split(',').map((cookie) => cookie.split(';')[0]).filter(Boolean).join('; ');
}

async function bootstrapSessionCookie() {
  const response = await fetch(`${BASE_URL}/`, {
    method: 'GET',
    signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
  });

  return extractCookieHeader(response);
}

function buildLookupPayload({ legalFullName, stateCode, page }) {
  const formData = new URLSearchParams();
  formData.set('name', legalFullName);
  formData.set('alphabet', '');
  formData.set('searchtype', 'Lawyer');
  formData.set('state', stateCode);
  formData.set('city', '');
  formData.set('keyword', '');
  formData.set('orderby', 'name');
  formData.set('dir', 'asc');
  formData.set('page', String(page));
  return formData.toString();
}

async function fetchLawyerPage({ legalFullName, stateCode, page, cookieHeader }) {
  const response = await fetch(LOOKUP_ENDPOINT, {
    method: 'POST',
    headers: {
      'content-type': 'application/x-www-form-urlencoded; charset=UTF-8',
      'x-requested-with': 'XMLHttpRequest',
      origin: BASE_URL,
      referer: `${BASE_URL}/v/search-result`,
      ...(cookieHeader ? { cookie: cookieHeader } : {}),
    },
    body: buildLookupPayload({ legalFullName, stateCode, page }),
    signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
  });

  const body = await response.text();
  if (!response.ok) {
    throw new Error(`Lookup request failed with status ${response.status}.`);
  }

  const parsed = parseJsonPayload(body);
  if (!parsed || typeof parsed !== 'object') {
    throw new Error('Lookup response is not valid JSON payload.');
  }

  return parsed;
}

function deriveStatusText(row) {
  const fromStatus = normalizeWhitespace(row.status);
  const fromMemberStatus = normalizeWhitespace(row.member_status);
  return normalizeWhitespace(`${fromStatus} ${fromMemberStatus}`);
}

function deriveActiveFlag(statusText) {
  const normalized = normalizeKey(statusText);
  if (!normalized) {
    return null;
  }

  if (normalized.includes('active')) {
    return true;
  }

  if (
    /(suspend|struck|inactive|ceased|expired|terminated|revoked|disbar)/.test(
      normalized
    )
  ) {
    return false;
  }

  return null;
}

function normalizeCandidate(row) {
  const statusText = deriveStatusText(row);

  return {
    name: normalizeWhitespace(row.name),
    firm: normalizeWhitespace(row.firm),
    admissionDate: normalizeWhitespace(row.admissiondate),
    qualification: normalizeWhitespace(row.qualification),
    status: normalizeWhitespace(row.status),
    memberStatus: normalizeWhitespace(row.member_status),
    statusText,
    isActive: deriveActiveFlag(statusText),
    state: normalizeWhitespace(row.state),
    city: normalizeWhitespace(row.city),
    postcode: normalizeWhitespace(row.postcode),
    email: normalizeWhitespace(row.email),
    tel1: normalizeWhitespace(row.tel1),
    tel2: normalizeWhitespace(row.tel2),
    tel3: normalizeWhitespace(row.tel3),
    fax: normalizeWhitespace(row.fax),
    addressLine1: normalizeWhitespace(row.add1),
    addressLine2: normalizeWhitespace(row.add2),
    addressLine3: normalizeWhitespace(row.add3),
    locationText: stripHtml(row.location),
    lastUpdate: normalizeWhitespace(row.lastupdate),
  };
}

function getLawyerRows(payload) {
  const lawyers = payload?.data?.lawyers;
  if (!lawyers || typeof lawyers !== 'object') {
    return { rows: [], numPages: 0, numRows: 0 };
  }

  const rows = Array.isArray(lawyers.data) ? lawyers.data : [];
  const numPages = Number.parseInt(String(lawyers.numpage || '0'), 10) || 0;
  const numRows = Number.parseInt(String(lawyers.numrow || '0'), 10) || 0;

  return { rows, numPages, numRows };
}

async function lookupMalaysianBarCandidates({ legalFullName, practiceState }) {
  const normalizedName = normalizeWhitespace(legalFullName);

  if (!normalizedName) {
    return {
      source: 'malaysian_bar',
      adapterStatus: 'skipped_missing_name',
      query: null,
      candidates: [],
    };
  }

  const stateCode = resolveStateCode(practiceState);
  let sessionCookie = '';

  try {
    sessionCookie = await bootstrapSessionCookie();
  } catch (_) {
    sessionCookie = '';
  }

  try {
    const firstPagePayload = await fetchLawyerPage({
      legalFullName: normalizedName,
      stateCode,
      page: 1,
      cookieHeader: sessionCookie,
    });

    const firstPage = getLawyerRows(firstPagePayload);
    const totalPages = Math.min(firstPage.numPages || 1, MAX_PAGES);
    const candidates = [...firstPage.rows.map(normalizeCandidate)];

    for (let page = 2; page <= totalPages; page += 1) {
      const payload = await fetchLawyerPage({
        legalFullName: normalizedName,
        stateCode,
        page,
        cookieHeader: sessionCookie,
      });

      const parsedPage = getLawyerRows(payload);
      candidates.push(...parsedPage.rows.map(normalizeCandidate));
    }

    return {
      source: 'malaysian_bar',
      adapterStatus: candidates.length ? 'success' : 'no_results',
      query: {
        legalFullName: normalizedName,
        requestedPracticeState: normalizeWhitespace(practiceState),
        stateCode,
        usedSessionCookie: Boolean(sessionCookie),
      },
      pageStats: {
        queriedPages: totalPages,
        totalPages: firstPage.numPages,
        totalRows: firstPage.numRows,
      },
      candidates,
    };
  } catch (error) {
    return {
      source: 'malaysian_bar',
      adapterStatus: 'request_failed',
      query: {
        legalFullName: normalizedName,
        requestedPracticeState: normalizeWhitespace(practiceState),
        stateCode,
        usedSessionCookie: Boolean(sessionCookie),
      },
      errorMessage: error?.message || String(error),
      candidates: [],
    };
  }
}

module.exports = {
  lookupMalaysianBarCandidates,
};
