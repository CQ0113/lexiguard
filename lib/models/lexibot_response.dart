class LexiBotCitation {
  final String title;
  final String sourceId;
  final String sourceUrl;

  const LexiBotCitation({
    required this.title,
    required this.sourceId,
    required this.sourceUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'sourceId': sourceId,
      'sourceUrl': sourceUrl,
    };
  }

  factory LexiBotCitation.fromMap(Map<String, dynamic> map) {
    return LexiBotCitation(
      title: map['title']?.toString() ?? '',
      sourceId: map['sourceId']?.toString() ?? '',
      sourceUrl: map['sourceUrl']?.toString() ?? '',
    );
  }
}

class LexiBotAnswer {
  final String shortAnswer;
  final String whatTheSourceSays;
  final String whatThisMeans;
  final List<String> evidenceToKeep;
  final List<String> whatYouCanDoNext;
  final List<String> sourcesUsed;
  final String needALawyer;

  const LexiBotAnswer({
    required this.shortAnswer,
    required this.whatTheSourceSays,
    required this.whatThisMeans,
    required this.evidenceToKeep,
    required this.whatYouCanDoNext,
    required this.sourcesUsed,
    required this.needALawyer,
  });

  Map<String, dynamic> toMap() {
    return {
      'shortAnswer': shortAnswer,
      'whatTheSourceSays': whatTheSourceSays,
      'whatThisMeans': whatThisMeans,
      'evidenceToKeep': evidenceToKeep,
      'whatYouCanDoNext': whatYouCanDoNext,
      'sourcesUsed': sourcesUsed,
      'needALawyer': needALawyer,
    };
  }

  factory LexiBotAnswer.fromMap(Map<String, dynamic> map) {
    return LexiBotAnswer(
      shortAnswer: map['shortAnswer']?.toString() ?? '',
      whatTheSourceSays: map['whatTheSourceSays']?.toString() ?? '',
      whatThisMeans: map['whatThisMeans']?.toString() ?? '',
      evidenceToKeep: _readStrings(map['evidenceToKeep']),
      whatYouCanDoNext: _readStrings(map['whatYouCanDoNext']),
      sourcesUsed: _readStrings(map['sourcesUsed']),
      needALawyer: map['needALawyer']?.toString() ?? '',
    );
  }

  static List<String> _readStrings(dynamic value) {
    if (value is! List) return const [];
    return value.map((item) => item.toString()).toList(growable: false);
  }
}

class LexiBotResponse {
  final String status;
  final String scopeStatus;
  final String riskLevel;
  final String responseLanguage;
  final LexiBotAnswer answer;
  final List<LexiBotCitation> citations;
  final int groundingChunkCount;
  final String auditId;

  const LexiBotResponse({
    required this.status,
    required this.scopeStatus,
    required this.riskLevel,
    this.responseLanguage = 'en',
    required this.answer,
    required this.citations,
    required this.groundingChunkCount,
    required this.auditId,
  });

  bool get needsLawyer =>
      status == 'urgent_escalation' ||
      status == 'out_of_scope' ||
      status == 'insufficient_sources' ||
      riskLevel == 'high';

  Map<String, dynamic> toMap() {
    return {
      'status': status,
      'scopeStatus': scopeStatus,
      'riskLevel': riskLevel,
      'responseLanguage': responseLanguage,
      'answer': answer.toMap(),
      'citations': citations.map((c) => c.toMap()).toList(),
      'groundingChunkCount': groundingChunkCount,
      'auditId': auditId,
    };
  }

  factory LexiBotResponse.fromMap(Map<String, dynamic> map) {
    final answerData = map['answer'];
    if (answerData is! Map) {
      throw const FormatException(
        'LexiBot response does not include an answer.',
      );
    }

    final citationsData = map['citations'];
    return LexiBotResponse(
      status: map['status']?.toString() ?? '',
      scopeStatus: map['scopeStatus']?.toString() ?? '',
      riskLevel: map['riskLevel']?.toString() ?? '',
      responseLanguage: map['responseLanguage']?.toString() ?? 'en',
      answer: LexiBotAnswer.fromMap(Map<String, dynamic>.from(answerData)),
      citations: citationsData is List
          ? citationsData
                .whereType<Map>()
                .map(
                  (item) =>
                      LexiBotCitation.fromMap(Map<String, dynamic>.from(item)),
                )
                .toList(growable: false)
          : const [],
      groundingChunkCount: (map['groundingChunkCount'] as num?)?.toInt() ?? 0,
      auditId: map['auditId']?.toString() ?? '',
    );
  }
}
