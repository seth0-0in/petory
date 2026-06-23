import 'package:flutter/material.dart';

import '../models/log_comment.dart';
import '../models/log_entry.dart';
import '../models/log_like.dart';
import '../models/log_media.dart';
import '../models/pet.dart';
import '../models/pet_member.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import '../widgets/log_like_button.dart';
import 'media_viewer_screen.dart';
import 'sign_up_screen.dart';

class LogDetailScreen extends StatefulWidget {
  final Pet pet;
  final LogEntry log;

  const LogDetailScreen({
    super.key,
    required this.pet,
    required this.log,
  });

  @override
  State<LogDetailScreen> createState() => _LogDetailScreenState();
}

class _LogDetailScreenState extends State<LogDetailScreen> {
  final SupabaseService _service = SupabaseService();
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();

  List<LogComment> _comments = const [];
  Map<String, String> _emailByUserId = const {}; // user_id → email
  List<LogLike> _likes = const [];
  bool _loadingComments = true;
  bool _sending = false;
  String? _commentError;

  String? get _currentUserId => AuthService.instance.currentUser?.id;
  bool get _isAnonymous => AuthService.instance.isAnonymous;

  @override
  void initState() {
    super.initState();
    _likes = List<LogLike>.from(widget.log.likes);
    _load();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loadingComments = true;
      _commentError = null;
    });
    try {
      final results = await Future.wait([
        _service.fetchComments(widget.log.id),
        _service.fetchPetMembers(widget.pet.id).catchError(
              (_) => <PetMember>[],
            ),
        _service.fetchLikes(widget.log.id),
      ]);
      final comments = results[0] as List<LogComment>;
      final members = results[1] as List<PetMember>;
      final likes = results[2] as List<LogLike>;
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _emailByUserId = {
          for (final m in members)
            if (m.email != null) m.userId: m.email!,
        };
        _likes = likes;
        _loadingComments = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _commentError = e.toString();
        _loadingComments = false;
      });
    }
  }

  bool _likedByMe() {
    final myId = _currentUserId;
    if (myId == null) return false;
    for (final l in _likes) {
      if (l.userId == myId) return true;
    }
    return false;
  }

  Future<void> _toggleLike() async {
    final myId = _currentUserId;
    if (myId == null || _isAnonymous) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('계정을 만들면 좋아요를 누를 수 있어요')),
      );
      return;
    }
    final wasLiked = _likedByMe();
    // 낙관적 업데이트.
    final next = [..._likes];
    if (wasLiked) {
      next.removeWhere((l) => l.userId == myId);
    } else {
      next.add(LogLike(
        id: 'pending-$myId-${widget.log.id}',
        logId: widget.log.id,
        userId: myId,
        createdAt: DateTime.now(),
      ));
    }
    setState(() {
      _likes = next;
    });
    try {
      await _service.toggleLike(widget.log.id);
      final fresh = await _service.fetchLikes(widget.log.id);
      if (!mounted) return;
      setState(() {
        _likes = fresh;
      });
    } catch (e) {
      if (!mounted) return;
      // 원복.
      setState(() {
        _likes = wasLiked
            ? [
                ..._likes,
                LogLike(
                  id: 'rollback-$myId-${widget.log.id}',
                  logId: widget.log.id,
                  userId: myId,
                  createdAt: DateTime.now(),
                ),
              ]
            : _likes.where((l) => l.userId != myId).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('좋아요 처리 실패: $e')),
      );
    }
  }

  void _showLikersSheet() {
    if (_likes.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        final textTheme = Theme.of(ctx).textTheme;
        final myId = _currentUserId;
        final myEmail = AuthService.instance.currentEmail;
        final entries = [..._likes]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Row(
                  children: [
                    const Text('❤️', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(
                      '좋아요한 사람 ${entries.length}',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              for (final like in entries)
                _LikerTile(
                  like: like,
                  isMine: myId != null && like.userId == myId,
                  displayName: () {
                    if (myId != null && like.userId == myId) {
                      return displayNameFromEmail(myEmail, fallback: '나');
                    }
                    return displayNameFromEmail(
                      _emailByUserId[like.userId],
                      fallback: 'family',
                    );
                  }(),
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  String _displayNameFor(LogComment c) {
    final myId = _currentUserId;
    if (myId != null && c.userId == myId) {
      return displayNameFromEmail(
        AuthService.instance.currentEmail,
        fallback: '나',
      );
    }
    final email = c.userId == null ? null : _emailByUserId[c.userId!];
    return displayNameFromEmail(email, fallback: 'family');
  }

  Future<void> _send() async {
    if (_sending) return;
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _sending = true;
    });
    try {
      final inserted = await _service.insertComment(
        logId: widget.log.id,
        content: text,
      );
      if (!mounted) return;
      setState(() {
        _comments = [..._comments, inserted];
        _commentController.clear();
        _sending = false;
      });
      // 새 댓글로 자동 스크롤.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('댓글 등록 실패: $e')),
      );
    }
  }

  Future<void> _confirmDelete(LogComment c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('댓글 삭제'),
        content: const Text('이 댓글을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.deleteComment(c.id);
      if (!mounted) return;
      setState(() {
        _comments = _comments.where((x) => x.id != c.id).toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('삭제 실패: $e')),
      );
    }
  }

  void _openMediaViewer(int initialIndex) {
    final media = widget.log.displayMedia;
    if (media.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MediaViewerScreen(
          media: media,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  Future<void> _openSignUp() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SignUpScreen()),
    );
    if (!mounted) return;
    setState(() {}); // 로그인 상태 변화 반영.
  }

  String _formatLogTime(DateTime t) {
    final y = t.year.toString().padLeft(4, '0');
    final m = t.month.toString().padLeft(2, '0');
    final d = t.day.toString().padLeft(2, '0');
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$y.$m.$d $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final media = widget.log.displayMedia;

    return Scaffold(
      appBar: AppBar(title: Text('${widget.pet.name}의 기록')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                if (media.isNotEmpty) ...[
                  _MediaSection(
                    media: media,
                    colorScheme: colorScheme,
                    onTap: _openMediaViewer,
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    LogLikeButton(
                      liked: _likedByMe(),
                      count: _likes.length,
                      onTap: _toggleLike,
                      onCountTap: _likes.isEmpty ? null : _showLikersSheet,
                      iconSize: 24,
                    ),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  widget.log.content,
                  style: textTheme.bodyLarge?.copyWith(height: 1.55),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatLogTime(widget.log.createdAt),
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                Divider(color: colorScheme.outlineVariant),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '댓글 ${_comments.length}',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildCommentSection(colorScheme, textTheme),
              ],
            ),
          ),
          _buildBottomBar(colorScheme, textTheme),
        ],
      ),
    );
  }

  Widget _buildCommentSection(ColorScheme colorScheme, TextTheme textTheme) {
    if (_loadingComments) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_commentError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text(
              '댓글을 불러오지 못했어요.',
              style: textTheme.bodyMedium?.copyWith(color: colorScheme.error),
            ),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: _load, child: const Text('다시 시도')),
          ],
        ),
      );
    }
    if (_comments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            '아직 댓글이 없어요. 첫 댓글을 남겨보세요.',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    final myId = _currentUserId;
    return Column(
      children: [
        for (final c in _comments)
          _CommentTile(
            comment: c,
            isMine: myId != null && c.userId == myId,
            displayName: _displayNameFor(c),
            onLongPress: (myId != null && c.userId == myId)
                ? () => _confirmDelete(c)
                : null,
            colorScheme: colorScheme,
            textTheme: textTheme,
          ),
      ],
    );
  }

  Widget _buildBottomBar(ColorScheme colorScheme, TextTheme textTheme) {
    if (_isAnonymous) {
      return Material(
        color: colorScheme.surface,
        elevation: 8,
        shadowColor: colorScheme.shadow.withValues(alpha: 0.15),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                Icon(Icons.lock_outline, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '계정을 만들면 댓글을 달 수 있어요',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _openSignUp,
                  child: const Text('계정 만들기'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Material(
      color: colorScheme.surface,
      elevation: 8,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.15),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  focusNode: _commentFocus,
                  textInputAction: TextInputAction.send,
                  minLines: 1,
                  maxLines: 4,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: '댓글을 입력하세요',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: '전송',
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.send, color: colorScheme.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaSection extends StatefulWidget {
  final List<LogMedia> media;
  final ColorScheme colorScheme;
  final void Function(int index) onTap;

  const _MediaSection({
    required this.media,
    required this.colorScheme,
    required this.onTap,
  });

  @override
  State<_MediaSection> createState() => _MediaSectionState();
}

class _MediaSectionState extends State<_MediaSection> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.media.length;
    return SizedBox(
      height: 280,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            onPageChanged: (i) => setState(() => _index = i),
            itemCount: total,
            itemBuilder: (context, index) {
              final m = widget.media[index];
              return GestureDetector(
                onTap: () => widget.onTap(index),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(
                        tag: m.mediaUrl,
                        child: _DetailThumb(
                          media: m,
                          colorScheme: widget.colorScheme,
                        ),
                      ),
                      if (m.isVideo)
                        const IgnorePointer(
                          child: Center(
                            child: Icon(
                              Icons.play_circle_fill,
                              color: Colors.white,
                              size: 64,
                              shadows: [
                                Shadow(color: Colors.black54, blurRadius: 8),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (total > 1)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_index + 1} / $total',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          if (total > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < total; i++)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _index ? 8 : 6,
                      height: i == _index ? 8 : 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _index
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailThumb extends StatelessWidget {
  final LogMedia media;
  final ColorScheme colorScheme;
  const _DetailThumb({required this.media, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    if (media.isVideo) {
      return Container(
        color: Colors.black87,
        alignment: Alignment.center,
        child: const Icon(
          Icons.movie_outlined,
          color: Colors.white54,
          size: 56,
        ),
      );
    }
    return Image.network(
      media.mediaUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        color: colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Icon(
          Icons.broken_image_outlined,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final LogComment comment;
  final bool isMine;
  final String displayName;
  final VoidCallback? onLongPress;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _CommentTile({
    required this.comment,
    required this.isMine,
    required this.displayName,
    required this.onLongPress,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    final time = formatRelativeKo(comment.createdAt);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isMine
                ? colorScheme.primaryContainer.withValues(alpha: 0.45)
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: isMine
                        ? colorScheme.primary
                        : colorScheme.outline,
                    child: Text(
                      displayName.isNotEmpty
                          ? displayName.characters.first.toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: isMine
                            ? colorScheme.onPrimary
                            : colorScheme.surface,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    displayName,
                    style: textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isMine
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    '  •  $time',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                comment.content,
                style: textTheme.bodyMedium?.copyWith(height: 1.45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LikerTile extends StatelessWidget {
  final LogLike like;
  final bool isMine;
  final String displayName;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _LikerTile({
    required this.like,
    required this.isMine,
    required this.displayName,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        radius: 16,
        backgroundColor:
            isMine ? colorScheme.primary : colorScheme.outline,
        child: Text(
          displayName.isNotEmpty
              ? displayName.characters.first.toUpperCase()
              : '?',
          style: TextStyle(
            color: isMine ? colorScheme.onPrimary : colorScheme.surface,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      title: Text(
        displayName,
        style: textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: isMine ? colorScheme.primary : colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        formatRelativeKo(like.createdAt),
        style: textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: const Text('❤️', style: TextStyle(fontSize: 16)),
    );
  }
}
