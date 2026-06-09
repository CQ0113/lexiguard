const URGENT_PATTERNS = [
  /\b(lock(?:ed)?\s*out|changed?\s+(?:the\s+)?locks?)\b/i,
  /\b(force(?:d)?\s+entry|broke?\s+in|belongings?\s+(?:removed|thrown))\b/i,
  /\b(threat(?:en|ened|s)?|violence|assault|danger|unsafe)\b/i,
  /\b(police|arrest(?:ed)?|criminal|crime)\b/i,
  /\b(court|summons|writ|hearing|deadline|tribunal|lawsuit)\b/i,
  /\b(cut|disconnect(?:ed)?|shut\s+off)\b.*\b(electricity|water|utilities?)\b/i,
  /\b(file|start|commence)\s+(?:a\s+)?(?:claim|case|proceedings?)\b/i,
  /\bsue\b/i,
  /\b(dikunci|(?:menukar|tukar)\s+kunci|pecah\s+masuk|diugut|ugut|ancam|keganasan)\b/i,
  /\b(polis|ditangkap|jenayah|mahkamah|saman|tarikh\s+akhir|tribunal)\b/i,
  /\b(failkan|memfailkan|mulakan)\s+(?:satu\s+)?(?:tuntutan|kes|prosiding)\b/i,
  /\b(memotong|potong|memutuskan|putuskan|menghentikan|hentikan)\b.*\b(elektrik|air|utiliti|bekalan)\b/i,
  /(换锁|更换门锁|锁在门外|强行进入|闯入|威胁|暴力|袭击|危险)/,
  /(警察|警方|逮捕|刑事|犯罪|法院|法庭|传票|庭审|截止日期|仲裁庭|起诉|诉讼)/,
  /(断电|停电|断水|停水|切断.{0,5}(电|水|公用设施))/,
];

const OUT_OF_SCOPE_PATTERNS = [
  /\b(sabah|sarawak)\b/i,
  /\b(syariah|shariah)\b/i,
  /\b(divorce|custody|inheritance|will|probate)\b/i,
  /\b(criminal|arrest(?:ed)?|police)\b/i,
  /\b(syariah|cerai|perceraian|hak\s+penjagaan|warisan|wasiat|probet|jenayah)\b/i,
  /(沙巴|砂拉越|砂劳越|伊斯兰法|离婚|监护权|遗产|遗嘱|刑事)/,
];

const TENANCY_PATTERNS = [
  /\b(tenant|landlord|tenancy|rental|rent|rented|lease|premises)\b/i,
  /\b(security\s+deposit|utility\s+deposit|deposit|evict(?:ion)?|distress)\b/i,
  /\b(condo|minium|strata|management\s+body|joint\s+management)\b/i,
  /\b(penyewa|tuan\s+rumah|pemilik|sewa|rumah\s+sewa|premis|cagaran)\b/i,
  /\b(wang\s+pendahuluan|deposit|pengusiran|usir|kondo|strata|pengurusan)\b/i,
  /(租客|租户|房东|房東|业主|業主|房屋租赁|房屋租賃|租赁|租賃|租约|租約|租金|出租|租房)/,
  /(押金|保证金|保證金|驱逐|驅逐|腾退|騰退|分层地契|分層地契|公寓|物业管理|物業管理)/,
];

const MALAY_LANGUAGE_PATTERNS = [
  /\b(saya|sewa|penyewa|tuan\s+rumah|pemilik|rumah|wang|enggan|boleh|mahu|tidak|tak)\b/i,
  /\b(mahkamah|saman|kunci|bekalan|elektrik|utiliti|cagaran|pengusiran)\b/i,
];

