import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/firebase/firebase_initializer.dart';
import '../../models/user_model.dart';
import '../../repositories/chat_repository.dart';
import 'chat_room_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CHAT LIST SCREEN — SCRUM-17 Step 3
//
// Shows all chat rooms for the current user, newest-message first.
// Used as the Chat tab body in both client and lawyer dashboards.
// ─────────────────────────────────────────────────────────────────────────────

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({
    super.key,
    required this.currentUser,
    this.repository,
  });

  final UserModel currentUser;

  /// Optional injection for tests — mirrors the pattern in
  /// connection_requests_screen.dart.
  final ChatRepository? repository;

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  // Nullable: only set when Firebase is ready or a test repo is injected.
  ChatRepository? _repo;
  int _streamKey = 0;

  @override
  void initState() {
    super.initState();
    // Guard Firebase access — if the caller injected a repo (e.g. in tests)
    // use it directly. Otherwise only initialise when Firebase is ready.
    if (widget.repository != null) {
      _repo = widget.repository;
    } else if (FirebaseInitializer.isReady) {
      _repo = ChatRepository();
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = _repo;
    if (repo == null) {
      // Firebase not ready — show the empty state so the tab is inert.
      return const _EmptyState();
    }

    return StreamBuilder<List<ChatRoom>>(
      key: ValueKey(_streamKey),
      stream: repo.streamRoomsForUser(widget.currentUser.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorState(
            message: snapshot.error.toString(),
            onRetry: () => setState(() => _streamKey++),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF0C1D36)),
          );
        }

        final rooms = snapshot.data ?? const [];

        if (rooms.isEmpty) {
          return const _EmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: rooms.length,
          itemBuilder: (context, i) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _RoomRow(
              room: rooms[i],
              currentUser: widget.currentUser,
              repo: repo,
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ROOM ROW
// ─────────────────────────────────────────────────────────────────────────────

class _RoomRow extends StatelessWidget {
  const _RoomRow({
    required this.room,
    required this.currentUser,
    required this.repo,
  });

  final ChatRoom room;
  final UserModel currentUser;
  final ChatRepository repo;

  static const Color _navy = Color(0xFF0C1D36);
  static const Color _gold = Color(0xFFCFA92A);

  bool get _isClient => currentUser.role == UserRole.client;

  String get _otherName =>
      _isClient ? room.lawyerName : room.clientName;

  String? get _otherAvatarUrl =>
      _isClient ? room.lawyerAvatarUrl : null;

  String get _initials {
    final name = _otherName.trim();
    if (name.isEmpty) return '?';
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  int get _unread => room.unreadCounts[currentUser.id] ?? 0;

  String _relativeTime(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt.toLocal());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = _unread > 0;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasUnread
                ? _gold.withValues(alpha: 0.35)
                : const Color(0xFFEEEEF2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChatRoomScreen(
                currentUser: currentUser,
                room: room,
                repository: repo,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Avatar ────────────────────────────────────────────────────
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _navy,
                shape: BoxShape.circle,
                border: hasUnread
                    ? Border.all(color: _gold, width: 2)
                    : null,
                image: _otherAvatarUrl != null
                    ? DecorationImage(
                        image: NetworkImage(_otherAvatarUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _otherAvatarUrl == null
                  ? Center(
                      child: Text(
                        _initials,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),

            // ── Content ──────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + timestamp
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          _otherName,
                          style: GoogleFonts.inter(
                            color: _navy,
                            fontSize: 14,
                            fontWeight:
                                hasUnread ? FontWeight.w700 : FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _relativeTime(room.lastMessageAt),
                        style: GoogleFonts.inter(
                          color: hasUnread ? _gold : Colors.grey[400],
                          fontSize: 11,
                          fontWeight: hasUnread
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),

                  // Case title
                  Text(
                    room.caseTitle,
                    style: GoogleFonts.inter(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),

                  // Last message preview + unread badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          room.lastMessageText.isEmpty
                              ? 'No messages yet'
                              : room.lastMessageText,
                          style: GoogleFonts.inter(
                            color: hasUnread ? _navy : Colors.grey[400],
                            fontSize: 12,
                            fontStyle: room.lastMessageText.isEmpty
                                ? FontStyle.italic
                                : FontStyle.normal,
                            fontWeight: hasUnread
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _gold,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _unread > 99 ? '99+' : '$_unread',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),       // Row
          ),     // Padding
        ),       // InkWell
      ),         // Container
    );           // Material
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 56,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'No conversations yet',
              style: GoogleFonts.inter(
                color: Colors.grey[500],
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                'No conversations yet. Once a connection request is approved, your chat will appear here.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.grey[400],
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ERROR STATE
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
            const SizedBox(height: 12),
            Text(
              'Something went wrong',
              style: GoogleFonts.inter(
                color: Colors.red[700],
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
