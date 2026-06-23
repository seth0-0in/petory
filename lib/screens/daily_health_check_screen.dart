import 'package:flutter/material.dart';

import '../models/daily_health_log.dart';
import '../services/supabase_service.dart';

class DailyHealthCheckScreen extends StatefulWidget {
  final String petId;
  final String petName;
  final DailyHealthLog? existing;

  const DailyHealthCheckScreen({
    super.key,
    required this.petId,
    required this.petName,
    this.existing,
  });

  @override
  State<DailyHealthCheckScreen> createState() => _DailyHealthCheckScreenState();
}

class _DailyHealthCheckScreenState extends State<DailyHealthCheckScreen> {
  final SupabaseService _service = SupabaseService();

  late int _appetite;
  late int _activity;
  late int _sleep;
  late int _digestion;
  late bool _painSigns;
  late final TextEditingController _memoController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _appetite = e?.appetite ?? 3;
    _activity = e?.activity ?? 3;
    _sleep = e?.sleep ?? 3;
    _digestion = e?.digestion ?? 3;
    _painSigns = e?.painSigns ?? false;
    _memoController = TextEditingController(text: e?.memo ?? '');
  }

  @override
  void dispose() {
    _memoController.dispose();
    super.dispose();
  }

  String _todayLabel() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return '$y.$m.$d (${weekdays[now.weekday - 1]})';
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
    });
    try {
      final memo = _memoController.text.trim();
      final saved = await _service.upsertTodayHealthLog(
        widget.petId,
        appetite: _appetite,
        activity: _activity,
        sleep: _sleep,
        digestion: _digestion,
        painSigns: _painSigns,
        memo: memo.isEmpty ? null : memo,
      );
      if (!mounted) return;
      Navigator.pop<DailyHealthLog>(context, saved);
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
    final isEdit = widget.existing != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? '오늘 건강 체크 수정' : '오늘 건강 체크'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            _DateHeader(
              label: _todayLabel(),
              petName: widget.petName,
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),
            const SizedBox(height: 16),
            _RatingCard(
              icon: '🍖',
              title: '식욕',
              lowLabel: '전혀 없음',
              highLabel: '매우 좋음',
              value: _appetite,
              onChanged: (v) => setState(() => _appetite = v),
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),
            const SizedBox(height: 10),
            _RatingCard(
              icon: '🏃',
              title: '활동량',
              lowLabel: '매우 적음',
              highLabel: '매우 활발',
              value: _activity,
              onChanged: (v) => setState(() => _activity = v),
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),
            const SizedBox(height: 10),
            _RatingCard(
              icon: '😴',
              title: '수면',
              lowLabel: '매우 불안',
              highLabel: '매우 안정',
              value: _sleep,
              onChanged: (v) => setState(() => _sleep = v),
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),
            const SizedBox(height: 10),
            _RatingCard(
              icon: '🚽',
              title: '배변',
              lowLabel: '이상 있음',
              highLabel: '매우 정상',
              value: _digestion,
              onChanged: (v) => setState(() => _digestion = v),
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),
            const SizedBox(height: 16),
            _PainSection(
              painSigns: _painSigns,
              onChanged: (v) => setState(() => _painSigns = v),
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _memoController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '메모 (선택)',
                border: OutlineInputBorder(),
                hintText: '예: 평소보다 물을 많이 마셨어요',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(_saving ? '저장 중...' : '저장'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  final String label;
  final String petName;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _DateHeader({
    required this.label,
    required this.petName,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today_outlined,
            color: colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '$petName의 오늘 건강 상태',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onPrimaryContainer,
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

class _RatingCard extends StatelessWidget {
  final String icon;
  final String title;
  final String lowLabel;
  final String highLabel;
  final int value;
  final ValueChanged<int> onChanged;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _RatingCard({
    required this.icon,
    required this.title,
    required this.lowLabel,
    required this.highLabel,
    required this.value,
    required this.onChanged,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Text(
                title,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '$value / 5',
                style: textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 1; i <= 5; i++)
                _EmojiButton(
                  selected: i == value,
                  label: '$i',
                  onTap: () => onChanged(i),
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                lowLabel,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                highLabel,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmojiButton extends StatelessWidget {
  final bool selected;
  final String label;
  final VoidCallback onTap;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _EmojiButton({
    required this.selected,
    required this.label,
    required this.onTap,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? colorScheme.primary : colorScheme.surface,
          border: Border.all(
            color: selected ? colorScheme.primary : colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: textTheme.titleMedium?.copyWith(
            color: selected ? colorScheme.onPrimary : colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _PainSection extends StatelessWidget {
  final bool painSigns;
  final ValueChanged<bool> onChanged;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _PainSection({
    required this.painSigns,
    required this.onChanged,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
          decoration: BoxDecoration(
            color: painSigns
                ? colorScheme.errorContainer
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: Text(
              '⚠️',
              style: TextStyle(
                fontSize: 22,
                color: painSigns
                    ? colorScheme.onErrorContainer
                    : colorScheme.onSurface,
              ),
            ),
            title: Text(
              '통증 신호',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: painSigns
                    ? colorScheme.onErrorContainer
                    : colorScheme.onSurface,
              ),
            ),
            subtitle: Text(
              '절뚝임·끙끙거림·특정 부위 만지기 싫어함 등',
              style: textTheme.bodySmall?.copyWith(
                color: painSigns
                    ? colorScheme.onErrorContainer.withValues(alpha: 0.85)
                    : colorScheme.onSurfaceVariant,
              ),
            ),
            value: painSigns,
            onChanged: onChanged,
          ),
        ),
        if (painSigns) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.error.withValues(alpha: 0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.local_hospital_outlined,
                  color: colorScheme.error,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '수의사 상담을 권장해요. 통증 신호가 계속되면 가까운 동물병원에 방문해 주세요.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
