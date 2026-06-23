import 'package:flutter/material.dart';

import '../models/log_entry.dart';
import '../models/log_like.dart';
import '../models/log_media.dart';
import '../models/pet.dart';
import '../services/auth_service.dart';
import '../services/pet_session.dart';
import '../services/supabase_service.dart';
import '../widgets/log_like_button.dart';
import 'add_log_screen.dart';
import 'gallery_screen.dart';
import 'log_detail_screen.dart';

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  final SupabaseService _service = SupabaseService();
  final TextEditingController _searchController = TextEditingController();

  List<LogEntry> _logs = [];
  bool _loading = false;
  String? _error;
  String? _loadedPetId;

  bool _searchVisible = false;
  String _searchQuery = '';
  DateTimeRange? _dateRange;

  VoidCallback? _petListener;

  @override
  void initState() {
    super.initState();
    _petListener = _onPetChanged;
    PetSession.instance.selectedPet.addListener(_petListener!);
    final initial = PetSession.instance.selectedPet.value;
    if (initial != null) {
      _load(initial.id);
    }
  }

  @override
  void dispose() {
    final cb = _petListener;
    if (cb != null) {
      PetSession.instance.selectedPet.removeListener(cb);
    }
    _searchController.dispose();
    super.dispose();
  }

  void _onPetChanged() {
    final pet = PetSession.instance.selectedPet.value;
    if (pet == null) {
      setState(() {
        _logs = [];
        _loadedPetId = null;
      });
      return;
    }
    if (pet.id != _loadedPetId) {
      _load(pet.id);
    }
  }

  Future<void> _load(String petId) async {
    setState(() {
      _loading = true;
      _error = null;
      _loadedPetId = petId;
    });
    try {
      final logs = await _service.fetchLogs(petId);
      if (!mounted) return;
      // 로드 도중 펫이 바뀌었으면 결과 무시.
      if (PetSession.instance.selectedPet.value?.id != petId) return;
      setState(() {
        _logs = logs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  bool get _hasActiveFilter => _searchQuery.isNotEmpty || _dateRange != null;

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _dateRange = null;
    });
  }

  void _toggleSearch() {
    setState(() {
      _searchVisible = !_searchVisible;
      if (!_searchVisible) {
        _searchController.clear();
        _searchQuery = '';
      }
    });
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: _dateRange,
    );
    if (range == null) return;
    setState(() {
      _dateRange = range;
    });
  }

  List<LogEntry> get _filteredLogs {
    return _logs.where((log) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!log.content.toLowerCase().contains(q)) return false;
      }
      if (_dateRange != null) {
        final created = log.createdAt;
        final start = DateTime(
          _dateRange!.start.year,
          _dateRange!.start.month,
          _dateRange!.start.day,
        );
        final endExclusive = DateTime(
          _dateRange!.end.year,
          _dateRange!.end.month,
          _dateRange!.end.day,
        ).add(const Duration(days: 1));
        if (created.isBefore(start) || !created.isBefore(endExclusive)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  String _formatDate(DateTime t) {
    final y = t.year.toString().padLeft(4, '0');
    final m = t.month.toString().padLeft(2, '0');
    final d = t.day.toString().padLeft(2, '0');
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$y.$m.$d $hh:$mm';
  }

  Future<void> _openAddLog() async {
    final pet = PetSession.instance.selectedPet.value;
    if (pet == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('펫을 먼저 선택해 주세요.')),
      );
      return;
    }
    final result = await Navigator.push<LogEntry>(
      context,
      MaterialPageRoute(
        builder: (_) => AddLogScreen(petId: pet.id),
      ),
    );
    if (result == null) return;
    if (!mounted) return;
    setState(() {
      _logs = [result, ..._logs];
    });
  }

  Future<void> _openEditLog(LogEntry log) async {
    final pet = PetSession.instance.selectedPet.value;
    if (pet == null) return;
    final result = await Navigator.push<LogEntry>(
      context,
      MaterialPageRoute(
        builder: (_) => AddLogScreen(petId: pet.id, existing: log),
      ),
    );
    if (result == null) return;
    if (!mounted) return;
    setState(() {
      _logs = _logs.map((x) => x.id == result.id ? result : x).toList();
    });
  }

  Future<void> _confirmDeleteLog(LogEntry log) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('기록 삭제'),
        content: const Text('이 기록을 삭제할까요? 되돌릴 수 없어요.'),
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
    if (confirmed != true) return;
    try {
      await _service.deleteLog(log.id);
      if (!mounted) return;
      setState(() {
        _logs = _logs.where((x) => x.id != log.id).toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('삭제 실패: $e')),
      );
    }
  }

  void _openLogDetail(LogEntry log) {
    final pet = PetSession.instance.selectedPet.value;
    if (pet == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LogDetailScreen(pet: pet, log: log),
      ),
    );
  }

  void _openGallery() {
    final pet = PetSession.instance.selectedPet.value;
    if (pet == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('펫을 먼저 선택해 주세요.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GalleryScreen(petId: pet.id)),
    );
  }

  Future<void> _toggleLogLike(LogEntry log) async {
    final userId = AuthService.instance.currentUser?.id;
    if (userId == null || AuthService.instance.isAnonymous) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('계정을 만들면 좋아요를 누를 수 있어요')),
      );
      return;
    }
    final wasLiked = log.isLikedBy(userId);
    final optimistic = [...log.likes];
    if (wasLiked) {
      optimistic.removeWhere((l) => l.userId == userId);
    } else {
      optimistic.add(LogLike(
        id: 'pending-$userId-${log.id}',
        logId: log.id,
        userId: userId,
        createdAt: DateTime.now(),
      ));
    }
    setState(() {
      final i = _logs.indexWhere((x) => x.id == log.id);
      if (i >= 0) _logs[i] = _logs[i].copyWith(likes: optimistic);
    });
    try {
      await _service.toggleLike(log.id);
      final fresh = await _service.fetchLikes(log.id);
      if (!mounted) return;
      setState(() {
        final i = _logs.indexWhere((x) => x.id == log.id);
        if (i >= 0) _logs[i] = _logs[i].copyWith(likes: fresh);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final i = _logs.indexWhere((x) => x.id == log.id);
        if (i >= 0) _logs[i] = _logs[i].copyWith(likes: log.likes);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('좋아요 처리 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ValueListenableBuilder<Pet?>(
      valueListenable: PetSession.instance.selectedPet,
      builder: (context, pet, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              pet == null ? '📖 일기' : '📖 ${pet.name}의 일기',
            ),
            actions: [
              IconButton(
                tooltip: _searchVisible ? '검색 닫기' : '기록 검색',
                icon: Icon(
                  _searchVisible ? Icons.search_off : Icons.search,
                ),
                onPressed: pet == null ? null : _toggleSearch,
              ),
              IconButton(
                tooltip: '날짜 범위',
                icon: const Icon(Icons.event_outlined),
                onPressed: pet == null ? null : _pickDateRange,
              ),
              IconButton(
                tooltip: '사진 갤러리',
                icon: const Icon(Icons.photo_library_outlined),
                onPressed: pet == null ? null : _openGallery,
              ),
            ],
          ),
          body: SafeArea(
            child: _buildBody(pet, colorScheme, textTheme),
          ),
          floatingActionButton: pet == null
              ? null
              : FloatingActionButton.extended(
                  onPressed: _openAddLog,
                  icon: const Icon(Icons.add),
                  label: const Text('오늘 기록'),
                ),
        );
      },
    );
  }

  Widget _buildBody(Pet? pet, ColorScheme colorScheme, TextTheme textTheme) {
    if (pet == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '홈에서 반려동물을 먼저 선택해 주세요.',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('일기를 불러오지 못했어요.', style: textTheme.bodyLarge),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => _load(pet.id),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }
    final logs = _filteredLogs;
    return Column(
      children: [
        if (_searchVisible) _buildSearchBar(colorScheme),
        if (_hasActiveFilter) _buildFilterChips(colorScheme, textTheme),
        Expanded(
          child: logs.isEmpty
              ? Center(
                  child: Text(
                    _hasActiveFilter
                        ? '검색 결과가 없어요'
                        : '아직 기록이 없어요. 첫 기록을 남겨보세요!',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    return _DiaryCard(
                      log: log,
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                      formatDate: _formatDate,
                      onTap: () => _openLogDetail(log),
                      onEdit: () => _openEditLog(log),
                      onDelete: () => _confirmDeleteLog(log),
                      onToggleLike: () => _toggleLogLike(log),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        onChanged: (v) => setState(() => _searchQuery = v.trim()),
        decoration: InputDecoration(
          hintText: '기록 내용 검색',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  tooltip: '검색어 지우기',
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                ),
          isDense: true,
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips(ColorScheme colorScheme, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (_searchQuery.isNotEmpty)
            InputChip(
              label: Text('"$_searchQuery"'),
              onDeleted: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
            ),
          if (_dateRange != null)
            InputChip(
              label: Text(
                '${_dateRange!.start.month}/${_dateRange!.start.day}'
                ' ~ ${_dateRange!.end.month}/${_dateRange!.end.day}',
              ),
              onDeleted: () {
                setState(() => _dateRange = null);
              },
            ),
          ActionChip(
            label: const Text('초기화'),
            onPressed: _resetFilters,
            backgroundColor: colorScheme.surfaceContainerHighest,
          ),
        ],
      ),
    );
  }
}

class _DiaryCard extends StatelessWidget {
  final LogEntry log;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final String Function(DateTime) formatDate;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleLike;

  const _DiaryCard({
    required this.log,
    required this.colorScheme,
    required this.textTheme,
    required this.formatDate,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleLike,
  });

  @override
  Widget build(BuildContext context) {
    final myId = AuthService.instance.currentUser?.id;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (log.hasMedia)
              _DiaryMediaPreview(
                media: log.displayMedia,
                colorScheme: colorScheme,
                onTap: onTap,
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 4, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(log.content, style: textTheme.bodyLarge),
                        const SizedBox(height: 8),
                        Text(
                          formatDate(log.createdAt),
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: '더보기',
                    icon: Icon(
                      Icons.more_vert,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          onEdit();
                          break;
                        case 'delete':
                          onDelete();
                          break;
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('수정')),
                      PopupMenuItem(value: 'delete', child: Text('삭제')),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Row(
                children: [
                  LogLikeButton(
                    liked: log.isLikedBy(myId),
                    count: log.likeCount,
                    onTap: onToggleLike,
                    onCountTap: onTap,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiaryMediaPreview extends StatefulWidget {
  final List<LogMedia> media;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  const _DiaryMediaPreview({
    required this.media,
    required this.colorScheme,
    required this.onTap,
  });

  @override
  State<_DiaryMediaPreview> createState() => _DiaryMediaPreviewState();
}

class _DiaryMediaPreviewState extends State<_DiaryMediaPreview> {
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
      height: 220,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            onPageChanged: (i) => setState(() => _index = i),
            itemCount: total,
            itemBuilder: (context, index) {
              final m = widget.media[index];
              return GestureDetector(
                onTap: widget.onTap,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(
                        tag: m.mediaUrl,
                        child: _PreviewThumb(
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
                              size: 56,
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

class _PreviewThumb extends StatelessWidget {
  final LogMedia media;
  final ColorScheme colorScheme;
  const _PreviewThumb({required this.media, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    if (media.isVideo) {
      return Container(
        color: Colors.black87,
        alignment: Alignment.center,
        child: const Icon(
          Icons.movie_outlined,
          color: Colors.white54,
          size: 48,
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
