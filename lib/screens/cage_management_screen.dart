import 'package:flutter/material.dart';

import '../models/cage_log.dart';
import '../models/cage_schedule.dart';
import '../services/reminder_scheduler.dart';
import '../services/supabase_service.dart';

class CageManagementScreen extends StatefulWidget {
  final String petId;
  final String petName;

  const CageManagementScreen({
    super.key,
    required this.petId,
    required this.petName,
  });

  @override
  State<CageManagementScreen> createState() => _CageManagementScreenState();
}

class _CageManagementScreenState extends State<CageManagementScreen> {
  final SupabaseService _service = SupabaseService();

  List<CageLog> _logs = [];
  Map<CageActivityType, CageSchedule?> _schedules = {
    CageActivityType.cleaning: null,
    CageActivityType.food: null,
    CageActivityType.water: null,
  };

  bool _loading = true;
  String? _error;
  bool _submittingDone = false;

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
      final now = DateTime.now();
      final from = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 14));

      final results = await Future.wait([
        _service.fetchCageLogs(widget.petId, from: from),
        _service.fetchCageSchedules(widget.petId),
      ]);
      final logs = results[0] as List<CageLog>;
      final schedules = results[1] as List<CageSchedule>;

      final byType = <CageActivityType, CageSchedule?>{
        CageActivityType.cleaning: null,
        CageActivityType.food: null,
        CageActivityType.water: null,
      };
      for (final s in schedules) {
        byType[s.type] = s;
      }

      if (!mounted) return;
      setState(() {
        _logs = logs;
        _schedules = byType;
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

  Future<void> _markDone(CageActivityType type) async {
    if (_submittingDone) return;
    setState(() {
      _submittingDone = true;
    });
    try {
      final saved = await _service.addCageLog(widget.petId, type: type);
      if (!mounted) return;
      setState(() {
        _logs = [saved, ..._logs];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submittingDone = false;
        });
      }
    }
  }

  Future<void> _editSchedule(CageActivityType type) async {
    final existing = _schedules[type];
    final updated = await showModalBottomSheet<CageSchedule>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ScheduleEditorSheet(
        petId: widget.petId,
        type: type,
        service: _service,
        existing: existing,
      ),
    );
    if (updated == null) return;
    if (!mounted) return;
    setState(() {
      _schedules = {..._schedules, type: updated};
    });
    _rescheduleNotifications();
  }

  Future<void> _rescheduleNotifications() async {
    await rescheduleAllReminders(_service);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('케이지 관리')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('케이지 관리')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('데이터를 불러오지 못했어요.', style: textTheme.bodyLarge),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style:
                      textTheme.bodySmall?.copyWith(color: colorScheme.error),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: _load, child: const Text('다시 시도')),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('${widget.petName} 케이지 관리')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              for (final type in CageActivityType.values) ...[
                _CageSectionCard(
                  type: type,
                  schedule: _schedules[type],
                  lastLog: _latestLog(type),
                  todayCount: _todayCount(type),
                  onDone: _submittingDone ? null : () => _markDone(type),
                  onEditSchedule: () => _editSchedule(type),
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 8),
              Text(
                '오늘 활동',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              _TodayTimeline(
                logs: _todayLogs(),
                colorScheme: colorScheme,
                textTheme: textTheme,
              ),
            ],
          ),
        ),
      ),
    );
  }

  CageLog? _latestLog(CageActivityType type) {
    for (final l in _logs) {
      if (l.type == type) return l;
    }
    return null;
  }

  int _todayCount(CageActivityType type) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    return _logs.where((l) {
      final local = l.loggedAt.toLocal();
      return l.type == type &&
          !local.isBefore(today) &&
          local.isBefore(tomorrow);
    }).length;
  }

  List<CageLog> _todayLogs() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final list = _logs.where((l) {
      final local = l.loggedAt.toLocal();
      return !local.isBefore(today) && local.isBefore(tomorrow);
    }).toList();
    list.sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
    return list;
  }
}

class _CageSectionCard extends StatelessWidget {
  final CageActivityType type;
  final CageSchedule? schedule;
  final CageLog? lastLog;
  final int todayCount;
  final VoidCallback? onDone;
  final VoidCallback onEditSchedule;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _CageSectionCard({
    required this.type,
    required this.schedule,
    required this.lastLog,
    required this.todayCount,
    required this.onDone,
    required this.onEditSchedule,
    required this.colorScheme,
    required this.textTheme,
  });

  String _agoLabel(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  String _formatTimestamp(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final mi = local.minute.toString().padLeft(2, '0');
    return '$y.$m.$d $h:$mi';
  }

  String? _nextExpectedLabel() {
    final last = lastLog;
    final sched = schedule;
    if (last == null || sched == null || sched.intervalHours <= 0) return null;
    final next = last.loggedAt.add(Duration(hours: sched.intervalHours));
    return _formatTimestamp(next);
  }

  @override
  Widget build(BuildContext context) {
    final last = lastLog;
    final sched = schedule;
    final nextExpected = _nextExpectedLabel();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(type.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Text(
                type.label,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (type != CageActivityType.cleaning)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '오늘 $todayCount회',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            last == null
                ? '아직 기록이 없어요'
                : '마지막: ${_agoLabel(last.loggedAt)} (${_formatTimestamp(last.loggedAt)})',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (nextExpected != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.event_outlined,
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  '다음 예정: $nextExpected',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onDone,
                  icon: Icon(_doneIcon()),
                  label: Text(_doneLabel()),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onEditSchedule,
                icon: const Icon(Icons.settings_outlined),
                label: const Text('설정'),
              ),
            ],
          ),
          if (sched != null) ...[
            const SizedBox(height: 8),
            _ScheduleSummary(
              schedule: sched,
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),
          ],
        ],
      ),
    );
  }

  IconData _doneIcon() {
    switch (type) {
      case CageActivityType.cleaning:
        return Icons.cleaning_services_outlined;
      case CageActivityType.food:
        return Icons.restaurant_outlined;
      case CageActivityType.water:
        return Icons.water_drop_outlined;
    }
  }

  String _doneLabel() {
    switch (type) {
      case CageActivityType.cleaning:
        return '청소 완료';
      case CageActivityType.food:
        return '급여 완료';
      case CageActivityType.water:
        return '물 교체 완료';
    }
  }
}