const COPY = {
  en: {
    urgentReason: "The question may involve immediate safety, court, criminal, or deadline risk.",
    scopeReason: "This MVP only covers Peninsular Malaysia residential tenancy information.",
    tenancyReason: "This question does not appear to concern residential tenancy.",
    urgentShortAnswer: "This situation may need urgent help from a qualified Malaysian lawyer.",
    scopeShortAnswer: "LexiBot cannot answer this question within its tenancy-law MVP scope.",
    urgentNext: "Contact a Malaysian lawyer or appropriate emergency/legal-aid service promptly.",
    scopeNext: "Speak with a qualified Malaysian lawyer for advice on this issue.",
    needLawyer: "Yes. LexiBot provides general legal information only.",
    insufficientShortAnswer: "I cannot answer this reliably from the approved tenancy sources available.",
    insufficientMeaning: "LexiBot did not retrieve enough approved evidence for a supported answer.",
    insufficientNext: "Speak with a qualified Malaysian lawyer about your circumstances.",
    insufficientLawyer: "Yes, if you need guidance for your situation.",
  },
  ms: {
    urgentReason: "Soalan ini mungkin melibatkan risiko keselamatan segera, mahkamah, jenayah atau tarikh akhir.",
    scopeReason: "MVP ini hanya meliputi maklumat penyewaan kediaman di Semenanjung Malaysia.",
    tenancyReason: "Soalan ini tidak kelihatan berkaitan dengan penyewaan kediaman.",
    urgentShortAnswer: "Situasi ini mungkin memerlukan bantuan segera daripada peguam Malaysia yang berkelayakan.",
    scopeShortAnswer: "LexiBot tidak dapat menjawab soalan ini dalam skop MVP undang-undang penyewaannya.",
    urgentNext: "Hubungi peguam Malaysia atau saluran kecemasan/bantuan guaman yang sesuai dengan segera.",
    scopeNext: "Dapatkan nasihat daripada peguam Malaysia yang berkelayakan mengenai isu ini.",
    needLawyer: "Ya. LexiBot hanya menyediakan maklumat undang-undang umum.",
    insufficientShortAnswer: "Saya tidak dapat menjawab soalan ini dengan boleh dipercayai berdasarkan sumber penyewaan yang diluluskan.",
    insufficientMeaning: "LexiBot tidak menemui bukti diluluskan yang mencukupi untuk memberikan jawapan yang disokong.",
    insufficientNext: "Berbincang dengan peguam Malaysia yang berkelayakan mengenai keadaan anda.",
    insufficientLawyer: "Ya, jika anda memerlukan panduan untuk keadaan anda.",
  },
  zh: {
    urgentReason: "此问题可能涉及紧急安全、法院、刑事或期限风险。",
    scopeReason: "本 MVP 仅涵盖马来西亚半岛住宅租赁信息。",
    tenancyReason: "此问题似乎与住宅租赁无关。",
    urgentShortAnswer: "此情况可能需要尽快向合格的马来西亚律师寻求帮助。",
    scopeShortAnswer: "LexiBot 无法在租赁法律 MVP 的范围内回答此问题。",
    urgentNext: "请尽快联系马来西亚律师或适当的紧急/法律援助渠道。",
    scopeNext: "请就此问题咨询合格的马来西亚律师。",
    needLawyer: "是。LexiBot 仅提供一般法律信息。",
    insufficientShortAnswer: "依据现有获批租赁来源，我无法可靠地回答此问题。",
    insufficientMeaning: "LexiBot 未检索到足够的获批证据来支持回答。",
    insufficientNext: "请就您的情况咨询合格的马来西亚律师。",
    insufficientLawyer: "是，如果您需要针对自身情况的指导。",
  },
};

function normalizeTenancyTerms(question) {
  return String(question || "")
    .replace(/\b(teenant|tenent|tennant)\b/gi, "tenant")
    .replace(/\b(teenancy|tenency|tennacy)\b/gi, "tenancy")
    .trim();
}

function detectResponseLanguage(text) {
  if (/[\u3400-\u9fff]/u.test(text)) return "zh";
  if (MALAY_LANGUAGE_PATTERNS.some((pattern) => pattern.test(text))) return "ms";
  return "en";
}

function assessQuestion(question) {
  const text = normalizeTenancyTerms(question);
  const responseLanguage = detectResponseLanguage(text);
  const copy = COPY[responseLanguage] || COPY.en;

  if (URGENT_PATTERNS.some((pattern) => pattern.test(text))) {
    return {
      scopeStatus: "urgent_escalation",
      riskLevel: "high",
      reason: copy.urgentReason,
      responseLanguage,
    };
  }

  if (OUT_OF_SCOPE_PATTERNS.some((pattern) => pattern.test(text))) {
    return {
      scopeStatus: "out_of_scope",
      riskLevel: "high",
      reason: copy.scopeReason,
      responseLanguage,
    };
  }

  if (!TENANCY_PATTERNS.some((pattern) => pattern.test(text))) {
    return {
      scopeStatus: "out_of_scope",
      riskLevel: "medium",
      reason: copy.tenancyReason,
      responseLanguage,
    };
  }

  return {
    scopeStatus: "in_scope",
    riskLevel: "low",
    reason: null,
    responseLanguage,
  };
}

function escalationResponse(assessment) {
  const urgent = assessment.scopeStatus === "urgent_escalation";
  const copy = COPY[assessment.responseLanguage] || COPY.en;
  
  return {
    status: assessment.scopeStatus,
    scopeStatus: assessment.scopeStatus,
    riskLevel: assessment.riskLevel,
    responseLanguage: assessment.responseLanguage,
    answer: {
      shortAnswer: urgent ? copy.urgentShortAnswer : copy.scopeShortAnswer,
      whatTheSourceSays: "",
      whatThisMeans: assessment.reason,
      evidenceToKeep: [],
      whatYouCanDoNext: [urgent ? copy.urgentNext : copy.scopeNext],
      sourcesUsed: [],
      needALawyer: copy.needLawyer,
    },
    citations: [],
  };
}

function insufficientSourcesResponse(assessment) {
  const copy = COPY[assessment.responseLanguage] || COPY.en;
  
  return {
    status: "insufficient_sources",
    scopeStatus: assessment.scopeStatus,
    riskLevel: "medium",
    responseLanguage: assessment.responseLanguage,
    answer: {
      shortAnswer: copy.insufficientShortAnswer,
      whatTheSourceSays: "",
      whatThisMeans: copy.insufficientMeaning,
      evidenceToKeep: [],
      whatYouCanDoNext: [copy.insufficientNext],
      sourcesUsed: [],
      needALawyer: copy.insufficientLawyer,
    },
    citations: [],
    groundingChunkCount: 0,
  };
}

module.exports = {
  assessQuestion,
  escalationResponse,
  insufficientSourcesResponse,
};
