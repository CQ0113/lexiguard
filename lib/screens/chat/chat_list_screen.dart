import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../models/user_model.dart';
import '../../repositories/chat_repository.dart';
import '../../widgets/network_avatar.dart';
import 'chat_room_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CHAT LIST SCREEN — SCRUM-17 Step 3
//
// Shows all chat rooms for the current user, newest-message first.
// Used as the Chat tab body in both client and lawyer dashboards.
// ─────────────────────────────────────────────────────────────────────────────

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key, required this.currentUser, this.repository});

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

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Guard Firebase access — if the caller injected a repo (e.g. in tests)
    // use it directly. Otherwise initialise the live repository.
    if (widget.repository != null) {
      _repo = widget.repository;
    } else {
      _repo = ChatRepository();
    }
    _backfillApprovedRooms();
  }

  Future<void> _backfillApprovedRooms() async {
    final repo = _repo;
    if (repo == null) return;
    try {
      if (widget.currentUser.role == UserRole.client) {
        await repo.syncClientRevealForApprovedConnections(widget.currentUser);
      }
      await repo.ensureRoomsForApprovedConnections(widget.currentUser.id);
    } catch (error) {
      debugPrint('Unable to backfill approved chat rooms: $error');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = _repo;
    if (repo == null) {
      // Firebase not ready — show the empty state so the tab is inert.
      return const _EmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sleek Search Header
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Conversations',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0C1D36),
                    ),
                  ),
                  // Small online/active indicator pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF0284C7),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Secure',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF0369A1),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search chats or cases...',
                  hintStyle: GoogleFonts.inter(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Color(0xFF64748B),
                    size: 20,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear_rounded,
                            color: Color(0xFF64748B),
                            size: 18,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Expanded List View
        Expanded(
          child: StreamBuilder<List<ChatRoom>>(
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

              final rawRooms = snapshot.data ?? const [];
              final query = _searchQuery.toLowerCase().trim();
              final rooms = rawRooms.where((room) {
                final otherName =
                    (widget.currentUser.role == UserRole.client
                            ? room.lawyerName
                            : room.clientName)
                        .toLowerCase();
                final caseTitle = room.caseTitle.toLowerCase();
                return otherName.contains(query) || caseTitle.contains(query);
              }).toList();

              if (rooms.isEmpty) {
                return _EmptyState(isSearch: query.isNotEmpty);
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: rooms.length,
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _RoomRow(
                    room: rooms[i],
                    currentUser: widget.currentUser,
                    repo: repo,
                  ),
                ),
              );
            },
          ),
        ),
      ],
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

  String get _otherName => _isClient ? room.lawyerName : room.clientName;

  String? get _otherAvatarUrl => _isClient ? room.lawyerAvatarUrl : null;

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
      color: Colors.transparent,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: hasUnread ? const Color(0xFFFFFDF5) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasUnread
                    ? _gold.withValues(alpha: 0.35)
                    : const Color(0xFFE2E8F0),
                width: hasUnread ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: hasUnread ? 0.04 : 0.02,
                  ),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // ── Avatar with active badge ─────────────────────────
                      Stack(
                        children: [
                          NetworkAvatar(
                            size: 48,
                            name: _otherName,
                            url: _otherAvatarUrl,
                            borderColor: hasUnread
                                ? _gold
                                : const Color(0xFFE2E8F0),
                            borderWidth: 1.5,
                            backgroundColor: _navy,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: const Color(0xFF22C55E), // Online green
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),

                      // ── Content Column ───────────────────────────────────
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Recipient Name + Relative Time
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    _otherName,
                                    style: GoogleFonts.inter(
                                      color: _navy,
                                      fontSize: 14.5,
                                      fontWeight: hasUnread
                                          ? FontWeight.w800
                                          : FontWeight.w600,
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
                                        ? FontWeight.w700
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),

                            // Styled Legal Case Tag
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.gavel_rounded,
                                    size: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      room.caseTitle,
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF64748B),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),

                            // Last message preview + unread badge
                            Row(
                              children: [
                                Expanded(
                                  child: _buildLastMessagePreview(hasUnread),
                                ),
                                if (hasUnread) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
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
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Color(0xFF94A3B8),
                                  size: 16,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Left unread accent indicator bar
          if (hasUnread)
            Positioned(
              left: 0,
              top: 18,
              bottom: 18,
              width: 4,
              child: Container(
                decoration: const BoxDecoration(
                  color: _gold,
                  borderRadius: BorderRadius.horizontal(
                    right: Radius.circular(4),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLastMessagePreview(bool hasUnread) {
    if (room.lastMessageText.isEmpty) {
      return Text(
        'No messages yet',
        style: GoogleFonts.inter(
          color: const Color(0xFF94A3B8),
          fontSize: 12,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    if (room.lastMessageType == 'image') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.image_outlined, size: 14, color: _gold),
          const SizedBox(width: 4),
          Text(
            'Sent an image',
            style: GoogleFonts.inter(
              fontStyle: FontStyle.italic,
              color: hasUnread ? _navy : const Color(0xFF64748B),
              fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
              fontSize: 12,
            ),
          ),
        ],
      );
    }

    if (room.lastMessageType == 'file') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.insert_drive_file_outlined, size: 14, color: _gold),
          const SizedBox(width: 4),
          Text(
            'Shared a document',
            style: GoogleFonts.inter(
              fontStyle: FontStyle.italic,
              color: hasUnread ? _navy : const Color(0xFF64748B),
              fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
              fontSize: 12,
            ),
          ),
        ],
      );
    }

    return Text(
      room.lastMessageText,
      style: GoogleFonts.inter(
        color: hasUnread ? _navy : const Color(0xFF64748B),
        fontSize: 12,
        fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
      ),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isSearch;
  const _EmptyState({this.isSearch = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSearch
                    ? Icons.search_off_rounded
                    : Icons.chat_bubble_outline_rounded,
                size: 32,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isSearch ? 'No chats found' : 'No conversations yet',
              style: GoogleFonts.inter(
                color: const Color(0xFF0C1D36),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isSearch
                  ? 'We couldn\'t find any active conversations matching your search query.'
                  : 'Once a connection request is approved, your chat will appear here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: const Color(0xFF64748B),
                fontSize: 13,
                height: 1.5,
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
              style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 12),
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
