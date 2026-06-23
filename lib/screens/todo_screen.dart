import 'package:flutter/material.dart';

import '../models/pet.dart';
import '../models/todo_item.dart';
import '../services/reminder_scheduler.dart';
import '../services/supabase_service.dart';
import 'todo_edit_screen.dart';

enum TodoTab { today, upcoming, done }

class TodoScreen extends StatefulWidget {
  final List<Pet> pets;
  final Pet? defaultPet;
  final TodoTab initialTab;

  const TodoScreen({
    super.key,
    required this.pets,
    this.defaultPet,
    this.initialTab = TodoTab.today,
  });

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen>
    with SingleTickerProviderStateMixin {
  final SupabaseService _service = SupabaseService();
  late final TabController _tabController;

  List<TodoItem> _todos = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.index,
    );
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final all = await _service.fetchAllTodos();
      if (!mounted) return;
      setState(() {
        _todos = all;
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

  Pet? _petFor(String petId) {
    for (final p in widget.pets) {
      if (p.id == petId) return p;
    }
    return null;
  }

  List<TodoItem> get _todayList {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final list = _todos
        .where((t) => !t.isDone && t.occursOn(today))
        .toList();
    list.sort(_compareByTime);
    return list;
  }

  List<TodoItem> get _upcomingList {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final list = <TodoItem>[];
    for (final t in _todos) {
      if (t.isDone) continue;
      if (t.occursOn(today)) continue; // 오늘 탭에서 보이므로 제외
      if (t.repeatType != TodoRepeatType.none) {
        // 반복 일정은 다음 14일 안에 한 번이라도 발생하면 예정으로 노출
        var hit = false;
        for (var i = 1; i <= 14; i++) {
          if (t.occursOn(today.add(Duration(days: i)))) {
            hit = true;
            break;
          }
        }
        if (hit) list.add(t);
      } else {
        final d = t.dueDate;
        if (d == null) continue;
        final dd = DateTime(d.year, d.month, d.day);
        if (dd.isAfter(today)) list.add(t);
      }
    }
    list.sort((a, b) {
      final ad = a.dueDate ?? DateTime(9999);
      final bd = b.dueDate ?? DateTime(9999);
      final c = ad.compareTo(bd);
      if (c != 0) return c;
      return _compareByTime(a, b);
    });
    return list;
  }

  List<TodoItem> get _doneList {
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: 7));
    final list = _todos
        .where((t) => t.isDone && (t.doneAt == null || t.doneAt!.isAfter(cutoff)))
        .toList();
    list.sort((a, b) {
      final ad = a.doneAt ?? a.createdAt;
      final bd = b.doneAt ?? b.createdAt;
      return bd.compareTo(ad);
    });
    return list;
  }

  int _compareByTime(TodoItem a, TodoItem b) {
    final ah = a.reminderHour;
    final bh = b.reminderHour;
    if (ah == null && bh == null) return a.createdAt.compareTo(b.createdAt);
    if (ah == null) return 1;
    if (bh == null) return -1;
    final c = ah.compareTo(bh);
    if (c != 0) return c;
    final am = a.reminderMinute ?? 0;
    final bm = b.reminderMinute ?? 0;
    return am.compareTo(bm);
  }

  Future<void> _toggleDone(TodoItem todo) async {
    setState(() {
      final i = _todos.indexWhere((t) => t.id == todo.id);
      if (i >= 0) {
        // 낙관적 업데이트.
        final updated = TodoItem(
          id: todo.id,
          petId: todo.petId,
          title: todo.title,
          dueDate: todo.dueDate,
          reminderTime: todo.reminderTime,
          repeatType: todo.repeatType,
          repeatWeekdays: todo.repeatWeekdays,
          note: todo.note,
          isDone: !todo.isDone,
          doneAt: !todo.isDone ? DateTime.now() : null,
          createdAt: todo.createdAt,
        );
        _todos[i] = updated;
      }
    });
    try {
      final result = await _service.setTodoDone(todo.id, !todo.isDone);
      if (!mounted) return;
      setState(() {
        final i = _todos.indexWhere((t) => t.id == result.id);
        if (i >= 0) _todos[i] = result;
      });
      // 변경됨.
      // 알림 재예약.
      await rescheduleAllReminders(_service);
    } catch (e) {
      if (!mounted) return;
      // 실패 시 원복.
      setState(() {
        final i = _todos.indexWhere((t) => t.id == todo.id);
        if (i >= 0) _todos[i] = todo;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('상태 변경 실패: $e')),
      );
    }
  }

  Future<void> _openCreate() async {
    final result = await Navigator.push<TodoItem>(
      context,
      MaterialPageRoute(
        builder: (_) => TodoEditScreen(
          pets: widget.pets,
          defaultPet: widget.defaultPet,
        ),
      ),
    );
    if (result == null) return;
    if (!mounted) return;
    setState(() {
      _todos = [..._todos, result];
    });
    // 변경됨.
    await rescheduleAllReminders(_service);
  }

