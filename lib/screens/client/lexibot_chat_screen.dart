import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/lexibot_response.dart';
import '../../services/lexibot_service.dart';

class LexiBotChatScreen extends StatefulWidget {
  const LexiBotChatScreen({
    super.key,
    LexiBotClient? client,
    VoidCallback? onRequestLawyer,
  }) : _client = client,
       _onRequestLawyer = onRequestLawyer;

  final LexiBotClient? _client;
  final VoidCallback? _onRequestLawyer;

  @override
  State<LexiBotChatScreen> createState() => _LexiBotChatScreenState();
}

class _LexiBotChatScreenState extends State<LexiBotChatScreen> {
  static const _navy = Color(0xFF0B2447);
  static const _gold = Color(0xFFD4AF37);

  final TextEditingController _questionController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final LexiBotClient _client;
  late final String _conversationId;
  final List<_ChatMessage> _messages = const [
    _ChatMessage.notice(
      'I answer general Peninsular Malaysia residential tenancy questions '
      'using approved legal sources. I cannot replace a lawyer or advise on '
      'urgent situations. For lockouts, violence, police or court deadlines, '
      'contact a lawyer promptly.',
    ),
  ].toList();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _client = widget._client ?? LexiBotService();
    _conversationId =
        'flutter-${DateTime.now().microsecondsSinceEpoch.toString()}';
  }

  @override
  void dispose() {
    _questionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _submitQuestion() async {
    final question = _questionController.text.trim();
    if (question.isEmpty || _isSending) return;

    setState(() {
      _messages.add(_ChatMessage.question(question));
      _questionController.clear();
      _isSending = true;
    });
    _scrollToLatest();

    try {
      final response = await _client.askQuestion(
        question: question,
        conversationId: _conversationId,
      );
      if (!mounted) return;
      setState(() => _messages.add(_ChatMessage.answer(response)));
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(() => _messages.add(_ChatMessage.error(_callableError(error))));
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _messages.add(
          const _ChatMessage.error(
            'LexiBot is taking too long to answer. Please try again later.',
          ),
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          const _ChatMessage.error(
            'LexiBot could not answer right now. Please try again later.',
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _scrollToLatest();
      }
    }
  }

  String _callableError(FirebaseFunctionsException error) {
    switch (error.code) {
      case 'failed-precondition':
        return 'LexiBot is still being prepared for client questions. '
            'Please check back after the source and safety review is complete.';
      case 'unauthenticated':
        return 'Please sign in again before asking LexiBot a question.';
      case 'resource-exhausted':
        return 'Too many requests were submitted. Please wait and try again.';
      default:
        return 'LexiBot could not answer right now. Please try again later.';
    }
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            itemCount: _messages.length + (_isSending ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _messages.length) {
                return const _ThinkingCard();
              }
              return _MessageCard(
                message: _messages[index],
                onRequestLawyer: widget._onRequestLawyer,
              );
            },
          ),
        ),
        _buildComposer(),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      color: Colors.white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _navy.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.smart_toy_outlined, color: _navy),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LexiBot',
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _navy,
                  ),
                ),
                Text(
                  'Peninsular Malaysia Residential Tenancy Information',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'MVP',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _navy,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                key: const Key('lexibot-question-field'),
                controller: _questionController,
                enabled: !_isSending,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'Ask about a tenancy issue...',
                  hintStyle: GoogleFonts.inter(color: Colors.grey[500]),
                  filled: true,
                  fillColor: const Color(0xFFF5F6F8),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              key: const Key('lexibot-send-button'),
              onPressed: _isSending ? null : _submitQuestion,
              style: IconButton.styleFrom(
                backgroundColor: _navy,
                disabledBackgroundColor: Colors.grey[300],
                minimumSize: const Size(48, 48),
              ),
              icon: const Icon(Icons.send_rounded, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ChatMessageType { notice, question, answer, error }

class _ChatMessage {
  final _ChatMessageType type;
  final String? text;
  final LexiBotResponse? response;

  const _ChatMessage._(this.type, {this.text, this.response});

  const _ChatMessage.notice(String text)
    : this._(_ChatMessageType.notice, text: text);

  const _ChatMessage.question(String text)
    : this._(_ChatMessageType.question, text: text);

  const _ChatMessage.answer(LexiBotResponse response)
    : this._(_ChatMessageType.answer, response: response);

  const _ChatMessage.error(String text)
    : this._(_ChatMessageType.error, text: text);
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message, this.onRequestLawyer});

  static const _navy = Color(0xFF0B2447);
  static const _red = Color(0xFFB91C1C);
  final _ChatMessage message;
  final VoidCallback? onRequestLawyer;

  @override
  Widget build(BuildContext context) {
    if (message.type == _ChatMessageType.answer) {
      return _AnswerCard(
        response: message.response!,
        onRequestLawyer: onRequestLawyer,
      );
    }

    final isUser = message.type == _ChatMessageType.question;
    final isError = message.type == _ChatMessageType.error;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 315),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: isUser
              ? _navy
              : isError
              ? const Color(0xFFFEE2E2)
              : const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          message.text!,
          style: GoogleFonts.inter(
            fontSize: 13,
            height: 1.4,
            color: isUser
                ? Colors.white
                : isError
                ? _red
                : _navy,
          ),
        ),
      ),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({required this.response, this.onRequestLawyer});

  static const _navy = Color(0xFF0B2447);
  static const _gold = Color(0xFFD4AF37);
  final LexiBotResponse response;
  final VoidCallback? onRequestLawyer;

  Future<void> _openSource(String sourceUrl) async {
    final uri = Uri.tryParse(sourceUrl);
    if (uri == null || !uri.hasScheme) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final answer = response.answer;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: response.needsLawyer
              ? const Color(0xFFFECACA)
              : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.smart_toy_outlined, color: _navy, size: 19),
              const SizedBox(width: 7),
              Text(
                'LexiBot',
                style: GoogleFonts.inter(
                  color: _navy,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              _StatusBadge(response: response),
            ],
          ),
          const SizedBox(height: 12),
          _AnswerSection(title: 'Short Answer', text: answer.shortAnswer),
          _AnswerSection(
            title: 'What the Source Says',
            text: answer.whatTheSourceSays,
          ),
          _AnswerSection(title: 'What This Means', text: answer.whatThisMeans),
          _AnswerListSection(
            title: 'Evidence to Keep',
            values: answer.evidenceToKeep,
          ),
          _AnswerListSection(
            title: 'What You Can Do Next',
            values: answer.whatYouCanDoNext,
          ),
          if (response.citations.isNotEmpty) ...[
            Text(
              'Sources Used',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _navy,
              ),
            ),
            const SizedBox(height: 5),
            ...response.citations.map(
              (citation) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.description_outlined,
                      size: 15,
                      color: _gold,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            citation.title,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                          if (citation.sourceUrl.isNotEmpty)
                            TextButton(
                              onPressed: () => _openSource(citation.sourceUrl),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 28),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('Open official source'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          _AnswerSection(title: 'Need a Lawyer?', text: answer.needALawyer),
          if (response.needsLawyer && onRequestLawyer != null)
            FilledButton.tonalIcon(
              onPressed: onRequestLawyer,
              icon: const Icon(Icons.person_search_outlined),
              label: const Text('Post a case for lawyer support'),
              style: FilledButton.styleFrom(
                foregroundColor: _navy,
                textStyle: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.response});

  final LexiBotResponse response;

  @override
  Widget build(BuildContext context) {
    final escalated = response.needsLawyer;
    final label = escalated ? 'Review needed' : 'Grounded';
    final color = escalated ? const Color(0xFFB91C1C) : const Color(0xFF15803D);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _AnswerSection extends StatelessWidget {
  const _AnswerSection({required this.title, required this.text});

  static const _navy = Color(0xFF0B2447);
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _navy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              height: 1.4,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnswerListSection extends StatelessWidget {
  const _AnswerListSection({required this.title, required this.values});

  static const _navy = Color(0xFF0B2447);
  final String title;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _navy,
            ),
          ),
          const SizedBox(height: 4),
          ...values.map(
            (value) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                '- $value',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  height: 1.4,
                  color: Colors.grey[700],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThinkingCard extends StatelessWidget {
  const _ThinkingCard();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
