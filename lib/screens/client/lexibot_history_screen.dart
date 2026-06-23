import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../repositories/lexibot_repository.dart';
import 'lexibot_chat_screen.dart';

class LexiBotHistoryScreen extends StatefulWidget {
  const LexiBotHistoryScreen({super.key});

  @override
  State<LexiBotHistoryScreen> createState() => _LexiBotHistoryScreenState();
}

class _LexiBotHistoryScreenState extends State<LexiBotHistoryScreen> {
  static const _navy = Color(0xFF0B2447);
  static const _slate = Color(0xFF64748B);

  late final LexiBotRepository _repo;
  late final String _userId;

  @override
  void initState() {
    super.initState();
    _repo = LexiBotRepository();
    _userId = FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  void _startNewConversation() {
    final newId = 'flutter-${DateTime.now().microsecondsSinceEpoch.toString()}';
    _openChatScreen(newId);
  }

  void _openChatScreen(String conversationId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            iconTheme: const IconThemeData(color: _navy),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: LexiBotChatScreen(
            conversationId: conversationId,
            repository: _repo,
          ),
        ),
      ),
    );
  }

  Future<void> _deleteConversation(String conversationId, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Delete Conversation?',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: _navy),
        ),
        content: Text(
          'Are you sure you want to delete this chat session: "$title"? This action cannot be undone.',
          style: GoogleFonts.inter(color: _slate),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.inter(color: _slate)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(
              'Delete',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _repo.deleteConversation(_userId, conversationId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Chat deleted successfully.',
                style: GoogleFonts.inter(),
              ),
              backgroundColor: _navy,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to delete chat: $e',
                style: GoogleFonts.inter(),
              ),
              backgroundColor: Colors.red[700],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Just now';
    DateTime dt;
    if (timestamp is Timestamp) {
      dt = timestamp.toDate();
    } else if (timestamp is DateTime) {
      dt = timestamp;
    } else {
      return 'Recently';
    }

    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day) {
      return DateFormat('h:mm a').format(dt);
    } else if (dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day - 1) {
      return 'Yesterday at ${DateFormat('h:mm a').format(dt)}';
    } else {
      return DateFormat('dd MMM, h:mm a').format(dt);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_userId.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view chat history.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'LexiBot Assistant',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: _navy,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: _navy),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Hero Start New Conversation Banner
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _startNewConversation,
                icon: const Icon(Icons.add_comment_rounded, size: 20),
                label: Text(
                  'Start New Conversation',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    letterSpacing: 0.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),

          // Chat History List
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _repo.streamConversations(_userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: _navy),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        'Failed to load chat history: ${snapshot.error}',
                        style: GoogleFonts.inter(color: Colors.red[700]),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final list = snapshot.data ?? [];
                if (list.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final doc = list[index];
                    final id = doc['id'] as String;
                    final title = doc['title'] as String? ?? 'New Chat';
                    final lastActive = doc['lastActiveAt'];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: _navy.withValues(alpha: 0.08),
                          child: const Icon(
                            Icons.smart_toy_outlined,
                            color: _navy,
                          ),
                        ),
                        title: Text(
                          title,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            color: _navy,
                            fontSize: 14.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Last active: ${_formatTimestamp(lastActive)}',
                            style: GoogleFonts.inter(
                              color: _slate,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.red,
                            size: 22,
                          ),
                          onPressed: () => _deleteConversation(id, title),
                        ),
                        onTap: () => _openChatScreen(id),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _navy.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: _slate,
              size: 36,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No previous conversations',
            style: GoogleFonts.inter(
              color: _navy,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a new conversation with LexiBot to ask residential tenancy questions.',
            style: GoogleFonts.inter(color: _slate, fontSize: 13, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