  Future<void> _openEdit(TodoItem todo) async {
    final result = await Navigator.push<TodoItem>(
      context,
      MaterialPageRoute(
        builder: (_) => TodoEditScreen(
          pets: widget.pets,
          existing: todo,
        ),
      ),
    );
    if (result == null) return;
    if (!mounted) return;
    setState(() {
      final i = _todos.indexWhere((t) => t.id == result.id);
      if (i >= 0) _todos[i] = result;
    });
    // 변경됨.
    await rescheduleAllReminders(_service);
  }

  Future<void> _confirmDelete(TodoItem todo) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('할 일 삭제'),
        content: Text('"${todo.title}" 할 일을 삭제할까요?'),
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
      await _service.deleteTodo(todo.id);
      if (!mounted) return;
      setState(() {
        _todos.removeWhere((t) => t.id == todo.id);
      });
      // 변경됨.
      await rescheduleAllReminders(_service);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('삭제 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('✅ 할 일'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
          indicatorColor: colorScheme.primary,
          tabs: const [
            Tab(text: '오늘'),
            Tab(text: '예정'),
            Tab(text: '완료'),
          ],
        ),
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: const Text('새 할 일'),
      ),
    );
  }

  Widget _buildBody() {
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
              const Text('할 일을 불러오지 못했어요.'),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('다시 시도')),
            ],
          ),
        ),
      );
    }
    return TabBarView(
      controller: _tabController,
      children: [
        _buildList(_todayList, '오늘 할 일이 없어요!\n새 할 일을 추가해보세요.'),
        _buildList(_upcomingList, '예정된 할 일이 없어요.'),
        _buildList(_doneList, '최근 7일 동안 완료한 할 일이 없어요.'),
      ],
    );
  }

  Widget _buildList(List<TodoItem> items, String emptyMessage) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            emptyMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final t = items[index];
        return _TodoTile(
          todo: t,
          pet: _petFor(t.petId),
          onToggle: () => _toggleDone(t),
          onEdit: () => _openEdit(t),
          onDelete: () => _confirmDelete(t),
        );
      },
    );
  }
}

class _TodoTile extends StatelessWidget {
  final TodoItem todo;
  final Pet? pet;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TodoTile({
    required this.todo,
    required this.pet,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  String? _timeText() {
    final h = todo.reminderHour;
    final m = todo.reminderMinute;
    if (h == null || m == null) return null;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  String? _repeatText() {
    switch (todo.repeatType) {
      case TodoRepeatType.daily:
        return '매일';
      case TodoRepeatType.weekly:
        if (todo.repeatWeekdays.isEmpty) return '매주';
        const labels = ['월', '화', '수', '목', '금', '토', '일'];
        final picked = todo.repeatWeekdays.toList()..sort();
        return '매주 ${picked.map((w) => labels[w - 1]).join('·')}';
      case TodoRepeatType.monthly:
        return '매월';
      case TodoRepeatType.none:
        return null;
    }
  }

  String? _dateText() {
    final d = todo.dueDate;
    if (d == null) return null;
    return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final done = todo.isDone;
    final time = _timeText();
    final repeat = _repeatText();
    final date = _dateText();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: done
            ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        elevation: done ? 0 : 1,
        shadowColor: colorScheme.shadow.withValues(alpha: 0.1),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 4, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onToggle,
                  icon: Icon(
                    done
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: done ? colorScheme.primary : colorScheme.outline,
                    size: 26,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                          style: textTheme.titleMedium!.copyWith(
                            fontWeight: FontWeight.w700,
                            decoration: done
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                            color: done
                                ? colorScheme.onSurfaceVariant
                                : colorScheme.onSurface,
                          ),
                          child: Text(todo.title),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (pet != null)
                              _PetBadge(pet: pet!, colorScheme: colorScheme),
                            if (time != null)
                              _MetaChip(
                                icon: Icons.schedule,
                                label: time,
                                colorScheme: colorScheme,
                              ),
                            if (repeat != null)
                              _MetaChip(
                                icon: Icons.repeat,
                                label: repeat,
                                colorScheme: colorScheme,
                              ),
                            if (date != null &&
                                todo.repeatType == TodoRepeatType.none)
                              _MetaChip(
                                icon: Icons.event_outlined,
                                label: date,
                                colorScheme: colorScheme,
                              ),
                          ],
                        ),
                        if (todo.note != null && todo.note!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            todo.note!,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: '더보기',
                  icon: Icon(
                    Icons.more_vert,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onSelected: (v) {
                    switch (v) {
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
        ),
      ),
    );
  }
}

class _PetBadge extends StatelessWidget {
  final Pet pet;
  final ColorScheme colorScheme;
  const _PetBadge({required this.pet, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final purple = Colors.deepPurple.shade400;
    final isMemorial = pet.isRainbowBridge;
    final bg = isMemorial
        ? purple.withValues(alpha: 0.15)
        : colorScheme.primaryContainer;
    final fg = isMemorial ? purple : colorScheme.onPrimaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.pets, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            pet.name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
          if (isMemorial) ...[
            const SizedBox(width: 3),
            const Text('🌈', style: TextStyle(fontSize: 11)),
          ],
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme colorScheme;
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
