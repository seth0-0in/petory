import 'package:flutter/material.dart';

import '../models/pet.dart';
import '../models/todo_item.dart';
import '../services/supabase_service.dart';

class TodoEditScreen extends StatefulWidget {
  final List<Pet> pets;
  final Pet? defaultPet;
  final TodoItem? existing;

  const TodoEditScreen({
    super.key,
    required this.pets,
    this.defaultPet,
    this.existing,
  });

  @override
  State<TodoEditScreen> createState() => _TodoEditScreenState();
}

class _TodoEditScreenState extends State<TodoEditScreen> {
  final SupabaseService _service = SupabaseService();
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;

  String? _petId;
  DateTime? _dueDate;
  TimeOfDay? _reminderTime;
  TodoRepeatType _repeatType = TodoRepeatType.none;
  final Set<int> _weekdays = <int>{};
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _noteController = TextEditingController(text: existing?.note ?? '');

    if (existing != null) {
      _petId = existing.petId;
      _dueDate = existing.dueDate;
      final h = existing.reminderHour;
      final m = existing.reminderMinute;
      if (h != null && m != null) {
        _reminderTime = TimeOfDay(hour: h, minute: m);
      }
      _repeatType = existing.repeatType;
      _weekdays.addAll(existing.repeatWeekdays);
    } else {
      _petId = widget.defaultPet?.id ?? widget.pets.firstOrNull?.id;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initial = _dueDate ?? today;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(today) ? today : initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    setState(() {
      _dueDate = picked;
    });
  }

  void _clearDate() {
    setState(() {
      _dueDate = null;
    });
  }

  Future<void> _pickTime() async {
    final initial = _reminderTime ?? const TimeOfDay(hour: 9, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked == null) return;
    setState(() {
      _reminderTime = picked;
    });
  }

  void _clearTime() {
    setState(() {
      _reminderTime = null;
    });
  }

  String _formatDate(DateTime d) =>
      '${d.year}년 ${d.month.toString().padLeft(2, '0')}월 ${d.day.toString().padLeft(2, '0')}일';

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목을 입력해 주세요.')),
      );
      return;
    }
    final petId = _petId;
    if (petId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('펫을 선택해 주세요.')),
      );
      return;
    }
    if (_repeatType == TodoRepeatType.weekly && _weekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('매주 반복은 요일을 한 개 이상 선택해 주세요.')),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final reminderText = _reminderTime == null
          ? null
          : _formatTime(_reminderTime!);
      final note = _noteController.text.trim();
      final TodoItem result;
      if (_isEdit) {
        result = await _service.updateTodo(
          id: widget.existing!.id,
          petId: petId,
          title: title,
          dueDate: _dueDate,
          reminderTime: reminderText,
          repeatType: _repeatType,
          repeatWeekdays: _weekdays,
          note: note,
        );
      } else {
        result = await _service.insertTodo(
          petId: petId,
          title: title,
          dueDate: _dueDate,
          reminderTime: reminderText,
          repeatType: _repeatType,
          repeatWeekdays: _weekdays,
          note: note,
        );
      }
      if (!mounted) return;
      Navigator.pop<TodoItem>(context, result);
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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? '할 일 수정' : '새 할 일'),
        actions: [
          TextButton(
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('제목', style: textTheme.labelLarge),
          const SizedBox(height: 8),
          TextField(
            controller: _titleController,
            autofocus: !_isEdit,
            decoration: const InputDecoration(
              hintText: '예: 산책 시키기',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 20),
          Text('펫', style: textTheme.labelLarge),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _petId,
            isExpanded: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
            items: [
              for (final p in widget.pets)
                DropdownMenuItem<String>(
                  value: p.id,
                  child: Text('${p.name} · ${p.species}'),
                ),
            ],
            onChanged: _saving
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() {
                      _petId = value;
                    });
                  },
          ),
          const SizedBox(height: 20),
          Text('날짜 (선택)', style: textTheme.labelLarge),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _saving ? null : _pickDate,
                  borderRadius: BorderRadius.circular(4),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      _dueDate == null ? '날짜 선택' : _formatDate(_dueDate!),
                      style: textTheme.bodyLarge?.copyWith(
                        color: _dueDate == null
                            ? colorScheme.onSurfaceVariant
                            : colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
              if (_dueDate != null)
                IconButton(
                  tooltip: '날짜 지우기',
                  icon: Icon(Icons.close, color: colorScheme.onSurfaceVariant),
                  onPressed: _saving ? null : _clearDate,
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text('알림 시각 (선택)', style: textTheme.labelLarge),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _saving ? null : _pickTime,
                  borderRadius: BorderRadius.circular(4),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.schedule),
                    ),
                    child: Text(
                      _reminderTime == null
                          ? '시각 선택'
                          : _formatTime(_reminderTime!),
                      style: textTheme.bodyLarge?.copyWith(
                        color: _reminderTime == null
                            ? colorScheme.onSurfaceVariant
                            : colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
              if (_reminderTime != null)
                IconButton(
                  tooltip: '시각 지우기',
                  icon: Icon(Icons.close, color: colorScheme.onSurfaceVariant),
                  onPressed: _saving ? null : _clearTime,
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text('반복', style: textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<TodoRepeatType>(
            segments: const [
              ButtonSegment(
                value: TodoRepeatType.none,
                label: Text('없음'),
              ),
              ButtonSegment(
                value: TodoRepeatType.daily,
                label: Text('매일'),
              ),
              ButtonSegment(
                value: TodoRepeatType.weekly,
                label: Text('매주'),
              ),
              ButtonSegment(
                value: TodoRepeatType.monthly,
                label: Text('매월'),
              ),
            ],
            selected: {_repeatType},
            onSelectionChanged: _saving
                ? null
                : (sel) {
                    setState(() {
                      _repeatType = sel.first;
                      if (_repeatType != TodoRepeatType.weekly) {
                        _weekdays.clear();
                      }
                    });
                  },
          ),
          if (_repeatType == TodoRepeatType.weekly) ...[
            const SizedBox(height: 12),
            _WeekdayPicker(
              selected: _weekdays,
              enabled: !_saving,
              onChanged: (next) {
                setState(() {
                  _weekdays
                    ..clear()
                    ..addAll(next);
                });
              },
            ),
          ],
          const SizedBox(height: 20),
          Text('메모 (선택)', style: textTheme.labelLarge),
          const SizedBox(height: 8),
          TextField(
            controller: _noteController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: '관련 메모를 적어두세요',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekdayPicker extends StatelessWidget {
  final Set<int> selected;
  final bool enabled;
  final void Function(Set<int>) onChanged;

  const _WeekdayPicker({
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  static const List<String> _labels = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      children: [
        for (var i = 0; i < 7; i++)
          ChoiceChip(
            label: Text(_labels[i]),
            selected: selected.contains(i + 1),
            onSelected: enabled
                ? (v) {
                    final next = {...selected};
                    if (v) {
                      next.add(i + 1);
                    } else {
                      next.remove(i + 1);
                    }
                    onChanged(next);
                  }
                : null,
            selectedColor: colorScheme.primaryContainer,
            labelStyle: TextStyle(
              color: selected.contains(i + 1)
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}