class _ScheduleSummary extends StatelessWidget {
  final CageSchedule schedule;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _ScheduleSummary({
    required this.schedule,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    final times = [...schedule.reminderTimes]..sort();
    final intervalLabel = schedule.intervalHours > 0
        ? '${schedule.intervalHours}시간마다'
        : '주기 미설정';
    final alarmLabel = times.isEmpty
        ? '알림 시각 없음'
        : '알림 ${times.join('·')}';
    final status = schedule.enabled ? '' : ' (꺼짐)';

    return Row(
      children: [
        Icon(
          Icons.alarm_outlined,
          size: 14,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            '$intervalLabel · $alarmLabel$status',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _TodayTimeline extends StatelessWidget {
  final List<CageLog> logs;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _TodayTimeline({
    required this.logs,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '오늘 기록이 아직 없어요.',
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return Column(
      children: [
        for (final log in logs)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Text(log.type.emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Text(
                  _hm(log.loggedAt),
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  log.type.label,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _hm(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _ScheduleEditorSheet extends StatefulWidget {
  final String petId;
  final CageActivityType type;
  final SupabaseService service;
  final CageSchedule? existing;

  const _ScheduleEditorSheet({
    required this.petId,
    required this.type,
    required this.service,
    this.existing,
  });

  @override
  State<_ScheduleEditorSheet> createState() => _ScheduleEditorSheetState();
}

class _ScheduleEditorSheetState extends State<_ScheduleEditorSheet> {
  late int _intervalHours;
  late bool _enabled;
  final List<TimeOfDay> _times = <TimeOfDay>[];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _intervalHours = e?.intervalHours ?? _defaultInterval();
    _enabled = e?.enabled ?? true;
    if (e != null) {
      for (final raw in e.reminderTimes) {
        final parts = raw.split(':');
        if (parts.length != 2) continue;
        final h = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (h == null || m == null) continue;
        if (h < 0 || h > 23 || m < 0 || m > 59) continue;
        _times.add(TimeOfDay(hour: h, minute: m));
      }
      _sortTimes();
    }
  }

  int _defaultInterval() {
    switch (widget.type) {
      case CageActivityType.cleaning:
        return 72; // 3일
      case CageActivityType.food:
        return 12;
      case CageActivityType.water:
        return 24;
    }
  }

  void _sortTimes() {
    _times.sort((a, b) {
      final am = a.hour * 60 + a.minute;
      final bm = b.hour * 60 + b.minute;
      return am.compareTo(bm);
    });
  }

  String _formatTimeOfDay(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _addTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked == null) return;
    final exists = _times.any(
      (t) => t.hour == picked.hour && t.minute == picked.minute,
    );
    setState(() {
      if (!exists) {
        _times.add(picked);
        _sortTimes();
      }
    });
  }

  Future<void> _save() async {
    if (_intervalHours <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('주기는 1시간 이상이어야 해요.')),
      );
      return;
    }
    setState(() {
      _saving = true;
    });
    try {
      final saved = await widget.service.upsertCageSchedule(
        widget.petId,
        type: widget.type,
        intervalHours: _intervalHours,
        reminderTimes: _times.map(_formatTimeOfDay).toList(),
        enabled: _enabled,
      );
      if (!mounted) return;
      Navigator.pop<CageSchedule>(context, saved);
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
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + bottomInset,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.type.emoji} ${widget.type.label} 설정',
              style: textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(
                Icons.notifications_active_outlined,
                color: colorScheme.primary,
              ),
              title: const Text('알림 받기'),
              subtitle: const Text('정해진 시각에 매일 반복으로 알려드릴게요'),
              value: _enabled,
              onChanged: _saving
                  ? null
                  : (v) {
                      setState(() {
                        _enabled = v;
                      });
                    },
            ),
            const SizedBox(height: 8),
            Text(
              '주기',
              style: textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final h in const [6, 8, 12, 24, 48, 72, 168])
                  ChoiceChip(
                    selected: _intervalHours == h,
                    label: Text(_intervalLabel(h)),
                    onSelected: (sel) {
                      if (sel) setState(() => _intervalHours = h);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '알림 시각',
                    style: textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _saving ? null : _addTime,
                  icon: const Icon(Icons.add),
                  label: const Text('시간 추가'),
                ),
              ],
            ),
            if (_times.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: Text(
                  '시간 추가 버튼을 눌러 알림 시각을 정해주세요',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in _times)
                    InputChip(
                      avatar: Icon(
                        Icons.access_time,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                      label: Text(_formatTimeOfDay(t)),
                      onDeleted: _saving
                          ? null
                          : () {
                              setState(() {
                                _times.remove(t);
                              });
                            },
                    ),
                ],
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
      ),
    );
  }

  String _intervalLabel(int hours) {
    if (hours % 24 == 0) {
      final days = hours ~/ 24;
      if (days == 7) return '1주';
      return '$days일';
    }
    return '$hours시간';
  }
}
