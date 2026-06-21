import 'package:flutter/material.dart';

import '../models/milestone.dart';
import '../services/supabase_service.dart';

class MilestonesScreen extends StatefulWidget {
  final String petId;

  const MilestonesScreen({super.key, required this.petId});

  @override
  State<MilestonesScreen> createState() => _MilestonesScreenState();
}

class _MilestonesScreenState extends State<MilestonesScreen> {
  final SupabaseService _service = SupabaseService();

  List<Milestone> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _service.fetchMilestones(widget.petId);
      if (!mounted) return;
      setState(() {
        _items = items;
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

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y.$m.$d';
  }

  Future<void> _openAdd() async {
    final added = await showModalBottomSheet<Milestone>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) =>
          _AddMilestoneSheet(petId: widget.petId, service: _service),
    );
    if (added == null) return;
    if (!mounted) return;
    setState(() {
      final next = [..._items, added]
        ..sort((a, b) => b.achievedAt.compareTo(a.achievedAt));
      _items = next;
    });
  }

  Future<void> _delete(Milestone m) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('순간 삭제'),
        content: Text('${m.title} 기록을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _service.deleteMilestone(m.id);
      if (!mounted) return;
      setState(() {
        _items = _items.where((x) => x.id != m.id).toList();
      });
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
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('특별한 순간')),
      body: _buildBody(colorScheme, textTheme),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAdd,
        icon: const Icon(Icons.add),
        label: const Text('순간 추가'),
      ),
    );
  }

  Widget _buildBody(ColorScheme colorScheme, TextTheme textTheme) {
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
              Text('데이터를 불러오지 못했어요.', style: textTheme.bodyLarge),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('다시 시도')),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '아직 기록된 순간이 없어요.\n오른쪽 아래 + 버튼으로 첫 순간을 남겨보세요.',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final m = _items[index];
        final hasMemo = m.memo != null && m.memo!.isNotEmpty;
        return ListTile(
          leading: Icon(Icons.celebration_outlined, color: colorScheme.primary),
          title: Text(m.title),
          subtitle: Text(
            hasMemo
                ? '${_formatDate(m.achievedAt)}\n${m.memo}'
                : _formatDate(m.achievedAt),
          ),
          isThreeLine: hasMemo,
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(m),
          ),
        );
      },
    );
  }
}

class _AddMilestoneSheet extends StatefulWidget {
  final String petId;
  final SupabaseService service;

  const _AddMilestoneSheet({required this.petId, required this.service});

  @override
  State<_AddMilestoneSheet> createState() => _AddMilestoneSheetState();
}

class _AddMilestoneSheetState extends State<_AddMilestoneSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();
  DateTime _achievedAt = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y.$m.$d';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _achievedAt,
      firstDate: DateTime(now.year - 30),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    setState(() {
      _achievedAt = picked;
    });
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목을 입력해 주세요.')),
      );
      return;
    }

    final memoText = _memoController.text.trim();

    setState(() {
      _saving = true;
    });
    try {
      final saved = await widget.service.addMilestone(
        widget.petId,
        title: title,
        achievedAt: _achievedAt,
        memo: memoText.isEmpty ? null : memoText,
      );
      if (!mounted) return;
      Navigator.pop<Milestone>(context, saved);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('특별한 순간 추가', style: textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '제목',
              border: OutlineInputBorder(),
              hintText: '예: 첫 산책',
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _saving ? null : _pickDate,
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text('날짜: ${_formatDate(_achievedAt)}'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _memoController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '메모 (선택)',
              border: OutlineInputBorder(),
              hintText: '예: 처음으로 동네 한 바퀴 돌았어요',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('저장'),
          ),
        ],
      ),
    );
  }
}
